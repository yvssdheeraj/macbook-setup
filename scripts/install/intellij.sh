#!/usr/bin/env bash
# scripts/install/intellij.sh

source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../utils/report.sh"

install_intellij() {
    log_info "Installing IntelliJ IDEA (${INTELLIJ_EDITION:-idea-community})..."

    local app_dir="$HOME/Applications"
    mkdir -p "$app_dir"

    local edition="${INTELLIJ_EDITION:-idea-community}"
    local app_name="IntelliJ IDEA CE.app"
    local download_url=""

    if [[ "$edition" == "idea-ultimate" ]]; then
        app_name="IntelliJ IDEA.app"
        # Download link for Ultimate ARM64
        download_url="https://download.jetbrains.com/idea/ideaIU-2023.3.3-aarch64.dmg"
    else
        # Download link for Community ARM64
        download_url="https://download.jetbrains.com/idea/ideaIC-2023.3.3-aarch64.dmg"
    fi

    if [[ -d "$app_dir/$app_name" ]]; then
        log_info "IntelliJ IDEA is already installed in $app_dir."
    else
        log_info "Downloading $edition..."
        execute_cmd "curl -L -o /tmp/intellij.dmg \"$download_url\""

        if [[ "$DRY_RUN" != "true" ]]; then
            # Attach DMG silently
            local mount_point
    mount_point=$(hdiutil attach -nobrowse -readonly /tmp/intellij.dmg | grep /Volumes | awk '{print $3}' | head -n 1)
            if [[ -n "$mount_point" && -d "$mount_point/$app_name" ]]; then
                cp -a "$mount_point/$app_name" "$app_dir/"
                hdiutil detach "$mount_point" -force
                log_success "Copied $app_name to $app_dir"
            else
                log_error "Failed to mount and extract IntelliJ DMG."
            fi
            rm /tmp/intellij.dmg
            xattr -d com.apple.quarantine "$app_dir/$app_name" 2>/dev/null || true
        else
            log_info "[DRY-RUN] Would mount DMG and copy $app_name to $app_dir"
        fi
    fi

    if [[ "$DRY_RUN" != "true" ]]; then
        local version
    version=$(defaults read "$app_dir/$app_name/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "Unknown")
        add_report_entry "IntelliJ IDEA" "$version" "2023.3.3" "In-app updater"
    else
        add_report_entry "IntelliJ IDEA" "N/A" "2023.3.3" "In-app updater"
    fi
}

install_intellij
