#!/usr/bin/env bash
# scripts/install/nvm-node.sh

source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../utils/report.sh"

install_nvm() {
    log_info "Installing NVM and Node.js..."

    export NVM_DIR="$HOME/.nvm"

    if [[ -d "$NVM_DIR" ]]; then
        log_info "NVM is already installed."
    else
        execute_cmd "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash"
    fi

    # Load NVM for this session if it exists (might not in dry-run)
    if [[ -s "$NVM_DIR/nvm.sh" ]]; then
        source "$NVM_DIR/nvm.sh"

        local target_version="${NODE_VERSION:-lts/*}"
        log_info "Installing Node.js version $target_version..."
        execute_cmd "nvm install \"$target_version\""
        execute_cmd "nvm alias default \"$target_version\""

        if [[ "$DRY_RUN" != "true" ]]; then
            local current_ver
    current_ver=$(node -v 2>/dev/null || echo "Unknown")
            add_report_entry "Node.js (NVM)" "$current_ver" "$target_version" "nvm install <version>"
        fi
    elif [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would source NVM and install Node.js ${NODE_VERSION:-lts/*}"
        add_report_entry "Node.js (NVM)" "N/A" "${NODE_VERSION:-lts/*}" "nvm install <version>"
    fi
}

install_nvm
