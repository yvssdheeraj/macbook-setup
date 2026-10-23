#!/usr/bin/env bats
load helpers

setup() { setup_fixture; }

@test "invalid and incomplete arguments return failure without writes" {
    for argument in --unknown --only --skip --config; do
        run bash setup.sh "$argument"
        assert_failure
    done
    [[ ! -d "$STATE_DIR" ]]
}

@test "unknown components and explicit dependency conflicts are rejected" {
    run bash setup.sh --dry-run --only typo
    assert_failure
    run bash setup.sh --dry-run --only gradle --skip java
    assert_failure
    assert_output --partial 'explicitly skipped'
    [[ ! -d "$STATE_DIR" ]]
}

@test "aliases expand and desktop preferences remain opt-in" {
    run bash setup.sh --dry-run --only browsers,cli-tools
    assert_success
    assert_output --partial 'Components: chrome duckduckgo gh aws'
    run bash setup.sh --dry-run
    assert_success
    refute_output --partial '[DRY-RUN] install wallpaper'
    refute_output --partial '[DRY-RUN] install dock;'
}

@test "Git setup is idempotent and preserves unrelated global configuration" {
    printf '[alias]\n    personal = status\n' > "$HOME/.gitconfig"
    run bash setup.sh --only git
    assert_success
    [[ "$(latest_report_status)" == changed ]]
    run bash setup.sh --only git
    assert_success
    [[ "$(latest_report_status)" == unchanged ]]
    [[ "$(git config --global alias.personal)" == status ]]
    [[ "$(git config --global --includes user.name)" == 'Setup Test' ]]
}

@test "Git identity changes can be updated without losing the original configuration" {
    printf '[user]\n    name = Original\n    email = original@example.invalid\n' > "$HOME/.gitconfig"
    run bash setup.sh --only git
    assert_success
    export GIT_USER_NAME="Updated Test"
    run bash setup.sh --only git
    assert_success
    [[ "$(git config --global --includes user.name)" == 'Updated Test' ]]
    run bash uninstall.sh --yes
    assert_success
    [[ "$(git config --global user.name)" == Original ]]
}

@test "missing required identity produces a failed report rather than setup complete" {
    unset GIT_USER_NAME GIT_USER_EMAIL
    run bash setup.sh --only git
    assert_failure
    assert_output --partial 'Setup is incomplete'
    [[ "$(latest_report_status)" == blocked ]]
    [[ ! -d "$STATE_DIR/lock" ]]
}

@test "selected validation fails for missing tools without creating reports" {
    run bash setup.sh --validate --only java
    assert_failure
    [[ ! -d "$STATE_DIR" ]]
}

@test "uninstall without ownership does not remove pre-existing applications" {
    mkdir -p "$APP_DIR/Maccy.app"
    run bash uninstall.sh --yes
    assert_success
    [[ -d "$APP_DIR/Maccy.app" ]]
}

@test "a second process cannot enter an active setup run" {
    mkdir -p "$STATE_DIR/lock"
    printf '123456\n' > "$STATE_DIR/lock/pid"
    run bash setup.sh --only git
    assert_failure
    assert_output --partial 'holds'
    [[ "$(cat "$STATE_DIR/lock/pid")" == 123456 ]]
}
