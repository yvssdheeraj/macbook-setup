#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"

git --version
name="$GIT_USER_NAME"
email="$GIT_USER_EMAIL"
[[ "$name" != 'Your Name' && "$email" != your.email@example.com ]] || blocked "Replace the example Git identity in config/user.env."
if [[ -z "$name" ]]; then name="$(git config --global --includes user.name)" || name=""; fi
if [[ -z "$email" ]]; then email="$(git config --global --includes user.email)" || email=""; fi
[[ -n "$name" && -n "$email" ]] || blocked "Set GIT_USER_NAME and GIT_USER_EMAIL, or configure an existing Git identity."
directory="$(work_dir)"
git config --file "$directory/gitconfig" user.name "$name"
git config --file "$directory/gitconfig" user.email "$email"
git config --file "$directory/gitconfig" init.defaultBranch "$GIT_DEFAULT_BRANCH"
git config --file "$directory/gitconfig" core.editor "$GIT_EDITOR"
cat "$directory/gitconfig" | managed_file "$DATA_DIR/gitconfig"
git config --file "$directory/include" include.path "$DATA_DIR/gitconfig"
cat "$directory/include" | managed_block "$HOME/.gitconfig"
[[ "$(git config --global --includes user.name)" == "$name" && "$(git config --global --includes user.email)" == "$email" ]] ||
    blocked "Git identity verification failed."
record_command_version Git existing git --version
