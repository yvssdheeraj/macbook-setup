#!/usr/bin/env bats

setup() {
    load 'bats-support/load'
    load 'bats-assert/load'
    DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
    PATH="$DIR/../scripts/utils:$PATH"

    # Mock date
    date() { echo "20230101_120000"; }
    export -f date
}

@test "logging outputs correctly" {
    run bash -c 'source scripts/utils/logging.sh && log_info "Test message"'
    assert_output --partial "Test message"
    assert_output --partial "[INFO]"
}

@test "backup file creates backup with timestamp" {
    # Create temp file
    temp_file="$(mktemp)"
    echo "test" > "$temp_file"

    run bash -c "source scripts/utils/backup.sh && backup_file \"$temp_file\""

    # Verify backup exists
    assert [ -f "${temp_file}.backup_20230101_120000" ]

    rm -f "$temp_file" "${temp_file}.backup_20230101_120000"
}
