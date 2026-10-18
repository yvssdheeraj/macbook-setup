#!/usr/bin/env bash
# setup.sh

set -e

# Change to the directory of the script
cd "$(dirname "${BASH_SOURCE[0]}")"
export REPO_ROOT="$(pwd)"

source "scripts/common.sh"
source "scripts/preflight.sh"
source "scripts/utils/report.sh"

usage() {
    cat << EOF
Usage: ./setup.sh [OPTIONS]

Options:
  --dry-run                 Simulate the setup process without making system changes.
  --only <list>             Comma-separated list of components to install (e.g., git,node,python).
  --skip <list>             Comma-separated list of components to skip.
  --validate                Run validation checks on the setup.
  --help                    Show this help message.

Example:
  ./setup.sh --dry-run
  ./setup.sh --only git,docker
  ./setup.sh --skip macos-customization
EOF
    exit 0
}

# Parse Arguments
ONLY=""
SKIP=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            export DRY_RUN=true
            shift
            ;;
        --only)
            ONLY="$2"
            shift 2
            ;;
        --skip)
            SKIP="$2"
            shift 2
            ;;
        --validate)
            bash scripts/validate.sh
            exit 0
            ;;
        --help)
            usage
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            ;;
    esac
done

if [[ "$DRY_RUN" == "true" ]]; then
    log_info "========== DRY RUN MODE ENABLED =========="
fi

# 1. Preflight
preflight_checks

# 2. Load Configuration
if [[ -f "$REPO_ROOT/config/user.env" ]]; then
    log_info "Loading configuration from config/user.env..."
    set -a
    source "$REPO_ROOT/config/user.env"
    set +a
else
    log_warn "config/user.env not found. Using defaults. Please copy config/user.example.env to config/user.env and configure it."
fi

# 3. Init Report
init_report

# Helper to check if a component should be run
should_run() {
    local component="$1"

    if [[ -n "$ONLY" ]]; then
        if [[ ",$ONLY," != *",$component,"* ]]; then
            return 1
        fi
    fi

    if [[ -n "$SKIP" ]]; then
        if [[ ",$SKIP," == *",$component,"* ]]; then
            return 1
        fi
    fi

    return 0
}

# 4. Installations
log_info "Starting installations..."

if should_run "git"; then bash scripts/install/git.sh; fi
if should_run "node"; then bash scripts/install/nvm-node.sh; fi
if should_run "python"; then bash scripts/install/uv-python.sh; fi
if should_run "java"; then bash scripts/install/sdkman-java.sh; fi
if should_run "docker"; then bash scripts/install/docker-colima.sh; fi
if should_run "maccy"; then bash scripts/install/maccy.sh; fi
if should_run "vscode"; then bash scripts/install/vscode.sh; fi
if should_run "cli-tools"; then bash scripts/install/cli-tools.sh; fi
if should_run "intellij"; then bash scripts/install/intellij.sh; fi
if should_run "browsers"; then bash scripts/install/browsers.sh; fi
if should_run "ghostty"; then bash scripts/install/ghostty.sh; fi
if should_run "oh-my-zsh"; then bash scripts/install/oh-my-zsh.sh; fi
if should_run "gradle"; then bash scripts/install/gradle.sh; fi
if should_run "dbeaver"; then bash scripts/install/dbeaver.sh; fi
if should_run "btop"; then bash scripts/install/btop.sh; fi

# 5. MacOS Customization
if should_run "macos-customization"; then
    log_info "Starting macOS customizations..."
    bash scripts/customize/trackpad.sh
    bash scripts/customize/appearance.sh
    bash scripts/customize/wallpaper.sh
    bash scripts/customize/dock.sh
fi

# 6. Dotfiles / Environment
if should_run "dotfiles"; then
    bash scripts/customize/dotfiles.sh
fi

log_success "Setup complete! Please check the Setup_Report.md on your Desktop."
