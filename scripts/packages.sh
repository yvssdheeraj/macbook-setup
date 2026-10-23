#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

download() {
    [[ "$1" == https://* ]] || { log_error "Only HTTPS downloads are permitted."; return 1; }
    assert_user_path "$2" || return
    curl --fail --location --silent --show-error --retry 3 --connect-timeout 20 \
        --max-time 900 --proto '=https' --proto-redir '=https' --tlsv1.2 --output "$2" "$1"
}

verify_sha256() {
    [[ "$2" =~ ^[0-9a-fA-F]{64}$ ]] || { log_error "Missing or invalid SHA256 for $1"; return 1; }
    local actual
    actual="$(shasum -a 256 "$1")" || return
    [[ "${actual%% *}" == "$2" ]] || { log_error "SHA256 mismatch: $1"; return 1; }
}

github_release() {
    local file="$RUN_DIR/release.${1//\//_}.json"
    if [[ ! -f "$file" ]]; then
        download "https://api.github.com/repos/$1/releases/latest" "$file" || return
    fi
    cat "$file"
}

extract_archive() {
    local archive="$1" destination="$2"
    assert_user_path "$destination" || return
    mkdir -p "$destination" || return
    case "$archive" in
        *.zip)
            unzip -Z -1 "$archive" | support archive-paths || return
            if tar --version | grep -q bsdtar; then
                tar -xf "$archive" -C "$destination" || return
            else
                log_error "ZIP extraction requires macOS bsdtar's secure symlink handling."
                return 1
            fi
            ;;
        *.tar.gz|*.tgz|*.tar.xz|*.tbz)
            tar -tf "$archive" | support archive-paths || return
            tar -xf "$archive" -C "$destination" || return
            ;;
        *) log_error "Unsupported archive: $archive"; return 1 ;;
    esac
    support check-links "$destination"
}

brew_inventory() {
    "$BREW_PREFIX/bin/brew" list --formula --versions &&
        "$BREW_PREFIX/bin/brew" list --cask --versions
}

ensure_homebrew() {
    require_apply_context
    local directory release tracked
    assert_user_path "$BREW_PREFIX" || return
    assert_user_path "$HOMEBREW_CACHE" || return
    assert_user_path "$HOMEBREW_LOGS" || return
    mkdir -p "$HOMEBREW_CACHE" "$HOMEBREW_LOGS" || return
    if [[ -x "$BREW_PREFIX/bin/brew" ]]; then
        "$BREW_PREFIX/bin/brew" --version || return
        if [[ "$MODE" == update ]] && support package-owned backend homebrew; then
            tracked="$(GIT_OPTIONAL_LOCKS=0 git -C "$BREW_PREFIX" status --porcelain --untracked-files=no)" || return
            [[ -z "$tracked" ]] ||
                { log_error "Homebrew tracked files were edited; preserving them."; return 1; }
            release="$(github_release Homebrew/brew | support release)" || return
            tracked="$(git -C "$BREW_PREFIX" describe --tags --exact-match)" || return
            if [[ "$tracked" != "$release" ]]; then
                git -C "$BREW_PREFIX" fetch --quiet --depth 1 origin "refs/tags/$release" || return
                git -C "$BREW_PREFIX" checkout --quiet --detach FETCH_HEAD || return
                support package backend homebrew "$release" "$BREW_PREFIX" || return
                mark_changed
            fi
        fi
        return 0
    fi
    if [[ -e "$BREW_PREFIX" ]]; then
        log_error "Homebrew destination exists but is not a usable installation: $BREW_PREFIX"
        return 1
    fi
    log_warn "Installing Homebrew in a home prefix is Tier 3. Formulae may need source builds."
    directory="$(work_dir)" || return
    release="$(github_release Homebrew/brew | support release)" || return
    [[ "$release" =~ ^[0-9]+(\.[0-9]+)+$ ]] || { log_error "Invalid Homebrew stable tag: $release"; return 1; }
    # The official installer rejects long home prefixes. A tagged upstream checkout
    # is the explicit Tier 3 alternative; it never provisions a system prefix.
    git clone --quiet --depth 1 --branch "$release" https://github.com/Homebrew/brew.git "$directory/brew" || return
    mkdir -p "$(dirname "$BREW_PREFIX")" || return
    "$directory/brew/bin/brew" --version || return
    [[ ! -e "$BREW_PREFIX" ]] || { log_error "Homebrew destination was created by another process."; return 1; }
    support package backend homebrew "$release" "$BREW_PREFIX" || return
    mv "$directory/brew" "$BREW_PREFIX" || return
    "$BREW_PREFIX/bin/brew" --version || return
    support package backend homebrew "$release" "$BREW_PREFIX" || return
    mark_changed
}

package_metadata() {
    local type="$1" name="$2" file="$RUN_DIR/$1.$2.json"
    if [[ ! -f "$file" ]]; then
        download "https://formulae.brew.sh/api/$type/$name.json" "$file" || return
    fi
    cat "$file"
}

try_brew_package() {
    local type="$1" name="$2" expected="$3" metadata version before after existing operation available=false
    ensure_homebrew || { log_warn "User-local Homebrew unavailable; trying an upstream fallback."; return 1; }
    metadata="$(package_metadata "$type" "$name")" || return
    printf '%s' "$metadata" | support package-policy "$type" || return
    version="$(printf '%s' "$metadata" | support package-version "$type")" || return
    before="$(work_dir)" || return
    brew_inventory > "$before/inventory" || return
    existing="$("$BREW_PREFIX/bin/brew" list "--$type" --versions "$name" 2>/dev/null)" || existing=""
    if [[ -n "$existing" ]]; then
        if [[ "$type" == formula ]]; then
            if command -v "$expected" >/dev/null; then available=true; fi
        elif find_app "$expected" >/dev/null; then
            available=true
        fi
        if [[ "$available" != true ]]; then
            support package-owned "$type" "$name" || blocked "Pre-existing $name is incomplete; repair it with its original owner."
            operation=reinstall
        elif [[ "$MODE" == update ]] && support package-owned "$type" "$name"; then
            operation=upgrade
        else
            log_info "Preserving existing $name; updates apply only to repo-owned packages."
            record_version "$name" "$existing" stable || return
            return 0
        fi
    else
        operation=install
    fi
    local status=0
    if [[ "$type" == cask ]]; then
        local options=("--appdir=$APP_DIR")
        [[ "$operation" != upgrade ]] || options+=(--greedy)
        "$BREW_PREFIX/bin/brew" "$operation" --cask "${options[@]}" "$name" || status=$?
    else
        "$BREW_PREFIX/bin/brew" "$operation" --formula "$name" || status=$?
    fi
    after="$(work_dir)" || return
    brew_inventory > "$after/inventory" || return
    printf '%s\n' "$name" > "$after/eligible"
    if "$BREW_PREFIX/bin/brew" deps "--$type" --installed "$name" > "$after/dependencies"; then
        cat "$after/dependencies" >> "$after/eligible"
    else
        log_warn "Could not attribute build dependencies for $name; unrecorded dependencies will be retained."
    fi
    support brew-diff "$before/inventory" "$after/inventory" "$BREW_PREFIX" "$after/eligible" || return
    if [[ "$status" -ne 0 ]]; then
        log_error "Homebrew $operation failed for $name (exit $status)."
        return "$status"
    fi
    existing="$("$BREW_PREFIX/bin/brew" list "--$type" --versions "$name")" || return
    support package "$type" "$name" "$existing" "$BREW_PREFIX" || return
    if [[ "$type" == cask ]]; then
        local installed_app
        installed_app="$(find_app "$expected")" || { log_error "Homebrew did not produce $expected."; return 1; }
        support package-app "$name" "$installed_app" || return
    fi
    record_version "$name" "$existing" "$version" || return
    if ! cmp -s "$before/inventory" "$after/inventory"; then mark_changed; fi
}

install_release_binary() {
    local repository="$1" pattern="$2" binary="$3" release version url checksum directory asset target source
    release="$(github_release "$repository" | support release "$pattern")" || return
    IFS=$'\t' read -r version url checksum <<< "$release"
    directory="$(work_dir)" || return
    asset="$directory/${url##*/}"
    download "$url" "$asset" || return
    verify_sha256 "$asset" "$checksum" || return
    case "$asset" in
        *.zip|*.tar.gz|*.tgz|*.tar.xz)
            extract_archive "$asset" "$directory/unpacked" || return
            source="$(find "$directory/unpacked" -type f -name "$binary" -print)" || return
            [[ -n "$source" && "$source" != *$'\n'* ]] || { log_error "Expected one $binary in release archive."; return 1; }
            ;;
        *) source="$asset" ;;
    esac
    chmod +x "$source" || return
    "$source" --version || return
    target="$LOCAL_BIN/$binary"
    managed_executable "$source" "$target" || return
    record_version "$binary" "$version" stable
}

install_formula() {
    require_apply_context
    local name="$1" binary="$2" existing=""
    existing="$(command -v "$binary")" || existing=""
    if [[ -n "$existing" ]]; then
        if [[ "$MODE" != update ]] || { ! owned_path "$existing" && ! support package-owned formula "$name"; }; then
            log_info "Using existing $binary at $existing."
            record_command_version "$name" stable "$existing" --version
            return
        fi
    fi
    if ! owned_path "$LOCAL_BIN/$binary" && try_brew_package formula "$name" "$binary"; then
        command -v "$binary" >/dev/null || { log_error "$name installed but $binary is not accessible."; return 1; }
        return 0
    fi
    log_warn "Trying the supported upstream fallback for $name."
    case "$name" in
        gh) install_release_binary cli/cli '^gh_.*_macOS_arm64\.zip$' gh ;;
        uv) install_release_binary astral-sh/uv '^uv-aarch64-apple-darwin\.tar\.gz$' uv ;;
        colima) install_release_binary abiosoft/colima '^colima-Darwin-(arm64|aarch64)$' colima ;;
        lima) install_lima_release ;;
        btop) build_btop ;;
        *) blocked "No verified user-only fallback for $name. Homebrew may need separately provisioned developer tools for its source build." ;;
    esac
}

install_lima_release() {
    local release version url checksum directory target
    release="$(github_release lima-vm/lima | support release '^lima-[0-9.]+-Darwin-(arm64|aarch64)\.tar\.gz$')" || return
    IFS=$'\t' read -r version url checksum <<< "$release"
    directory="$(work_dir)" || return
    download "$url" "$directory/lima.tar.gz" || return
    verify_sha256 "$directory/lima.tar.gz" "$checksum" || return
    extract_archive "$directory/lima.tar.gz" "$directory/unpacked" || return
    target="$DATA_DIR/lima-release"
    snapshot_path "$target" || return
    support replace-tree "$directory/unpacked" "$target" || return
    seal_path "$target" || return
    managed_link "$LOCAL_BIN/limactl" "$target/bin/limactl" || return
    record_version Lima "$version" stable
}

build_btop() {
    local directory version
    xcode-select -p >/dev/null 2>&1 || blocked "btop has no upstream macOS binary; its source build needs pre-provisioned developer tools."
    directory="$(work_dir)" || return
    version="$(github_release aristocratos/btop | support release)" || return
    git clone --quiet --depth 1 --branch "$version" https://github.com/aristocratos/btop.git "$directory/source" || return
    make -C "$directory/source" -j2 PREFIX="$DATA_DIR/btop" || return
    managed_executable "$directory/source/bin/btop" "$LOCAL_BIN/btop" || return
    record_command_version btop "$version" "$LOCAL_BIN/btop" --version
}

verify_app() {
    [[ -f "$1/Contents/Info.plist" ]] || { log_error "Incomplete application: $1"; return 1; }
    codesign --verify --deep --strict "$1" || return
    spctl --assess --type execute "$1" || { log_error "Application requires security approval: $1"; return 1; }
    app_version "$1" >/dev/null
}

install_app() {
    require_apply_context
    local name="$1" app="$2" existing="" metadata version url checksum directory asset archive_format mount="" source status=0
    existing="$(find_app "$app")" || existing=""
    if [[ -n "$existing" ]]; then
        if [[ "$MODE" != update ]] || { ! owned_path "$existing" && ! support package-owned cask "$name"; }; then
            verify_app "$existing"
            record_command_version "$name" stable app_version "$existing"
            return
        fi
    fi
    if ! owned_path "$APP_DIR/$app" && try_brew_package cask "$name" "$app"; then
        existing="$(find_app "$app")" || { log_error "Homebrew did not produce $app."; return 1; }
        verify_app "$existing"
        record_command_version "$name" stable app_version "$existing"
        return
    fi
    log_warn "Trying the verified upstream app bundle for $name."
    metadata="$(package_metadata cask "$name")"
    printf '%s' "$metadata" | support package-policy bundle
    version="$(printf '%s' "$metadata" | support json version)"
    url="$(printf '%s' "$metadata" | support json url)"
    checksum="$(printf '%s' "$metadata" | support json sha256)"
    directory="$(work_dir)"
    asset="$directory/download"
    download "$url" "$asset"
    if [[ "$checksum" != no_check ]]; then verify_sha256 "$asset" "$checksum"; fi
    archive_format="$(support archive-format "$asset")"
    mv "$asset" "$asset.$archive_format"
    asset="$asset.$archive_format"
    case "$archive_format" in
        dmg)
            mount="$directory/mount"
            mkdir "$mount"
            : > "$directory/.mounted"
            hdiutil attach -nobrowse -readonly -mountpoint "$mount" "$asset" </dev/null
            source="$mount/$app"
            ;;
        zip|tar.gz|tar.xz)
            extract_archive "$asset" "$directory/unpacked"
            source="$(find "$directory/unpacked" -type d -name "$app" -prune -print)"
            [[ -n "$source" && "$source" != *$'\n'* ]] || blocked "No unique $app in the upstream archive."
            ;;
        *) blocked "Upstream $name requires an unsupported or privileged installer." ;;
    esac
    if ! verify_app "$source"; then status=1; fi
    if [[ "$status" -eq 0 ]]; then
        ditto "$source" "$directory/staged.app" || status=$?
    fi
    if [[ -n "$mount" ]]; then
        hdiutil detach "$mount" || blocked "Could not detach $mount; staging was retained safely."
        rm "$directory/.mounted"
    fi
    [[ "$status" -eq 0 ]] || return "$status"
    snapshot_path "$APP_DIR/$app"
    support replace-tree "$directory/staged.app" "$APP_DIR/$app"
    seal_path "$APP_DIR/$app"
    verify_app "$APP_DIR/$app"
    record_command_version "$name" "$version" app_version "$APP_DIR/$app"
}

install_git_checkout() {
    require_apply_context
    local repository="$1" target="$2" branch="$3" directory revision tracked
    assert_user_path "$target" || return
    if [[ -d "$target" ]]; then
        if [[ "$MODE" != update ]] || ! owned_path "$target"; then
            revision="$(git -C "$target" rev-parse HEAD)" || return
            record_version "$repository" "$revision" "$branch" || return
            return 0
        fi
        support retain-modified "$target" || return
        tracked="$(GIT_OPTIONAL_LOCKS=0 git -C "$target" status --porcelain --untracked-files=no)" || return
        [[ -z "$tracked" ]] ||
            { log_error "Tracked files were edited; preserving $target"; return 1; }
    fi
    directory="$(work_dir)" || return
    git clone --quiet --depth 1 --branch "$branch" "https://github.com/$repository.git" "$directory/checkout" || return
    revision="$(git -C "$directory/checkout" rev-parse HEAD)" || return
    if [[ -d "$target" ]] && [[ "$(git -C "$target" rev-parse HEAD)" == "$revision" ]]; then
        record_version "$repository" "$revision" "$branch" || return
        return 0
    fi
    snapshot_path "$target" || return
    if [[ -d "$target" ]]; then
        git -C "$target" fetch --quiet --depth 1 origin "$branch" || return
        git -C "$target" checkout --quiet --detach FETCH_HEAD || return
    else
        support replace-tree "$directory/checkout" "$target" || return
    fi
    seal_path "$target" || return
    record_version "$repository" "$revision" "$branch"
}
