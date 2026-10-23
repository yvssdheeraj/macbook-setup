#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../packages.sh"
case "${CURRENT_COMPONENT:-}" in
    chrome) install_app google-chrome 'Google Chrome.app' ;;
    duckduckgo) install_app duckduckgo DuckDuckGo.app ;;
    *) fatal "Run this module through setup.sh --only browsers." ;;
esac
