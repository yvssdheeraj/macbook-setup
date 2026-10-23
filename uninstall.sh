#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source scripts/common.sh
source scripts/preflight.sh

confirmed=false
CONFIG_FILE="$REPO_ROOT/config/user.env"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true; shift ;;
        --yes) confirmed=true; shift ;;
        --config)
            [[ $# -ge 2 && "$2" != --* ]] || fatal "--config requires a file."
            CONFIG_FILE="$2"; shift 2 ;;
        --help|-h)
            printf '%s\n' 'Usage: ./uninstall.sh [--dry-run] [--yes] [--config FILE]' \
                'Only recorded resources are removed. Modified files, Homebrew itself, and VM data are retained.'
            exit 0 ;;
        *) fatal "Unknown option: $1" ;;
    esac
done
export DRY_RUN MODE=uninstall
load_configuration "$CONFIG_FILE"
preflight_checks
if [[ ! -f "$STATE_DIR/ownership.json" ]]; then
    log_info "No ownership record; nothing will be removed."
    exit 0
fi
if [[ "$DRY_RUN" == true ]]; then
    support uninstall --dry-run
    exit
fi
if [[ "$confirmed" != true ]]; then
    [[ -t 0 ]] || fatal "Use --yes for non-interactive removal, or --dry-run to preview."
    printf 'Remove only recorded, unchanged resources and restore backed-up settings? [y/N] '
    read -r answer
    [[ "$answer" == y || "$answer" == Y ]] || exit 0
fi
initialize_run
export COLIMA_HOME="$DATA_DIR/colima"
support uninstall
log_info "Recorded removal completed. Backups, reports, the Homebrew bootstrap, and Colima VM data were retained."
