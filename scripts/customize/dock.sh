#!/usr/bin/env bash
# scripts/customize/dock.sh

source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"

install_dockutil() {
    local bin_dir="$HOME/.local/bin"
    mkdir -p "$bin_dir"

    if command -v dockutil &> /dev/null || [[ -f "$bin_dir/dockutil" ]]; then
        return 0
    fi

    log_info "Downloading dockutil for Dock customization..."
    # The latest dockutil pkg provides a universal binary
    execute_cmd "curl -L -o /tmp/dockutil.pkg https://github.com/kcrawford/dockutil/releases/latest/download/dockutil-3.1.3.pkg"
    execute_cmd "mkdir -p /tmp/dock_extract"
    if [[ "$DRY_RUN" != "true" ]]; then
        pkgutil --expand-full /tmp/dockutil.pkg /tmp/dock_extract
        cp -a /tmp/dock_extract/dockutil.pkg/Payload/usr/local/bin/dockutil "$bin_dir/"
        chmod +x "$bin_dir/dockutil"
        rm -rf /tmp/dockutil.pkg /tmp/dock_extract
    fi
}

customize_dock() {
    log_info "Configuring Dock..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would install dockutil and configure Dock layout."
        return
    fi

    install_dockutil

    local dockutil="$HOME/.local/bin/dockutil"

    if [[ ! -x "$dockutil" ]]; then
        log_warn "dockutil not found, cannot configure Dock."
        return
    fi

    # Clear everything
    "$dockutil" --remove all --no-restart

    # Finder and Trash are handled inherently by macOS Dock.
    # dockutil doesn't need to explicitly add Finder or Trash as they can't be fully removed.
    # We just need to add Google Chrome.

    local chrome_app="$HOME/Applications/Google Chrome.app"
    if [[ -d "$chrome_app" ]]; then
        "$dockutil" --add "$chrome_app" --no-restart
    else
        # Fallback to system chrome if user already had it there and we skipped install
        if [[ -d "/Applications/Google Chrome.app" ]]; then
            "$dockutil" --add "/Applications/Google Chrome.app" --no-restart
        fi
    fi

    killall Dock
    log_success "Dock configured."
}

customize_dock
