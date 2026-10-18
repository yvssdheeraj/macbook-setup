#!/usr/bin/env bash
# scripts/install/browsers.sh

source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../utils/report.sh"

install_chrome() {
    log_info "Installing Google Chrome..."
    local app_dir="$HOME/Applications"
    mkdir -p "$app_dir"

    if [[ -d "$app_dir/Google Chrome.app" ]]; then
        log_info "Google Chrome is already installed."
    else
        execute_cmd "curl -L -o /tmp/chrome.dmg https://dl.google.com/chrome/mac/universal/stable/GGRO/googlechrome.dmg"
        if [[ "$DRY_RUN" != "true" ]]; then
            local mount_point
    mount_point=$(hdiutil attach -nobrowse -readonly /tmp/chrome.dmg | grep /Volumes | awk '{print $3$4$5}' | head -n 1)
            # Sometimes volume name has spaces. Safer string manipulation:
            mount_point=$(hdiutil info | grep /Volumes/Google | awk -F'\t' '{print $3}')

            if [[ -n "$mount_point" && -d "$mount_point/Google Chrome.app" ]]; then
                cp -a "$mount_point/Google Chrome.app" "$app_dir/"
                hdiutil detach "$mount_point" -force
                log_success "Copied Google Chrome to $app_dir"
            else
                log_error "Failed to mount Chrome DMG."
            fi
            rm /tmp/chrome.dmg
        else
            log_info "[DRY-RUN] Would copy Google Chrome.app to $app_dir"
        fi
    fi
    add_report_entry "Google Chrome" "Installed" "Latest" "In-app auto-updater"
}

install_duckduckgo() {
    log_info "Installing DuckDuckGo Browser..."
    local app_dir="$HOME/Applications"

    if [[ -d "$app_dir/DuckDuckGo.app" ]]; then
        log_info "DuckDuckGo is already installed."
    else
        execute_cmd "curl -L -o /tmp/ddg.dmg https://staticcdn.duckduckgo.com/mac-desktop-browser/duckduckgo.dmg"
        if [[ "$DRY_RUN" != "true" ]]; then
            local mount_point
    mount_point=$(hdiutil info | grep /Volumes/DuckDuckGo | awk -F'\t' '{print $3}')
            if [[ -z "$mount_point" ]]; then
                hdiutil attach -nobrowse -readonly /tmp/ddg.dmg
                mount_point=$(hdiutil info | grep /Volumes/DuckDuckGo | awk -F'\t' '{print $3}')
            fi

            if [[ -n "$mount_point" && -d "$mount_point/DuckDuckGo.app" ]]; then
                cp -a "$mount_point/DuckDuckGo.app" "$app_dir/"
                hdiutil detach "$mount_point" -force
                log_success "Copied DuckDuckGo to $app_dir"
            else
                log_error "Failed to mount DuckDuckGo DMG."
            fi
            rm /tmp/ddg.dmg
        else
            log_info "[DRY-RUN] Would copy DuckDuckGo.app to $app_dir"
        fi
    fi
    add_report_entry "DuckDuckGo" "Installed" "Latest" "In-app auto-updater"
}

install_chrome
install_duckduckgo
