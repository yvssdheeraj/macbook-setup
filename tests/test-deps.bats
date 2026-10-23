#!/usr/bin/env bats
# shellcheck disable=SC2016,SC2030,SC2031
load helpers

setup() { setup_fixture; }

copy_test_cache() {
    local dependency
    mkdir -p "$HOME/test dependencies"
    for dependency in "$BATS_CORE_DIR" "$BATS_SUPPORT_DIR" "$BATS_ASSERT_DIR"; do
        cp -R "$dependency" "$HOME/test dependencies/"
    done
    export TEST_DEPS_DIR="$HOME/test dependencies"
}

@test "cached test dependencies work offline with spaces in their path" {
    copy_test_cache
    mkdir "$TEST_DEPS_DIR/.lock"
    printf 'other bootstrap\n' > "$TEST_DEPS_DIR/.lock/pid"
    run make test-deps
    assert_success
    run bash scripts/test-deps.sh --run --version
    assert_success
    assert_output --partial 'Bats '
    [[ ! -e "$COMMAND_LOG" ]]
    [[ "$(cat "$TEST_DEPS_DIR/.lock/pid")" == 'other bootstrap' ]]
}

@test "a test dependency checksum mismatch prevents extraction and cleans staging" {
    export TEST_DEPS_DIR="$HOME/test dependencies"
    stub curl '
while [[ $# -gt 0 ]]; do
    if [[ "$1" == --output ]]; then
        printf "tampered archive\n" > "$2"
        exit 0
    fi
    shift
done
exit 2'
    stub tar 'touch "$HOME/extracted"; exit 0'
    run make test-deps
    assert_failure
    assert_output --partial 'SHA256 mismatch'
    [[ ! -e "$HOME/extracted" && ! -e "$TEST_DEPS_DIR/.lock" ]]
    [[ -z "$(find "$TEST_DEPS_DIR" -mindepth 1 -print)" ]]
}

@test "a failed test dependency download cannot publish a partial installation" {
    export TEST_DEPS_DIR="$HOME/test dependencies"
    run make test-deps
    assert_failure
    [[ -z "$(find "$TEST_DEPS_DIR" -mindepth 1 -print)" ]]
}

@test "an incomplete existing test cache is preserved and reported rather than adopted" {
    copy_test_cache
    rm "$TEST_DEPS_DIR/$(basename "$BATS_CORE_DIR")/bin/bats"
    run make test-deps
    assert_failure
    assert_output --partial 'Incomplete test dependency cache'
    [[ -d "$TEST_DEPS_DIR" && ! -e "$TEST_DEPS_DIR/.lock" ]]
    [[ ! -e "$COMMAND_LOG" ]]
}

@test "a test dependency cache outside HOME is rejected without writes" {
    export TEST_DEPS_DIR="$BATS_TEST_TMPDIR/outside"
    run make test-deps
    assert_failure
    assert_output --partial 'escapes HOME'
    [[ ! -e "$TEST_DEPS_DIR" ]]
}
