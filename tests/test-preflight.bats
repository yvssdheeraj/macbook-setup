#!/usr/bin/env bats
# shellcheck disable=SC2016,SC2030,SC2031
load helpers

setup() { setup_fixture; }

@test "a supported read-only plan includes runtime dependencies without writes" {
    before="$(home_digest)"
    run bash setup.sh --dry-run --only gradle
    assert_success
    assert_output --partial 'Components: java gradle'
    [[ "$(home_digest)" == "$before" ]]
    [[ ! -e "$COMMAND_LOG" ]]
}

@test "OS bypass cannot enable real installations on Linux" {
    export TEST_OS=Linux CI_BYPASS_OS_CHECK=1
    run bash setup.sh --only git
    assert_failure
    assert_output --partial 'OS bypass is allowed only for a dry-run'
    [[ ! -d "$STATE_DIR" ]]
}

@test "OS bypass is limited to read-only CI plans" {
    export TEST_OS=Linux CI_BYPASS_OS_CHECK=1
    run bash setup.sh --dry-run --only git
    assert_success
    [[ ! -d "$STATE_DIR" ]]
}

@test "Intel architecture is rejected without bypass" {
    export TEST_ARCH=x86_64
    run bash setup.sh --dry-run --only git
    assert_failure
    assert_output --partial 'Apple Silicon'
}

@test "a system-prefix override is rejected before changes" {
    export BREW_PREFIX=/opt/homebrew
    run bash setup.sh --dry-run --only git
    assert_failure
    assert_output --partial 'escapes HOME'
    [[ ! -d "$STATE_DIR" ]]
}

@test "relative installation paths are rejected before changes" {
    export LOCAL_BIN=relative-bin
    run bash setup.sh --dry-run --only git
    assert_failure
    assert_output --partial 'must be an absolute path'
    [[ ! -d "$STATE_DIR" && ! -d relative-bin ]]
}

@test "a home directory symlink cannot redirect installations outside HOME" {
    mkdir -p "$BATS_TEST_TMPDIR/outside"
    ln -s "$BATS_TEST_TMPDIR/outside" "$HOME/redirect"
    export LOCAL_BIN="$HOME/redirect/bin"
    run bash setup.sh --dry-run --only git
    assert_failure
    assert_output --partial 'escapes HOME'
}

@test "data-only configuration rejects commands without executing them" {
    printf 'GIT_USER_NAME="$(touch %s/pwned)"\n' "$HOME" > "$BATS_TEST_TMPDIR/user.env"
    run bash setup.sh --dry-run --only git --config "$BATS_TEST_TMPDIR/user.env"
    assert_failure
    assert_output --partial 'shell expansion is not supported'
    [[ ! -e "$HOME/pwned" ]]
}

@test "configuration supports quoted hashes and comments without overriding the environment" {
    unset GIT_USER_NAME
    printf 'GIT_USER_NAME="# Personal Name" # comment\nJAVA_LTS="21"\n' > "$BATS_TEST_TMPDIR/user.env"
    run bash -c 'set -euo pipefail; source scripts/common.sh; load_configuration "$1"; printf "%s|%s\n" "$GIT_USER_NAME" "$JAVA_LTS"' -- "$BATS_TEST_TMPDIR/user.env"
    assert_success
    assert_output '# Personal Name|21'
    export JAVA_LTS=25
    run bash setup.sh --dry-run --only java --config "$BATS_TEST_TMPDIR/user.env"
    assert_success
}

@test "invalid resource values fail before writes" {
    export COLIMA_MEMORY=0
    run bash setup.sh --dry-run --only docker
    assert_failure
    assert_output --partial 'positive integer'
    [[ ! -d "$STATE_DIR" ]]
}
