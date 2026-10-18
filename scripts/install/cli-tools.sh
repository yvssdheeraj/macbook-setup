#!/usr/bin/env bash
# scripts/install/cli-tools.sh

source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../utils/report.sh"

install_gh_cli() {
    log_info "Installing GitHub CLI (gh)..."
    local bin_dir="$HOME/.local/bin"
    mkdir -p "$bin_dir"

    if command -v gh &> /dev/null || [[ -f "$bin_dir/gh" ]]; then
        log_info "GitHub CLI is already installed."
    else
        execute_cmd "curl -L -o /tmp/gh.tar.gz https://github.com/cli/cli/releases/latest/download/gh_2.42.1_macOS_arm64.tar.gz"
        execute_cmd "tar -xzf /tmp/gh.tar.gz -C /tmp"
        execute_cmd "mv /tmp/gh_*_macOS_arm64/bin/gh $bin_dir/"
        execute_cmd "rm -rf /tmp/gh.tar.gz /tmp/gh_*_macOS_arm64"
    fi

    if [[ "$DRY_RUN" != "true" ]]; then
        add_report_entry "GitHub CLI" "$($bin_dir/gh --version | head -n 1 | awk '{print $3}')" "Latest" "Download release binary"
    else
        add_report_entry "GitHub CLI" "N/A" "Latest" "Download release binary"
    fi
}

install_aws_cli() {
    log_info "Installing AWS CLI..."
    local bin_dir="$HOME/.local/bin"
    mkdir -p "$bin_dir"

    if command -v aws &> /dev/null || [[ -f "$HOME/.cargo/bin/aws" ]] || [[ -f "$bin_dir/aws" ]]; then
        log_info "AWS CLI is already installed."
    else
        # We install AWS CLI cleanly at the user level using uv
        # This requires uv to be installed first.
        export PATH="$HOME/.cargo/bin:$PATH"
        if command -v uv &> /dev/null; then
            if [[ "$DRY_RUN" != "true" ]]; then
                execute_cmd "uv tool install awscli"
                log_success "AWS CLI installed via uv."
            else
                log_info "[DRY-RUN] Would install awscli via uv tool install"
            fi
        else
            log_error "uv not found, skipping AWS CLI installation."
        fi
    fi

    if [[ "$DRY_RUN" != "true" ]]; then
        local aws_cmd="aws"
        [[ -f "$HOME/.cargo/bin/aws" ]] && aws_cmd="$HOME/.cargo/bin/aws"
        local version
    version=$($aws_cmd --version 2>&1 | awk '{print $1}' | cut -d/ -f2 || echo "Unknown")
        add_report_entry "AWS CLI" "$version" "Latest" "uv tool upgrade awscli"
    else
        add_report_entry "AWS CLI" "N/A" "Latest" "uv tool upgrade awscli"
    fi
}

install_gh_cli
install_aws_cli
