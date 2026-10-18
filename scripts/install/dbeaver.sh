#!/usr/bin/env bash
# scripts/install/dbeaver.sh

source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../utils/report.sh"

install_dbeaver() {
    log_info "Installing DBeaver Community Edition..."
    local app_dir="$HOME/Applications"
    mkdir -p "$app_dir"

    if [[ -d "$app_dir/DBeaver.app" ]]; then
        log_info "DBeaver is already installed."
    else
        execute_cmd "curl -L -o /tmp/dbeaver.dmg https://dbeaver.io/files/dbeaver-ce-latest-macos-aarch64.dmg"
        if [[ "$DRY_RUN" != "true" ]]; then
            local mount_point=$(hdiutil info | grep /Volumes/DBeaver | awk -F'\t' '{print $3}')
            if [[ -z "$mount_point" ]]; then
                hdiutil attach -nobrowse -readonly /tmp/dbeaver.dmg
                mount_point=$(hdiutil info | grep /Volumes/DBeaver | awk -F'\t' '{print $3}')
            fi

            if [[ -n "$mount_point" && -d "$mount_point/DBeaver.app" ]]; then
                cp -a "$mount_point/DBeaver.app" "$app_dir/"
                hdiutil detach "$mount_point" -force
                log_success "Copied DBeaver to $app_dir"
            else
                log_error "Failed to mount DBeaver DMG."
            fi
            rm /tmp/dbeaver.dmg
        else
            log_info "[DRY-RUN] Would copy DBeaver.app to $app_dir"
        fi
    fi
    add_report_entry "DBeaver CE" "Installed" "Latest" "In-app updater"
}

install_dbeaver
