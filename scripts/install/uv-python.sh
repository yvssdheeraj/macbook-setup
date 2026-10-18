#!/usr/bin/env bash
# scripts/install/uv-python.sh

source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../utils/report.sh"

install_uv() {
    log_info "Installing Python (uv)..."

    if command -v uv &> /dev/null || [[ -f "$HOME/.cargo/bin/uv" ]]; then
        log_info "uv is already installed."
    else
        execute_cmd "curl -LsSf https://astral.sh/uv/install.sh | sh"
    fi

    # Ensure it's in PATH for this script session
    export PATH="$HOME/.cargo/bin:$PATH"

    if command -v uv &> /dev/null || [[ "$DRY_RUN" == "true" ]]; then
        local target_version="${PYTHON_VERSION:-3.12}"
        log_info "Installing Python $target_version via uv..."
        execute_cmd "uv python install \"$target_version\""

        if [[ "$DRY_RUN" != "true" ]]; then
            local current_ver=$(uv python list 2>/dev/null | grep "$target_version" | head -n 1 | awk '{print $2}' || echo "Unknown")
            add_report_entry "Python (uv)" "$current_ver" "$target_version" "uv self update && uv python install <version>"
        fi
    fi
}

install_uv
