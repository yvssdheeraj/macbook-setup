#!/usr/bin/env bash
# scripts/validate.sh

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

log_info "Running validation checks..."

declare -a missing=()

check_cmd() {
    if ! command -v "$1" &> /dev/null && [[ ! -f "$HOME/.local/bin/$1" ]] && [[ ! -f "$HOME/.cargo/bin/$1" ]]; then
        missing+=("$1")
    else
        log_success "$1 is installed and accessible."
    fi
}

check_app() {
    if [[ ! -d "$HOME/Applications/$1" ]]; then
        missing+=("$1.app")
    else
        log_success "$1 is installed."
    fi
}

check_cmd "node" # NVM will not be accessible in standard subshell usually, but let's check basic
check_cmd "uv"
check_cmd "docker"
check_cmd "colima"
check_cmd "code"
check_cmd "gh"
check_cmd "aws"
check_cmd "btop"

check_app "Google Chrome.app"
check_app "Visual Studio Code.app"
check_app "Maccy.app"

if [[ ${#missing[@]} -gt 0 ]]; then
    log_warn "The following tools/apps might be missing or not in PATH: ${missing[*]}"
    log_warn "This might be expected if you skipped their installation or if they require a new shell session to load."
else
    log_success "All core validations passed!"
fi
