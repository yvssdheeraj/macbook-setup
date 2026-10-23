#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../packages.sh"
install_git_checkout ohmyzsh/ohmyzsh "$ZSH" master
[[ -s "$ZSH/oh-my-zsh.sh" ]] || blocked "Oh My Zsh installation is incomplete."
install_git_checkout zsh-users/zsh-autosuggestions "$DATA_DIR/zsh-plugins/zsh-autosuggestions" master
install_git_checkout zsh-users/zsh-syntax-highlighting "$DATA_DIR/zsh-plugins/zsh-syntax-highlighting" master
