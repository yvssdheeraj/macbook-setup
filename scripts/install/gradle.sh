#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../runtimes.sh"
install_sdk_candidate gradle "$GRADLE_VERSION"
