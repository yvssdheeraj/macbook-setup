#!/usr/bin/env bash
# scripts/utils/backup.sh

source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"

backup_file() {
    local file="$1"
    if [[ -f "$file" || -L "$file" ]]; then
        local timestamp
        timestamp=$(date +%Y%m%d_%H%M%S)
        local backup_path="${file}.backup_${timestamp}"

        if [[ "${DRY_RUN:-false}" == "true" ]]; then
            log_info "[DRY-RUN] Would backup $file to $backup_path"
        else
            cp -a "$file" "$backup_path"
            log_success "Backed up $file to $backup_path"
        fi
    fi
}
