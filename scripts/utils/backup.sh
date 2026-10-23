#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"

backup_file() {
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would snapshot $1"
    else
        snapshot_path "$1"
    fi
}
