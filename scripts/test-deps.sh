#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export TEST_DEPS_DIR="${TEST_DEPS_DIR:-$HOME/Library/Caches/macbook-setup/test-deps}"
run_tests=false
case "${1:-}" in
    '') ;;
    --run) run_tests=true; shift ;;
    *) printf 'Usage: bash scripts/test-deps.sh [--run BATS_ARGUMENTS...]\n' >&2; exit 2 ;;
esac

[[ "$TEST_DEPS_DIR" == /* ]] || { printf 'TEST_DEPS_DIR must be an absolute path.\n' >&2; exit 1; }
TEST_DEPS_DIR="$(ruby "$REPO_ROOT/scripts/support.rb" path "$TEST_DEPS_DIR")"
umask 077
mkdir -p "$TEST_DEPS_DIR"
staging=""
lock_owned=false
cleanup() {
    local status=$?
    if [[ -n "$staging" && -d "$staging" ]]; then
        rm -rf -- "$staging" || status=1
    fi
    if [[ "$lock_owned" == true ]]; then
        rm -f -- "$TEST_DEPS_DIR/.lock/pid" || status=1
        rmdir "$TEST_DEPS_DIR/.lock" || status=1
    fi
    return "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

dependency_complete() {
    local directory="$1" name="$2" entrypoint="$3"
    [[ ! -L "$directory" && -f "$directory/$entrypoint" ]] || return 1
    if [[ "$name" == bats-core ]]; then
        [[ -x "$directory/bin/bats" && -x "$directory/libexec/bats-core/bats" && -d "$directory/lib/bats-core" ]]
    else
        [[ -d "$directory/src" ]]
    fi
}

install_dependency() {
    local name="$1" version="$2" checksum="$3" entrypoint="$4"
    local target="$TEST_DEPS_DIR/$name-$version" archive actual
    if [[ ! -e "$target" && ! -L "$target" ]]; then
        if [[ -z "$staging" ]]; then
            if ! mkdir "$TEST_DEPS_DIR/.lock" 2>/dev/null; then
                printf 'Test dependency cache is locked: %s/.lock. Check its pid before removing a stale lock.\n' "$TEST_DEPS_DIR" >&2
                return 1
            fi
            lock_owned=true
            printf '%s\n' "$$" > "$TEST_DEPS_DIR/.lock/pid"
            staging="$(mktemp -d "$TEST_DEPS_DIR/.download.XXXXXXXX")"
        fi
        archive="$staging/$name.tar.gz"
        printf 'Downloading %s %s...\n' "$name" "$version" >&2
        curl --fail --location --silent --show-error --retry 3 --connect-timeout 20 \
            --max-time 180 --proto '=https' --proto-redir '=https' --tlsv1.2 \
            --output "$archive" "https://codeload.github.com/bats-core/$name/tar.gz/refs/tags/v$version"
        actual="$(shasum -a 256 "$archive")"
        [[ "${actual%% *}" == "$checksum" ]] ||
            { printf 'SHA256 mismatch for %s %s; nothing was installed.\n' "$name" "$version" >&2; return 1; }
        tar -tzf "$archive" | ruby "$REPO_ROOT/scripts/support.rb" archive-paths
        mkdir "$staging/$name"
        tar -xzf "$archive" --strip-components=1 -C "$staging/$name"
        ruby "$REPO_ROOT/scripts/support.rb" check-links "$staging/$name"
        dependency_complete "$staging/$name" "$name" "$entrypoint" ||
            { printf 'Incomplete release archive: %s %s\n' "$name" "$version" >&2; return 1; }
        printf '%s\n' "$checksum" > "$staging/$name/.archive-sha256"
        mv "$staging/$name" "$target"
    fi
    actual=""
    if [[ -f "$target/.archive-sha256" ]]; then actual="$(cat "$target/.archive-sha256")"; fi
    if [[ "$actual" != "$checksum" ]] || ! dependency_complete "$target" "$name" "$entrypoint"; then
        printf 'Incomplete test dependency cache; inspect and remove only %s before retrying.\n' "$target" >&2
        return 1
    fi
    case "$name" in
        bats-core) export BATS_CORE_DIR="$target" ;;
        bats-support) export BATS_SUPPORT_DIR="$target" ;;
        bats-assert) export BATS_ASSERT_DIR="$target" ;;
    esac
}

install_dependency bats-core 1.14.0 bb537b70b15b732f6d8827dd6578e3d8ce166636ce1f18ea9a074184fcce9177 bin/bats
install_dependency bats-support 0.3.0 7815237aafeb42ddcc1b8c698fc5808026d33317d8701d5ec2396e9634e2918f load.bash
install_dependency bats-assert 2.2.4 e305df20c4c36cba4570e10f1cd824efb1ae71d88b5ef474550781ebee04192f load.bash

cleanup
trap - EXIT INT TERM
if [[ "$run_tests" == true ]]; then
    exec "$BATS_CORE_DIR/bin/bats" "$@"
fi
printf 'Test dependencies ready: %s\n' "$TEST_DEPS_DIR"
