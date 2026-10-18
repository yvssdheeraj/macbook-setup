#!/usr/bin/env bats

setup() {
    load 'bats-support/load'
    load 'bats-assert/load'
    DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
}

@test "preflight passes with bypassed OS checks" {
    export CI_BYPASS_OS_CHECK=1
    run bash -c "source scripts/preflight.sh && preflight_checks"
    assert_success
    assert_output --partial "Preflight checks passed."
}

@test "preflight fails on non-macOS if not bypassed" {
    export CI_BYPASS_OS_CHECK=""
    # Assuming the runner is Linux
    run bash -c "source scripts/preflight.sh && preflight_checks"
    assert_failure
    assert_output --partial "This setup is intended for macOS only."
}
