#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../packages.sh"
install_app visual-studio-code 'Visual Studio Code.app'
app="$(find_app 'Visual Studio Code.app')"
managed_link "$LOCAL_BIN/code" "$app/Contents/Resources/app/bin/code"
"$LOCAL_BIN/code" --version
