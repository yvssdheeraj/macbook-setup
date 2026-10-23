#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"
export REPO_ROOT="$PWD"
source "$REPO_ROOT/scripts/common.sh"
source "$REPO_ROOT/scripts/components.sh"
source "$REPO_ROOT/scripts/preflight.sh"

usage() {
    cat <<'EOF'
Usage: ./setup.sh [--dry-run] [--update | --validate] [--only LIST] [--skip LIST]
                  [--config FILE] [--list] [--help]

Setup installs missing tools without upgrading existing installations.
--update upgrades only repo-owned installations, tracking stable/LTS channels.
--validate probes selected components without setup writes; tools may update caches.
--dry-run prints a read-only plan; it performs no downloads or installations.
LIST is comma-separated. Dependencies are included; explicit skip conflicts fail.
Desktop preferences are opt-in: appearance, trackpad, wallpaper, dock.
Aliases: browsers, cli-tools, macos-customization.
EOF
}

ONLY=""
SKIP=""
CONFIG_FILE="$REPO_ROOT/config/user.env"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true; shift ;;
        --update|--validate)
            [[ "$MODE" == install ]] || fatal "--update and --validate are mutually exclusive."
            MODE="${1#--}"; shift ;;
        --only|--skip|--config)
            [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || fatal "$1 requires a value."
            case "$1" in
                --only) ONLY="$2" ;;
                --skip) SKIP="$2" ;;
                --config) CONFIG_FILE="$2" ;;
            esac
            shift 2 ;;
        --list) printf '%s\n' "$COMPONENTS"; exit 0 ;;
        --help|-h) usage; exit 0 ;;
        *) log_error "Unknown option: $1"; usage >&2; exit 2 ;;
    esac
done
export DRY_RUN MODE
load_configuration "$CONFIG_FILE"
select_components "$ONLY" "$SKIP"
preflight_checks

printf 'Mode: %s%s\nComponents: %s\n' "$MODE" "$([[ "$DRY_RUN" == true ]] && printf ' (dry-run)' || true)" "$SELECTED"
printf 'Homebrew: %s (custom home prefix; reduced bottle compatibility)\nApplications: %s\n' "$BREW_PREFIX" "$APP_DIR"
if [[ "$DRY_RUN" == true ]]; then
    for component in $SELECTED; do
        printf '[DRY-RUN] %s %s; verify actual state; preserve pre-existing resources\n' "$MODE" "$component"
    done
    exit 0
fi

if [[ "$MODE" != validate ]]; then
    initialize_run
fi

failed=""
result=0
for component in $SELECTED; do
    dependency_failed=false
    for dependency in $(component_dependencies "$component"); do
        case " $failed " in *" $dependency "*) dependency_failed=true ;; esac
    done
    if [[ "$dependency_failed" == true ]]; then
        log_error "BLOCKED: $component has a failed dependency."
        failed="$failed $component"
        result=1
        if [[ "$MODE" != validate ]]; then
            support report "$component" blocked "A required dependency failed."
        fi
        continue
    fi
    export CURRENT_COMPONENT="$component"
    log_info "$MODE: $component"
    status=0
    if [[ "$MODE" == validate ]]; then
        bash "$REPO_ROOT/scripts/validate.sh" "$component" || status=$?
    else
        log_file="$STATE_DIR/reports/$(basename "$REPORT_FILE" .md)-$component.log"
        bash "$REPO_ROOT/scripts/$(component_script "$component")" 2>&1 | tee "$log_file" || status=$?
    fi
    if [[ "$status" -eq 0 ]]; then
        if [[ "$MODE" != validate ]]; then
            outcome=unchanged
            [[ ! -f "$RUN_DIR/changed.$component" ]] || outcome=changed
            support report "$component" "$outcome" "Verified."
        fi
    else
        failed="$failed $component"
        result=1
        outcome=failed
        [[ "$status" -ne 78 ]] || outcome=blocked
        log_error "$component: $outcome (exit $status)."
        if [[ "$MODE" != validate ]]; then
            support report "$component" "$outcome" "Exit $status; see $(basename "$log_file")."
        fi
    fi
done
if [[ "$MODE" != validate ]]; then
    log_info "Report: $REPORT_FILE"
fi
if [[ "$result" -ne 0 ]]; then
    log_error "Setup is incomplete. Failed or blocked components:$failed"
else
    log_success "All selected components verified."
fi
exit "$result"
