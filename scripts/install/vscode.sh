#!/usr/bin/env bash
# scripts/install/vscode.sh

source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../utils/report.sh"

install_vscode() {
    log_info "Installing Visual Studio Code..."

    local app_dir="$HOME/Applications"
    mkdir -p "$app_dir"

    if [[ -d "$app_dir/Visual Studio Code.app" ]]; then
        log_info "VS Code is already installed in $app_dir."
    else
        log_info "Downloading VS Code for Apple Silicon..."
        execute_cmd "curl -L -o /tmp/vscode.zip \"https://code.visualstudio.com/sha/download?build=stable&os=darwin-arm64\""
        execute_cmd "unzip -q /tmp/vscode.zip -d $app_dir/"
        execute_cmd "rm /tmp/vscode.zip"

        execute_cmd "xattr -d com.apple.quarantine \"$app_dir/Visual Studio Code.app\" 2>/dev/null || true"
    fi

    # Set up CLI command
    local bin_dir="$HOME/.local/bin"
    mkdir -p "$bin_dir"
    execute_cmd "ln -sf \"$app_dir/Visual Studio Code.app/Contents/Resources/app/bin/code\" \"$bin_dir/code\""

    if [[ "$DRY_RUN" != "true" ]]; then
        local version
    version=$(defaults read "$app_dir/Visual Studio Code.app/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "Unknown")
        add_report_entry "VS Code" "$version" "Latest" "In-app updater"
    else
        add_report_entry "VS Code" "N/A" "Latest" "In-app updater"
    fi
}

install_vscode
