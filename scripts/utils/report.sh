#!/usr/bin/env bash
# scripts/utils/report.sh

source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"

REPORT_FILE="$HOME/Desktop/Setup_Report.md"

init_report() {
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would initialize report at $REPORT_FILE"
        return
    fi

    mkdir -p "$HOME/Desktop"
    { echo "# macOS Setup Report";
    echo "Generated on: $(date)"
    echo ""
    echo "| Application | Installed Version | Latest Version | Update Command |"
    echo "| :--- | :--- | :--- | :--- |"; } > "$REPORT_FILE"
}

add_report_entry() {
    local app="$1"
    local current_version="$2"
    local latest_version="$3"
    local update_cmd="$4"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would add report entry for $app"
        return
    fi

    echo "| $app | $current_version | $latest_version | \`$update_cmd\` |" >> "$REPORT_FILE"
}
