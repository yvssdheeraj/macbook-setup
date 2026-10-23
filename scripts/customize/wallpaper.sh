#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"
target="$DATA_DIR/black-wallpaper.png"
cat "$REPO_ROOT/assets/black-wallpaper.png" | managed_file "$target"
log_info "Wallpaper uses System Events and may require an Automation approval."
result="$(support wallpaper "$target")" || blocked "Wallpaper needs an interactive desktop and macOS Automation permission."
[[ "$result" != changed ]] || mark_changed
