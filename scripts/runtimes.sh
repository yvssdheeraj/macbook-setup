#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/packages.sh"

install_node() {
    require_apply_context
    local release current target="" candidate manager_owned=false
    if [[ ! -s "$NVM_DIR/nvm.sh" ]] || { [[ "$MODE" == update ]] && owned_path "$NVM_DIR"; }; then
        release="$(github_release nvm-sh/nvm | support release)"
        install_git_checkout nvm-sh/nvm "$NVM_DIR" "$release"
    fi
    [[ -s "$NVM_DIR/nvm.sh" ]] || blocked "Existing NVM directory is incomplete: $NVM_DIR"
    if owned_path "$NVM_DIR"; then
        manager_owned=true
        support retain-modified "$NVM_DIR"
    fi
    # Upstream shell managers are not nounset-clean.
    set +u
    source "$NVM_DIR/nvm.sh"
    local status=0
    current="$(nvm current)" || status=$?
    [[ "$status" -eq 0 || ( "$status" -eq 3 && "$current" == none ) ]] || blocked "NVM could not inspect the current Node installation."
    if [[ "$NODE_VERSION" != 'lts/*' ]]; then target="$(nvm version-remote "$NODE_VERSION")"; fi
    if [[ "$MODE" != update && "$current" == v* && ( "$NODE_VERSION" == 'lts/*' || "$target" == "$current" ) ]]; then
        node --version
        record_command_version Node "$NODE_VERSION" node --version
        [[ "$manager_owned" != true ]] || support seal "$NVM_DIR"
        set -u
        return
    fi
    if [[ "$MODE" == update && "$current" == v* && "$manager_owned" != true && ( "$NODE_VERSION" == 'lts/*' || "$target" == "$current" ) ]] &&
        ! owned_path "$(nvm which current)"; then
        log_info "Preserving pre-existing Node installation."
        record_command_version Node "$NODE_VERSION" node --version
        set -u
        return
    fi
    if [[ -z "$target" ]]; then target="$(nvm version-remote "$NODE_VERSION")"; fi
    [[ "$target" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || blocked "Cannot resolve Node channel $NODE_VERSION."
    candidate="$NVM_DIR/versions/node/$target"
    if [[ "$manager_owned" != true ]]; then snapshot_path "$NVM_DIR/alias/default"; fi
    if [[ ! -x "$candidate/bin/node" ]]; then
        if [[ "$manager_owned" != true ]]; then snapshot_path "$candidate"; fi
        nvm install "$target" </dev/null
        if [[ "$manager_owned" != true ]]; then seal_path "$candidate"; else mark_changed; fi
    fi
    nvm use "$target"
    if [[ "$manager_owned" == true ]]; then
        nvm alias default "$target"
        support seal "$NVM_DIR"
    else
        printf '%s\n' "$target" | managed_file "$NVM_DIR/alias/default"
        support seal "$NVM_DIR/alias/default"
    fi
    node --version
    record_command_version Node "$NODE_VERSION" node --version
    set -u
}

install_python() {
    require_apply_context
    install_formula uv uv
    export UV_PYTHON_INSTALL_DIR="$DATA_DIR/python"
    export UV_PYTHON_BIN_DIR="$DATA_DIR/python-bin"
    export UV_NO_MODIFY_PATH=1
    local current="" target python_request="$PYTHON_VERSION" python_root_owned=false bin_owned=false
    [[ "$python_request" != stable ]] || python_request=cpython
    if [[ -d "$UV_PYTHON_INSTALL_DIR" ]]; then
        current="$(uv python find --no-config --system --managed-python --offline --no-python-downloads "$python_request" 2>/dev/null)" || current=""
        if owned_path "$UV_PYTHON_INSTALL_DIR"; then
            python_root_owned=true
            support retain-modified "$UV_PYTHON_INSTALL_DIR"
        elif [[ "$MODE" == update || -z "$current" ]]; then
            blocked "Cannot add or update Python in an unowned directory: $UV_PYTHON_INSTALL_DIR"
        fi
    else
        snapshot_path "$UV_PYTHON_INSTALL_DIR"
        python_root_owned=true
    fi
    if [[ -z "$current" || "$MODE" == update ]]; then
        if [[ ! -d "$UV_PYTHON_BIN_DIR" ]]; then
            snapshot_path "$UV_PYTHON_BIN_DIR"
            bin_owned=true
        elif owned_path "$UV_PYTHON_BIN_DIR"; then
            support retain-modified "$UV_PYTHON_BIN_DIR"
            bin_owned=true
        else
            blocked "Cannot modify an unowned Python binary directory: $UV_PYTHON_BIN_DIR"
        fi
        target="$(uv python list --no-config --all-versions --output-format json "$python_request" | support python-version)"
        uv python install --no-config "$target"
        current="$(uv python find --no-config --system --managed-python --offline --no-python-downloads "$target")"
        [[ "$python_root_owned" != true ]] || seal_path "$UV_PYTHON_INSTALL_DIR"
        [[ "$bin_owned" != true || ! -d "$UV_PYTHON_BIN_DIR" ]] || seal_path "$UV_PYTHON_BIN_DIR"
    fi
    "$current" --version
    record_command_version Python "$PYTHON_VERSION" "$current" --version
}

load_sdkman() {
    require_apply_context
    local directory sdk_owned=false
    if [[ ! -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]]; then
        [[ ! -e "$SDKMAN_DIR" ]] || blocked "Existing SDKMAN directory is incomplete: $SDKMAN_DIR"
        snapshot_path "$SDKMAN_DIR"
        directory="$(work_dir)"
        download 'https://get.sdkman.io?ci=true&rcupdate=false' "$directory/sdkman-install.sh"
        log_info "Running SDKMAN's official HTTPS installer with shell modifications disabled."
        bash "$directory/sdkman-install.sh" </dev/null
        seal_path "$SDKMAN_DIR"
    fi
    if owned_path "$SDKMAN_DIR"; then
        sdk_owned=true
        support retain-modified "$SDKMAN_DIR"
    fi
    set +u
    source "$SDKMAN_DIR/bin/sdkman-init.sh"
    export sdkman_auto_answer=true sdkman_colour_enable=false sdkman_selfupdate_feature=false
    if [[ "$MODE" == update && "$sdk_owned" == true ]]; then
        sdk selfupdate </dev/null
    fi
}

install_sdk_candidate() {
    local candidate="$1" requested="$2" target="$2" manager_owned=false directory current="" major releases current_matches=true version_argument=--version
    [[ "$candidate" != java ]] || version_argument=-version
    load_sdkman
    if owned_path "$SDKMAN_DIR"; then manager_owned=true; fi
    directory="$SDKMAN_DIR/candidates/$candidate"
    if [[ -x "$directory/current/bin/$candidate" ]]; then
        current="$(cd "$directory/current" && pwd -P)"
        if [[ "$candidate" == java && "$requested" == lts ]]; then
            major="${current##*/}"
            [[ "$JAVA_LTS" == latest || "${major%%.*}" == "$JAVA_LTS" ]] || current_matches=false
        elif [[ "$requested" != stable && "${current##*/}" != "$requested" ]]; then
            current_matches=false
        fi
        if [[ "$current_matches" == true ]] &&
            { [[ "$MODE" != update ]] || { [[ "$manager_owned" != true ]] && ! owned_path "$current"; }; }; then
            record_command_version "$candidate" "$requested" "$current/bin/$candidate" "$version_argument"
            [[ "$manager_owned" != true ]] || support seal "$SDKMAN_DIR"
            set -u
            return
        fi
    fi
    if [[ "$candidate" == java && "$target" == lts ]]; then
        major="$JAVA_LTS"
        if [[ "$major" == latest && "$MODE" == update && -n "$current" ]]; then
            major="${current##*/}"
            major="${major%%.*}"
        fi
        if [[ "$major" == latest ]]; then
            releases="$(work_dir)"
            download https://api.adoptium.net/v3/info/available_releases "$releases/java.json"
            major="$(ruby -rjson -e 'puts JSON.parse(File.read(ARGV[0])).fetch("available_lts_releases").max' "$releases/java.json")"
        fi
        target="$(sdk list java | support sdk-java "$major")"
    elif [[ "$candidate" == gradle && "$target" == stable ]]; then
        target="$(sdk list gradle | support sdk-gradle)"
    fi
    [[ "$target" =~ ^[0-9][a-zA-Z0-9._-]*$ ]] || blocked "Invalid resolved $candidate version: $target"
    if [[ "$manager_owned" != true ]]; then snapshot_path "$directory/current"; fi
    if [[ ! -x "$directory/$target/bin/$candidate" ]]; then
        if [[ "$manager_owned" != true ]]; then snapshot_path "$directory/$target"; fi
        sdk install "$candidate" "$target" </dev/null
        if [[ "$manager_owned" != true ]]; then seal_path "$directory/$target"; else mark_changed; fi
    fi
    if [[ "$candidate" == gradle ]]; then
        [[ -x "$SDKMAN_DIR/candidates/java/current/bin/java" ]] || blocked "Gradle requires a working selected Java installation."
        export JAVA_HOME="$SDKMAN_DIR/candidates/java/current"
        "$directory/$target/bin/gradle" --version || blocked "Latest Gradle is incompatible with the selected Java. Use the project's Gradle Wrapper or select a compatible GRADLE_VERSION."
    else
        "$directory/$target/bin/java" -version
    fi
    if [[ "$manager_owned" == true ]]; then
        sdk default "$candidate" "$target"
        support seal "$SDKMAN_DIR"
    else
        managed_link "$directory/current" "$directory/$target"
    fi
    record_command_version "$candidate" "$requested" "$directory/$target/bin/$candidate" "$version_argument"
    set -u
}
