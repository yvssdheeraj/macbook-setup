#!/usr/bin/env bash

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export REPO_ROOT
source "$REPO_ROOT/scripts/utils/logging.sh"
if [[ -z "${ORIGINAL_ENV_NAMES+x}" ]]; then
    ORIGINAL_ENV_NAMES=" $(env | cut -d= -f1 | tr '\n' ' ') "
fi

export DRY_RUN="${DRY_RUN:-false}"
export MODE="${MODE:-install}"
export STATE_DIR="${STATE_DIR:-$HOME/Library/Application Support/macbook-setup}"
export CACHE_DIR="${CACHE_DIR:-$HOME/Library/Caches/macbook-setup}"
export DATA_DIR="${DATA_DIR:-$HOME/.local/share/macbook-setup}"
export BREW_PREFIX="${BREW_PREFIX:-$HOME/.homebrew}"
export LOCAL_BIN="${LOCAL_BIN:-$HOME/.local/bin}"
export APP_DIR="${APP_DIR:-$HOME/Applications}"
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
export SDKMAN_DIR="${SDKMAN_DIR:-$HOME/.sdkman}"
export ZSH="${ZSH:-$HOME/.oh-my-zsh}"
export PATH="$LOCAL_BIN:$BREW_PREFIX/bin:$BREW_PREFIX/sbin:$HOME/.cargo/bin:$PATH"
export HOMEBREW_NO_SUDO=1 HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_UPGRADE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1 HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_NO_AUTOREMOVE=1
export HOMEBREW_CACHE="$HOME/Library/Caches/Homebrew"
export HOMEBREW_LOGS="$STATE_DIR/logs/homebrew"
unset HOMEBREW_CASK_OPTS
export CI=1 NONINTERACTIVE=1

support() {
    ruby "$REPO_ROOT/scripts/support.rb" "$@"
}

blocked() {
    log_error "BLOCKED: $*"
    exit 78
}

execute_cmd() {
    if [[ "$DRY_RUN" == true ]]; then
        printf '[DRY-RUN]'
        printf ' %q' "$@"
        printf '\n'
    else
        "$@"
    fi
}

assert_user_path() {
    support path "$1" >/dev/null
}

require_apply_context() {
    [[ "$DRY_RUN" != true && "$MODE" != validate && -n "${RUN_DIR:-}" && -d "$RUN_DIR" && -f "$STATE_DIR/lock/pid" ]] ||
        fatal "Mutating modules must be run through setup.sh, not directly."
}

mark_changed() {
    [[ -n "${RUN_DIR:-}" ]] || fatal "No active setup run."
    : > "$RUN_DIR/changed.${CURRENT_COMPONENT:-setup}"
}

record_version() {
    support version "${CURRENT_COMPONENT:-setup}" "$1" "$2" "$3"
}

record_command_version() {
    local name="$1" requested="$2" output
    shift 2
    output="$("$@" 2>&1)" || { log_error "Version probe failed for $name: $output"; return 1; }
    [[ -n "$output" ]] || { log_error "Version probe returned no output for $name."; return 1; }
    record_version "$name" "$output" "$requested"
}

managed_file() {
    local result
    require_apply_context
    result="$(support write "$1" "${CURRENT_COMPONENT:-setup}")" || return
    [[ "$result" != changed ]] || mark_changed
}

managed_block() {
    local result
    require_apply_context
    result="$(support block "$1" "${CURRENT_COMPONENT:-setup}")" || return
    [[ "$result" != changed ]] || mark_changed
}

managed_link() {
    local result
    require_apply_context
    result="$(support link "$1" "$2" "${CURRENT_COMPONENT:-setup}")" || return
    [[ "$result" != changed ]] || mark_changed
}

managed_executable() {
    local result
    require_apply_context
    result="$(support executable "$1" "$2" "${CURRENT_COMPONENT:-setup}")" || return
    [[ "$result" != changed ]] || mark_changed
}

snapshot_path() {
    support snapshot "$1" "${CURRENT_COMPONENT:-setup}"
}

seal_path() {
    support seal "$1" || return
    mark_changed
}

owned_path() {
    support owned "$1"
}

work_dir() {
    [[ -n "${RUN_DIR:-}" && -d "$RUN_DIR" ]] || fatal "No active setup run."
    mktemp -d "$RUN_DIR/work.XXXXXXXX"
}

check_command() {
    local executable
    executable="$(command -v "$1")" || blocked "$1 is missing or not on PATH."
    "$executable" "${@:2}"
}

find_app() {
    local directory name
    for directory in "$APP_DIR" /Applications; do
        for name in "$@"; do
            if [[ -d "$directory/$name" ]]; then
                printf '%s\n' "$directory/$name"
                return 0
            fi
        done
    done
    return 1
}

app_version() {
    /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$1/Contents/Info.plist"
}

load_configuration() {
    local config_file="$1" values key value
    if [[ -f "$config_file" ]]; then
        values="$(support config "$config_file")" || return
        while IFS=$'\t' read -r key value; do
            [[ -n "$key" ]] || continue
            case "$ORIGINAL_ENV_NAMES" in
                *" $key "*) ;;
                *) printf -v "$key" '%s' "$value"; export "${key?}" ;;
            esac
        done <<< "$values"
    elif [[ "$config_file" != "$REPO_ROOT/config/user.env" ]]; then
        fatal "Configuration file does not exist: $config_file"
    fi
    export NODE_VERSION="${NODE_VERSION:-lts/*}" PYTHON_VERSION="${PYTHON_VERSION:-stable}"
    export JAVA_VERSION="${JAVA_VERSION:-lts}" JAVA_LTS="${JAVA_LTS:-latest}"
    export GRADLE_VERSION="${GRADLE_VERSION:-stable}"
    export INTELLIJ_EDITION="${INTELLIJ_EDITION:-idea-community}"
    export COLIMA_CPU="${COLIMA_CPU:-2}" COLIMA_MEMORY="${COLIMA_MEMORY:-4}"
    export COLIMA_DISK="${COLIMA_DISK:-50}" COLIMA_START_AT_LOGIN="${COLIMA_START_AT_LOGIN:-false}"
    export GIT_USER_NAME="${GIT_USER_NAME:-}" GIT_USER_EMAIL="${GIT_USER_EMAIL:-}"
    export GIT_DEFAULT_BRANCH="${GIT_DEFAULT_BRANCH:-main}" GIT_EDITOR="${GIT_EDITOR:-nano}"
    export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-}" AWS_PROFILE="${AWS_PROFILE:-default}"
    export PATH="$LOCAL_BIN:$BREW_PREFIX/bin:$BREW_PREFIX/sbin:$HOME/.cargo/bin:$PATH"
    export HOMEBREW_LOGS="$STATE_DIR/logs/homebrew"
    support validate-config
}

initialize_run() {
    local directory
    for directory in "$STATE_DIR" "$CACHE_DIR" "$DATA_DIR" "$LOCAL_BIN" "$APP_DIR" "$BREW_PREFIX" "$NVM_DIR" "$SDKMAN_DIR" "$ZSH"; do
        assert_user_path "$directory"
    done
    mkdir -p "$STATE_DIR" "$CACHE_DIR"
    chmod 700 "$STATE_DIR" "$CACHE_DIR"
    if ! mkdir "$STATE_DIR/lock" 2>/dev/null; then
        fatal "Another run or an interrupted run holds $STATE_DIR/lock. Check its pid before removing that specific lock directory."
    fi
    printf '%s\n' "$$" > "$STATE_DIR/lock/pid"
    trap cleanup_run EXIT
    export RUN_DIR
    RUN_DIR="$(mktemp -d "$CACHE_DIR/run.XXXXXXXX")"
    export TMPDIR="$RUN_DIR/tmp" HOMEBREW_TEMP="$RUN_DIR/homebrew-tmp"
    mkdir "$TMPDIR" "$HOMEBREW_TEMP"
    export REPORT_FILE="$STATE_DIR/reports/$(date -u +%Y%m%dT%H%M%SZ)-$$.md"
    mkdir -p "$STATE_DIR/reports"
    trap 'exit 130' INT
    trap 'exit 143' TERM
}

cleanup_run() {
    local status=$?
    trap - EXIT
    if [[ -n "${RUN_DIR:-}" && -d "$RUN_DIR" ]]; then
        if ! support cleanup "$RUN_DIR"; then
            log_error "Temporary files retained at $RUN_DIR; cleanup needs attention."
            status=1
        fi
    fi
    if [[ -f "$STATE_DIR/lock/pid" && "$(cat "$STATE_DIR/lock/pid")" == "$$" ]]; then
        rm "$STATE_DIR/lock/pid"
        rmdir "$STATE_DIR/lock"
    fi
    exit "$status"
}
