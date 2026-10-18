#!/usr/bin/env bash
# scripts/customize/appearance.sh

source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"

customize_appearance() {
    log_info "Configuring Dark Mode..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would enable Dark Mode."
        return
    fi

    # Tell System Events to switch to Dark Mode (This may trigger a prompt the *first* time
    # if it's run via osascript, but there is a non-prompting way using defaults, though
    # it requires a restart/logout to fully take effect usually.
    # Let's try osascript since it's the standard API, but if the user absolutely rejects prompts,
    # the defaults way is:
    defaults write -g AppleInterfaceStyle -string "Dark"

    # We can also attempt to notify distributed notifications or restart Finder to avoid prompt,
    # but the defaults write is safest for zero-prompts.
    log_success "Dark Mode configured (may require logout/restart to apply fully)."
}

customize_appearance
