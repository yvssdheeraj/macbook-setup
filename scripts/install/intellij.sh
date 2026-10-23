#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../packages.sh"
log_info "Current IntelliJ uses a unified distribution; paid features require a separate license."
if find_app 'IntelliJ IDEA CE.app' >/dev/null && ! find_app 'IntelliJ IDEA.app' >/dev/null; then
    existing="$(find_app 'IntelliJ IDEA CE.app')"
    verify_app "$existing"
    record_command_version IntelliJ existing app_version "$existing"
    exit 0
fi
install_app intellij-idea 'IntelliJ IDEA.app'
