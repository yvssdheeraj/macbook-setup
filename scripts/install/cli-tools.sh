#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../packages.sh"
case "${CURRENT_COMPONENT:-}" in
    gh) install_formula gh gh; check_command gh --version ;;
    aws)
        install_formula awscli aws
        version="$(aws --version 2>&1)"
        [[ "$version" == aws-cli/2.* ]] || blocked "AWS CLI v2 is required; preserving the existing v1 installation."
        record_version 'AWS CLI' "$version" 'stable v2'
        ;;
    *) fatal "Run this module through setup.sh --only gh,aws." ;;
esac
