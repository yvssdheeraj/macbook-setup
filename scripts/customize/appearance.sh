#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"
result="$(support preference NSGlobalDomain AppleInterfaceStyle string Dark)"
[[ "$result" != changed ]] || mark_changed
log_info "Dark mode selected; macOS may require a new login session to refresh all applications."
