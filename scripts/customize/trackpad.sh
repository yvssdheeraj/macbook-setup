#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"
for domain in com.apple.driver.AppleBluetoothMultitouch.trackpad com.apple.AppleMultitouchTrackpad; do
    for key in Clicking TrackpadRightClick; do
        result="$(support preference "$domain" "$key" bool true)"
        [[ "$result" != changed ]] || mark_changed
    done
    result="$(support preference "$domain" TrackpadCornerSecondaryClick int 0)"
    [[ "$result" != changed ]] || mark_changed
done
result="$(support preference NSGlobalDomain com.apple.trackpad.scaling float 2.4)"
[[ "$result" != changed ]] || mark_changed
log_info "Preference values verified. Physical trackpad behavior requires a hardware check."
