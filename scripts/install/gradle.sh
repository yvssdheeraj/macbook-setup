#!/usr/bin/env bash
# scripts/install/gradle.sh

source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../utils/report.sh"

install_gradle() {
    log_info "Installing Gradle..."

    export SDKMAN_DIR="$HOME/.sdkman"

    local target_version="${GRADLE_VERSION:-8.5}"

    if [[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]]; then
        source "$SDKMAN_DIR/bin/sdkman-init.sh"

        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[DRY-RUN] Would install Gradle $target_version via SDKMAN!"
            add_report_entry "Gradle" "N/A" "$target_version" "sdk install gradle <version>"
        else
            sdk install gradle "$target_version"
            sdk default gradle "$target_version"

            local current_ver
    current_ver=$(gradle -v 2>/dev/null | grep Gradle | awk '{print $2}')
            add_report_entry "Gradle" "${current_ver:-Unknown}" "$target_version" "sdk upgrade gradle"
        fi
    else
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[DRY-RUN] Would source SDKMAN and install Gradle $target_version"
            add_report_entry "Gradle" "N/A" "$target_version" "sdk install gradle <version>"
        else
            log_error "SDKMAN! not found, cannot install Gradle."
        fi
    fi
}

install_gradle
