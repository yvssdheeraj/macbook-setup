#!/usr/bin/env bats
# shellcheck disable=SC2016
load helpers

setup() { setup_fixture; }

@test "a fresh NVM with no Node installs successfully and removal preserves the existing manager" {
    mkdir -p "$NVM_DIR"
    cp tests/fixtures/nvm.sh "$NVM_DIR/nvm.sh"
    run bash setup.sh --only node
    assert_success
    [[ -x "$NVM_DIR/versions/node/v24.2.0/bin/node" ]]
    [[ "$(cat "$NVM_DIR/alias/default")" == v24.2.0 ]]
    run bash setup.sh --only node
    assert_success
    [[ "$(latest_report_status)" == unchanged ]]
    run bash setup.sh --validate --only node
    assert_success
    run bash uninstall.sh --yes
    assert_success
    [[ -f "$NVM_DIR/nvm.sh" ]]
    [[ ! -e "$NVM_DIR/alias/default" ]]
    [[ ! -d "$NVM_DIR/versions/node/v24.2.0" ]]
}

@test "a failed Java dependency blocks Gradle without invoking its installer" {
    mkdir -p "$SDKMAN_DIR"
    run bash setup.sh --only gradle
    assert_failure
    assert_output --partial 'gradle has a failed dependency'
    [[ "$(latest_report_status)" == blocked ]]
}

@test "an explicit Node request is installed alongside an existing default and restores that default" {
    mkdir -p "$NVM_DIR/versions/node/v22.1.0/bin" "$NVM_DIR/alias"
    cp tests/fixtures/nvm.sh "$NVM_DIR/nvm.sh"
    printf '#!/usr/bin/env bash\necho v22.1.0\n' > "$NVM_DIR/versions/node/v22.1.0/bin/node"
    chmod +x "$NVM_DIR/versions/node/v22.1.0/bin/node"
    printf 'v22.1.0\n' > "$NVM_DIR/alias/default"
    export NODE_VERSION=24
    run bash setup.sh --only node
    assert_success
    [[ "$(cat "$NVM_DIR/alias/default")" == v24.2.0 ]]
    run bash uninstall.sh --yes
    assert_success
    [[ "$(cat "$NVM_DIR/alias/default")" == v22.1.0 ]]
    [[ -x "$NVM_DIR/versions/node/v22.1.0/bin/node" ]]
}

@test "missing Python versions are not added to an unowned installation directory" {
    mkdir -p "$DATA_DIR/python"
    stub uv 'if [[ "$1" == --version ]]; then echo "uv 1.0"; else exit 1; fi'
    run bash setup.sh --only python
    assert_failure
    assert_output --partial 'Cannot add or update Python in an unowned directory'
    [[ "$(latest_report_status)" == blocked ]]
}

@test "Python updates resolve a new concrete stable version instead of accepting the installed version" {
    export MOCK_PYTHON_LATEST=3.14.1
    stub uv '
if [[ "$1" == --version ]]; then echo "uv 1.0"; exit 0; fi
case "$2" in
    find)
        [[ -f "$UV_PYTHON_INSTALL_DIR/selected" ]] || exit 1
        version="$(cat "$UV_PYTHON_INSTALL_DIR/selected")"
        printf "%s/cpython-%s/bin/python3\n" "$UV_PYTHON_INSTALL_DIR" "$version";;
    list)
        printf "[{\"key\":\"cpython-%s-macos-aarch64-none\",\"version\":\"%s\"}]\n" "$MOCK_PYTHON_LATEST" "$MOCK_PYTHON_LATEST";;
    install)
        version="${@: -1}"
        printf "python install %s\n" "$version" >> "$COMMAND_LOG"
        mkdir -p "$UV_PYTHON_INSTALL_DIR/cpython-$version/bin" "$UV_PYTHON_BIN_DIR"
        printf "#!/usr/bin/env bash\necho Python %s\n" "$version" > "$UV_PYTHON_INSTALL_DIR/cpython-$version/bin/python3"
        chmod +x "$UV_PYTHON_INSTALL_DIR/cpython-$version/bin/python3"
        printf "%s\n" "$version" > "$UV_PYTHON_INSTALL_DIR/selected";;
    *) exit 2;;
esac'
    run bash setup.sh --only python
    assert_success
    export MOCK_PYTHON_LATEST=3.14.2
    run bash setup.sh --only python
    assert_success
    [[ "$(cat "$DATA_DIR/python/selected")" == 3.14.1 ]]
    run bash setup.sh --update --only python
    assert_success
    [[ "$(cat "$DATA_DIR/python/selected")" == 3.14.2 ]]
    run bash uninstall.sh --yes
    assert_success
    [[ ! -d "$DATA_DIR/python" ]]
}

@test "a new symlink can reference an existing system executable without owning its target" {
    fixture_run 'managed_link "$HOME/tool" /bin/bash; support uninstall'
    assert_success
    [[ ! -e "$HOME/tool" ]]
    [[ -x /bin/bash ]]
}

@test "replacing an existing symlink restores the original link on removal" {
    printf 'original\n' > "$HOME/original"
    printf 'new\n' > "$HOME/new"
    ln -s original "$HOME/tool"
    fixture_run 'managed_link "$HOME/tool" "$HOME/new"; support uninstall'
    assert_success
    [[ -L "$HOME/tool" && "$(readlink "$HOME/tool")" == original ]]
}

@test "updating a directly owned binary does not migrate it into Homebrew" {
    mkdir -p "$LOCAL_BIN"
    printf '#!/usr/bin/env bash\necho old\n' > "$HOME/old"
    fixture_run 'managed_executable "$HOME/old" "$LOCAL_BIN/uv"'
    assert_success
    fixture_run 'export MODE=update; source scripts/packages.sh; install_release_binary() { printf "direct update\n"; }; try_brew_package() { printf "unexpected migration\n"; return 1; }; install_formula uv uv'
    assert_success
    assert_output --partial 'direct update'
    refute_output --partial 'unexpected migration'
}
