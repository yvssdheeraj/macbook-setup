#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"

add_report_entry() {
    record_version "$1" "$2" "$3"
}
