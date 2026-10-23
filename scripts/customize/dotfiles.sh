#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"

{
    printf 'export MACBOOK_LOCAL_BIN=%q\n' "$LOCAL_BIN"
    printf 'export MACBOOK_BREW_PREFIX=%q\n' "$BREW_PREFIX"
    printf 'export MACBOOK_DATA_DIR=%q\n' "$DATA_DIR"
    printf 'export MACBOOK_NVM_DIR=%q\n' "$NVM_DIR"
    printf 'export MACBOOK_SDKMAN_DIR=%q\n' "$SDKMAN_DIR"
    printf 'export MACBOOK_ZSH=%q\n' "$ZSH"
    if [[ -n "$AWS_DEFAULT_REGION" ]]; then
        printf 'export AWS_DEFAULT_REGION=%q\n' "$AWS_DEFAULT_REGION"
        printf 'export AWS_PROFILE=%q\n' "$AWS_PROFILE"
    fi
    cat "$REPO_ROOT/dotfiles/zshrc"
} | managed_file "$DATA_DIR/shell.zsh"
printf 'source %q\n' "$DATA_DIR/shell.zsh" | managed_block "$HOME/.zshrc"
cat "$REPO_ROOT/dotfiles/ghostty_config" |
    managed_block "$HOME/Library/Application Support/com.mitchellh.ghostty/config"
zsh -n "$DATA_DIR/shell.zsh"
log_info "Shell integration installed. Open a new shell to load it."
