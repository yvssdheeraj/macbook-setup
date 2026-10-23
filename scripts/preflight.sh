#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

preflight_checks() {
    local os architecture tool version
    os="$(uname -s)"
    architecture="$(uname -m)"
    if [[ "$os" != Darwin || "$architecture" != arm64 ]]; then
        if [[ "$DRY_RUN" == true && "${CI_BYPASS_OS_CHECK:-}" == 1 ]]; then
            log_warn "Read-only CI plan: bypassing macOS/ARM64 checks."
        else
            fatal "This setup requires macOS on Apple Silicon (ARM64). OS bypass is allowed only for a dry-run."
        fi
    fi
    [[ "$EUID" -ne 0 ]] || fatal "Do not run setup as root."
    [[ -d "$HOME" && -w "$HOME" && "$HOME" != / ]] || fatal "HOME must be an existing writable user home."
    for tool in ruby curl shasum tar unzip git; do
        command -v "$tool" >/dev/null || fatal "Missing prerequisite: $tool. Provision it separately without elevation."
    done
    if [[ "$os" == Darwin ]]; then
        version="$(sw_vers -productVersion)"
        [[ "${version%%.*}" -ge 13 ]] || fatal "macOS 13 or newer is required."
        if [[ "$DRY_RUN" != true ]]; then
            if [[ "$(command -v git)" == /usr/bin/git ]] && ! xcode-select -p >/dev/null 2>&1; then
                fatal "Apple Git is an installer stub until developer tools are provisioned. Setup will not request administrator access."
            fi
            git --version >/dev/null || fatal "Git is not usable."
        fi
    fi
    log_success "Preflight passed. Installation is restricted to the current user's home."
}
