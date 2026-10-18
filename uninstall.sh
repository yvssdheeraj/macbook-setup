#!/usr/bin/env bash
# uninstall.sh

set -e

cd "$(dirname "${BASH_SOURCE[0]}")"
export REPO_ROOT="$(pwd)"

source "scripts/common.sh"

cat << EOF
WARNING: This script will attempt to remove all user-level applications and tools
installed by this repository (e.g., from ~/Applications, ~/.local/bin, ~/.nvm, etc.).
Pre-existing user data and configurations (like .zshrc) will not be securely deleted,
but directories created strictly by this script will be removed.

Are you sure you want to proceed? [y/N]
EOF

read -r response
if [[ ! "$response" =~ ^[Yy]$ ]]; then
    log_info "Uninstall aborted."
    exit 0
fi

log_info "Starting uninstall process..."

remove_dir() {
    if [[ -d "$1" ]]; then
        log_info "Removing directory: $1"
        rm -rf "$1"
    fi
}

remove_file() {
    if [[ -f "$1" || -L "$1" ]]; then
        log_info "Removing file: $1"
        rm -f "$1"
    fi
}

# Remove Applications
remove_dir "$HOME/Applications/Maccy.app"
remove_dir "$HOME/Applications/Visual Studio Code.app"
remove_dir "$HOME/Applications/IntelliJ IDEA CE.app"
remove_dir "$HOME/Applications/IntelliJ IDEA.app"
remove_dir "$HOME/Applications/Google Chrome.app"
remove_dir "$HOME/Applications/DuckDuckGo.app"
remove_dir "$HOME/Applications/Ghostty.app"
remove_dir "$HOME/Applications/DBeaver.app"

# Remove Tool Directories
remove_dir "$HOME/.nvm"
remove_dir "$HOME/.sdkman"
remove_dir "$HOME/.oh-my-zsh"
remove_dir "$HOME/.local/aws-cli"

# Remove Local Binaries
remove_file "$HOME/.local/bin/docker"
remove_file "$HOME/.local/bin/colima"
remove_file "$HOME/.local/bin/limactl"
remove_file "$HOME/.local/bin/code"
remove_file "$HOME/.local/bin/gh"
remove_file "$HOME/.local/bin/aws"
remove_file "$HOME/.local/bin/aws_completer"
remove_file "$HOME/.local/bin/btop"
remove_file "$HOME/.local/bin/dockutil"

# Cargo / UV
# Note: we only remove the uv binary if it exists to be safe
remove_file "$HOME/.cargo/bin/uv"

log_success "Uninstallation complete. Note: dotfiles and global system states (like Dock / Wallpapers) were left as is to avoid destructive changes."
