#!/usr/bin/env bash
# scripts/install/sdkman-java.sh

source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../utils/report.sh"

install_sdkman() {
    log_info "Installing SDKMAN! and Java..."

    export SDKMAN_DIR="$HOME/.sdkman"

    if [[ -d "$SDKMAN_DIR" ]]; then
        log_info "SDKMAN! is already installed."
    else
        execute_cmd "curl -s \"https://get.sdkman.io\" | bash"
    fi

    if [[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]]; then
        source "$SDKMAN_DIR/bin/sdkman-init.sh"

        local target_version="${JAVA_VERSION:-17.0.9-tem}"
        log_info "Installing Java version $target_version..."

        # sdkman doesn't like dry-run evals sometimes, so be careful
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[DRY-RUN] Would execute: sdk install java $target_version"
            add_report_entry "Java (SDKMAN)" "N/A" "$target_version" "sdk install java <version>"
        else
            sdk install java "$target_version"
            sdk default java "$target_version"

            local current_ver
    current_ver=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
            add_report_entry "Java (SDKMAN)" "${current_ver:-Unknown}" "$target_version" "sdk update && sdk upgrade java"
        fi
    elif [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would source SDKMAN! and install Java ${JAVA_VERSION:-17.0.9-tem}"
        add_report_entry "Java (SDKMAN)" "N/A" "${JAVA_VERSION:-17.0.9-tem}" "sdk install java <version>"
    fi
}

install_sdkman
