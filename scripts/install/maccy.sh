#!/usr/bin/env bash
# scripts/install/maccy.sh

source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../utils/report.sh"

install_maccy() {
    log_info "Installing Maccy clipboard manager..."

    local app_dir="$HOME/Applications"
    mkdir -p "$app_dir"

    if [[ -d "$app_dir/Maccy.app" ]]; then
        log_info "Maccy is already installed in $app_dir."
    else
        log_info "Downloading Maccy..."
        execute_cmd "curl -L -o /tmp/Maccy.app.zip https://github.com/p0deje/Maccy/releases/latest/download/Maccy.app.zip"
        execute_cmd "unzip -q /tmp/Maccy.app.zip -d $app_dir/"
        execute_cmd "rm /tmp/Maccy.app.zip"

        # Remove quarantine attribute to avoid "app is damaged" prompt
        execute_cmd "xattr -d com.apple.quarantine \"$app_dir/Maccy.app\" 2>/dev/null || true"
    fi

    if [[ "$DRY_RUN" != "true" ]]; then
        local version
    version=$(defaults read "$app_dir/Maccy.app/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "Unknown")
        add_report_entry "Maccy" "$version" "Latest" "In-app updater"
    else
        add_report_entry "Maccy" "N/A" "Latest" "In-app updater"
    fi
}

install_maccy
