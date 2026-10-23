#!/usr/bin/env bats
# shellcheck disable=SC2016
load helpers

setup() { setup_fixture; }

@test "a checksum mismatch prevents promotion of a downloaded executable" {
    printf 'not the expected release' > "$HOME/download"
    fixture_run 'source scripts/packages.sh; verify_sha256 "$HOME/download" 0000000000000000000000000000000000000000000000000000000000000000'
    assert_failure
    assert_output --partial 'SHA256 mismatch'
    [[ ! -e "$LOCAL_BIN/gh" ]]
}

@test "HTTP errors stop downloads and cannot produce success-shaped installs" {
    fixture_run 'source scripts/packages.sh; download https://example.invalid/release "$RUN_DIR/release"; printf "not reached\n"'
    assert_failure
    refute_output --partial 'not reached'
}

@test "existing tools outside the managed prefix are reused without downloads or adoption" {
    stub gh 'echo "gh version 9.0.0"'
    run bash setup.sh --only gh
    assert_success
    assert_output --partial 'Using existing gh'
    [[ ! -e "$COMMAND_LOG" ]]
    run bash setup.sh --update --only gh
    assert_success
    [[ ! -e "$COMMAND_LOG" ]]
}

@test "a failed version probe cannot produce a successful component report" {
    stub gh 'echo "broken executable" >&2; exit 4'
    run bash setup.sh --only gh
    assert_failure
    assert_output --partial 'Version probe failed'
    [[ "$(latest_report_status)" == failed ]]
}

@test "privileged cask artifacts are rejected rather than unpacked" {
    fixture_run 'printf "%s" "{\"artifacts\":[{\"pkg\":[\"installer.pkg\"]}]}" | support package-policy cask'
    assert_failure
    assert_output --partial 'unsupported installer'
}

@test "uninstall scripts are blocked for Homebrew but ignored when copying only an app bundle" {
    export CASK_METADATA='{"artifacts":[{"app":["Example.app"]},{"uninstall":[{"script":{"executable":"privileged-helper"}}]}]}'
    fixture_run 'printf "%s" "$CASK_METADATA" | support package-policy cask'
    assert_failure
    assert_output --partial 'unsupported uninstall hooks'
    fixture_run 'printf "%s" "$CASK_METADATA" | support package-policy bundle'
    assert_success
}

@test "application container detection does not depend on a download URL extension" {
    printf 'PK\003\004archive' > "$HOME/stable"
    fixture_run 'support archive-format "$HOME/stable"'
    assert_success
    assert_output 'zip'
    printf 'xar!installer' > "$HOME/stable"
    fixture_run 'support archive-format "$HOME/stable"'
    assert_failure
    assert_output --partial 'Unsupported application container'
}

@test "a cask application changed by its updater is retained even if its brew receipt is unchanged" {
    mkdir -p "$BREW_PREFIX/bin" "$APP_DIR/Example.app"
    printf 'original\n' > "$APP_DIR/Example.app/version"
    stub brew 'case "$1" in list) echo "example 1.0";; uninstall) touch "$HOME/uninstalled";; *) exit 2;; esac'
    cp "$BATS_TEST_TMPDIR/bin/brew" "$BREW_PREFIX/bin/brew"
    fixture_run 'support package cask example 1.0 "$BREW_PREFIX"; support package-app example "$APP_DIR/Example.app"; printf "updated\n" > "$APP_DIR/Example.app/version"; support uninstall'
    assert_failure
    assert_output --partial 'Retaining application changed outside setup'
    [[ ! -e "$HOME/uninstalled" && -d "$APP_DIR/Example.app" ]]
}

@test "release resolution chooses the matching current architecture asset and digest" {
    fixture_run 'printf "%s" "{\"tag_name\":\"v9.0.0\",\"draft\":false,\"prerelease\":false,\"assets\":[{\"name\":\"tool-arm64.tar.gz\",\"browser_download_url\":\"https://example.invalid/tool-arm64.tar.gz\",\"digest\":\"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\"}]}" | support release "^tool-arm64"'
    assert_success
    assert_output --partial 'v9.0.0'
    assert_output --partial 'https://example.invalid/tool-arm64.tar.gz'
}

@test "an unverified release asset is rejected" {
    fixture_run 'printf "%s" "{\"tag_name\":\"v9.0.0\",\"assets\":[{\"name\":\"tool-arm64\",\"browser_download_url\":\"https://example.invalid/tool\"}]}" | support release "tool-arm64"'
    assert_failure
    assert_output --partial 'no SHA256 digest'
}

@test "archive traversal is rejected before extraction" {
    fixture_run 'printf "../outside\n" | support archive-paths'
    assert_failure
    assert_output --partial 'Unsafe archive member'
}

@test "stable runtime resolution excludes prereleases and picks the latest matching LTS patch" {
    fixture_run 'printf "21.0.8-tem | 25.0.1-tem | 25.0.2-tem | 26-ea\n" | support sdk-java 25; printf "8.9 9.0-rc-1 9.0.0 8.10.2\n" | support sdk-gradle'
    assert_success
    assert_output --partial '25.0.2-tem'
    assert_output --partial '9.0.0'
}
