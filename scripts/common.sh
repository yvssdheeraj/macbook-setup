#!/usr/bin/env bash
# scripts/common.sh

# This file sources common utilities so they are available to all scripts.
# It also defines global variables.

# Get absolute path to the directory where this script resides,
# then get the parent directory (the repo root).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Source utils
source "$SCRIPT_DIR/utils/logging.sh"
source "$SCRIPT_DIR/utils/backup.sh"

# Global state / Options
export DRY_RUN="${DRY_RUN:-false}"

# Helper for executing commands considering DRY_RUN
execute_cmd() {
    local cmd="$*"
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would execute: $cmd"
    else
        log_info "Executing: $cmd"
        eval "$cmd"
    fi
}
