#!/usr/bin/env bash
# scripts/preflight.sh

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

preflight_checks() {
    log_info "Running preflight checks..."

    # Check OS
    if [[ "$(uname -s)" != "Darwin" ]]; then
        # For CI/CD purposes, we might allow bypassing this via an env var
        if [[ -z "$CI_BYPASS_OS_CHECK" ]]; then
             fatal "This setup is intended for macOS only."
        else
             log_warn "Bypassing OS check due to CI_BYPASS_OS_CHECK."
        fi
    fi

    # Check Architecture
    if [[ "$(uname -m)" != "arm64" ]]; then
        if [[ -z "$CI_BYPASS_OS_CHECK" ]]; then
            fatal "This setup is intended for Apple Silicon (ARM64) only."
        else
            log_warn "Bypassing Architecture check due to CI_BYPASS_OS_CHECK."
        fi
    fi

    # Check for Sudo / Root
    if [[ "$EUID" -eq 0 ]]; then
        fatal "Please do not run this script as root or with sudo."
    fi

    # Check for User Home Directory writable
    if [[ ! -w "$HOME" ]]; then
        fatal "User home directory ($HOME) is not writable."
    fi

    log_success "Preflight checks passed."
}
