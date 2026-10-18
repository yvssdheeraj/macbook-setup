#!/usr/bin/env bash
# scripts/install/git.sh

source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"

install_git_config() {
    log_info "Configuring Git..."

    if [[ -z "$GIT_USER_NAME" || -z "$GIT_USER_EMAIL" ]]; then
        log_warn "Git user name or email not set in config/user.env. Skipping full Git config."
        return
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would configure git for $GIT_USER_NAME <$GIT_USER_EMAIL>"
    else
        git config --global user.name "$GIT_USER_NAME"
        git config --global user.email "$GIT_USER_EMAIL"
        git config --global init.defaultBranch "${GIT_DEFAULT_BRANCH:-main}"
        git config --global core.editor "${GIT_EDITOR:-nano}"
        log_success "Git configured."
    fi
}

install_git_config
