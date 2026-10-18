#!/usr/bin/env bash
# scripts/customize/trackpad.sh

source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"

customize_trackpad() {
    log_info "Configuring Trackpad preferences..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would enable tap-to-click and configure pointer speed."
        return
    fi

    # Enable tap to click for this user and for the login screen
    defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
    defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true

    # Enable two-finger secondary click
    defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRightClick -bool true
    defaults write com.apple.AppleMultitouchTrackpad TrackpadRightClick -bool true
    defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadCornerSecondaryClick -int 0
    defaults write com.apple.AppleMultitouchTrackpad TrackpadCornerSecondaryClick -int 0

    # Pointer tracking speed (~80%)
    # Range is generally 0.0 to 3.0. 80% is ~2.4
    defaults write -g com.apple.trackpad.scaling -float 2.4

    log_success "Trackpad configured."
}

customize_trackpad
