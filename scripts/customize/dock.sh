#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"
chrome="$(find_app 'Google Chrome.app')" || blocked "Install Chrome before adding it to the Dock."
result="$(support dock-add "$chrome")"
if [[ "$result" == changed ]]; then
    mark_changed
    pids="$(pgrep -x -u "$(id -u)" Dock)" || pids=""
    for pid in $pids; do kill -TERM "$pid"; done
fi
log_info "Chrome is present in the Dock; existing entries were preserved."
