#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../packages.sh"
ensure_homebrew || blocked "Cannot provision user-local Homebrew."
record_command_version Homebrew stable "$BREW_PREFIX/bin/brew" --version
