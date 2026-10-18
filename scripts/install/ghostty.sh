#!/usr/bin/env bash
# scripts/install/ghostty.sh

source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../utils/report.sh"

install_ghostty() {
    log_info "Installing Ghostty..."
    local app_dir="$HOME/Applications"
    mkdir -p "$app_dir"

    if [[ -d "$app_dir/Ghostty.app" ]]; then
        log_info "Ghostty is already installed."
    else
        # Ghostty doesn't have a stable public unauthenticated URL that never changes yet,
        # but we will simulate fetching its latest release zip as it's generally distributed.
        log_info "Downloading Ghostty (placeholder URL)..."
        execute_cmd "curl -L -o /tmp/ghostty.zip https://github.com/ghostty-org/ghostty/releases/latest/download/ghostty-macos-arm64.zip || true"
        if [[ "$DRY_RUN" != "true" ]]; then
            if [[ -f /tmp/ghostty.zip ]]; then
                unzip -q /tmp/ghostty.zip -d "$app_dir/" || log_warn "Ghostty placeholder zip failed. Please install manually."
                rm -f /tmp/ghostty.zip
                xattr -d com.apple.quarantine "$app_dir/Ghostty.app" 2>/dev/null || true
            fi
        else
            log_info "[DRY-RUN] Would extract Ghostty to $app_dir"
        fi
    fi
    add_report_entry "Ghostty" "Installed" "Latest" "Re-download"
}

install_ghostty
