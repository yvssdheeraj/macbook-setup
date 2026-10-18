#!/usr/bin/env bash
# scripts/install/oh-my-zsh.sh

source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../utils/report.sh"

install_omz() {
    log_info "Installing Oh My Zsh..."

    export ZSH="$HOME/.oh-my-zsh"

    if [[ -d "$ZSH" ]]; then
        log_info "Oh My Zsh is already installed."
    else
        execute_cmd "curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh | sh -s -- --unattended"
    fi

    add_report_entry "Oh My Zsh" "Installed" "Latest" "omz update"
}

install_omz
