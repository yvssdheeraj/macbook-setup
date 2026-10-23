#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../packages.sh"
install_formula btop btop
check_command btop --version
