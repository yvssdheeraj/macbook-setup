#!/usr/bin/env bash
# scripts/install/btop.sh

source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../utils/report.sh"

install_btop() {
    log_info "Installing btop..."
    local bin_dir="$HOME/.local/bin"
    mkdir -p "$bin_dir"

    if command -v btop &> /dev/null || [[ -f "$bin_dir/btop" ]]; then
        log_info "btop is already installed."
    else
        execute_cmd "curl -L -o /tmp/btop.tbz https://github.com/aristocratos/btop/releases/latest/download/btop-aarch64-macos-11.tbz"
        execute_cmd "mkdir -p /tmp/btop && tar -xf /tmp/btop.tbz -C /tmp/btop"
        execute_cmd "cp /tmp/btop/btop/bin/btop $bin_dir/"
        execute_cmd "rm -rf /tmp/btop /tmp/btop.tbz"
    fi

    if [[ "$DRY_RUN" != "true" ]]; then
        add_report_entry "btop" "$($bin_dir/btop --version | awk '{print $3}')" "Latest" "Download release binary"
    else
        add_report_entry "btop" "N/A" "Latest" "Download release binary"
    fi
}

install_btop
