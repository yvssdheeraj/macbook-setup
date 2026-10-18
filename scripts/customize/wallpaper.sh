#!/usr/bin/env bash
# scripts/customize/wallpaper.sh

source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"

customize_wallpaper() {
    log_info "Configuring Wallpaper..."

    local wallpaper_src="$REPO_ROOT/assets/black-wallpaper.png"
    local target_dir="$HOME/Pictures/Wallpapers"
    local target_file="$target_dir/black-wallpaper.png"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would copy black wallpaper and update SQLite DB."
        return
    fi

    mkdir -p "$target_dir"
    cp -a "$wallpaper_src" "$target_file"

    local db_path="$HOME/Library/Application Support/Dock/desktoppicture.db"

    # Some systems might not have the DB yet or we need to kill Dock to flush it
    if [[ -f "$db_path" ]]; then
        # Check if sqlite3 is available
        if command -v sqlite3 &> /dev/null; then
            # Insert the new picture path into the data table and point preferences to it.
            # To be absolutely safe and idempotent, we just update all rows in the data table
            # to point to the new image, or update the preferences.
            # The safest approach for 10.14+ is:
            sqlite3 "$db_path" "UPDATE data SET value = '$target_file';"

            # Restart Dock to apply
            killall Dock
            log_success "Black wallpaper configured via DB."
        else
            log_warn "sqlite3 not found, skipping wallpaper configuration."
        fi
    else
        log_warn "Desktop picture DB not found at $db_path. Cannot silently set wallpaper."
    fi
}

customize_wallpaper
