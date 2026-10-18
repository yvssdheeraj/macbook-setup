#!/usr/bin/env bash
# scripts/customize/dotfiles.sh

source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../utils/backup.sh"

install_dotfiles() {
    log_info "Configuring Shell Environment and Dotfiles..."

    local zshrc_target="$HOME/.zshrc"
    local zshrc_source="$REPO_ROOT/dotfiles/zshrc"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would backup and replace ~/.zshrc"
        log_info "[DRY-RUN] Would configure Ghostty preferences"
        return
    fi

    # 1. ZSHRC
    if [[ -f "$zshrc_target" ]]; then
        # Check if it's already our managed one to avoid endless backups
        if ! grep -q "# Path configuration" "$zshrc_target" 2>/dev/null; then
            backup_file "$zshrc_target"
            cp "$zshrc_source" "$zshrc_target"
            log_success "Updated ~/.zshrc"
        else
            log_info "~/.zshrc is already configured."
        fi
    else
        cp "$zshrc_source" "$zshrc_target"
        log_success "Created ~/.zshrc"
    fi

    # 2. AWS Config (Using user.env settings if any)
    if [[ -n "$AWS_DEFAULT_REGION" || -n "$AWS_PROFILE" ]]; then
        mkdir -p "$HOME/.aws"
        local aws_config="$HOME/.aws/config"
        if [[ ! -f "$aws_config" ]]; then
            cat << EOF > "$aws_config"
[default]
region = ${AWS_DEFAULT_REGION:-us-east-1}
output = json

[profile ${AWS_PROFILE:-dev}]
region = ${AWS_DEFAULT_REGION:-us-east-1}
output = json
EOF
            log_success "Created ~/.aws/config"
        fi
    fi

    # 3. Ghostty Config
    local ghostty_dir="$HOME/Library/Application Support/com.mitchellh.ghostty"
    mkdir -p "$ghostty_dir"
    if [[ -f "$REPO_ROOT/dotfiles/ghostty_config" ]]; then
        cp "$REPO_ROOT/dotfiles/ghostty_config" "$ghostty_dir/config"
        log_success "Configured Ghostty preferences."
    fi
}

install_dotfiles
