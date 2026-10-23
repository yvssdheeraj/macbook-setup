#!/usr/bin/env bats
# shellcheck disable=SC2016
load helpers

setup() {
    [[ "${RUN_UPSTREAM_TESTS:-}" == 1 ]] || skip 'Set RUN_UPSTREAM_TESTS=1 for read-only network compatibility checks.'
    setup_fixture
    stub curl 'exec /usr/bin/curl "$@"'
}

@test "current application catalog contains user-only stable distributions" {
    fixture_run 'source scripts/packages.sh; for name in ghostty maccy visual-studio-code intellij-idea dbeaver-community google-chrome duckduckgo; do package_metadata cask "$name" | support package-policy bundle; done'
    assert_success
}

@test "current runtime and CLI release metadata resolves supported ARM64 assets" {
    fixture_run 'source scripts/packages.sh; github_release nvm-sh/nvm | support release; github_release cli/cli | support release "^gh_.*_macOS_arm64\\.zip$"; github_release astral-sh/uv | support release "^uv-aarch64-apple-darwin\\.tar\\.gz$"; github_release abiosoft/colima | support release "^colima-Darwin-(arm64|aarch64)$"; github_release lima-vm/lima | support release "^lima-[0-9.]+-Darwin-(arm64|aarch64)\\.tar\\.gz$"'
    assert_success
}
