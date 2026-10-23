#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../packages.sh"

[[ "$(sysctl -n kern.hv_support)" == 1 ]] || blocked "Hardware virtualization is unavailable, as is common inside a macOS VM."
export COLIMA_HOME="$DATA_DIR/colima"
assert_user_path "$COLIMA_HOME"
agent="$HOME/Library/LaunchAgents/dev.macbook-setup.colima.plist"
if [[ "$COLIMA_START_AT_LOGIN" == true ]]; then
    service_state="$(support service-state "$agent")"
    if [[ "$service_state" == loaded ]]; then
        expected_agent="$(support launchagent "$(command -v colima)" "$COLIMA_HOME")"
        [[ "$expected_agent" == "$(cat "$agent")" ]] ||
            blocked "Unload the owned Colima LaunchAgent before changing its configuration."
    fi
fi
if [[ "$MODE" == update ]] && command -v colima >/dev/null; then
    profile_state="$(support colima-state "$COLIMA_HOME")"
    if [[ "$profile_state" == running ]]; then
        blocked "Stop the macbook-setup Colima profile before updating container binaries; running workloads will not be interrupted."
    fi
fi
install_formula docker docker
install_formula lima limactl
install_formula colima colima
profile_state="$(support colima-state "$COLIMA_HOME")"
if [[ "$profile_state" == stopped ]]; then
    support colima "$COLIMA_HOME"
    colima start --profile macbook-setup --vm-type vz --runtime docker \
        --activate=false --ssh-config=false \
        --cpus "$COLIMA_CPU" --memory "$COLIMA_MEMORY" --disk "$COLIMA_DISK"
    mark_changed
fi
docker --context colima-macbook-setup info
if [[ "$COLIMA_START_AT_LOGIN" == true ]]; then
    support colima-owned "$COLIMA_HOME" ||
        blocked "Stop the pre-existing macbook-setup profile before enabling managed login startup."
    colima_bin="$(command -v colima)"
    support launchagent "$colima_bin" "$COLIMA_HOME" |
        managed_file "$agent"
    if [[ "$service_state" == stopped ]]; then
        support service "$agent"
        launchctl bootstrap "gui/$(id -u)" "$agent"
        mark_changed
    fi
fi
record_command_version 'Docker engine' 'stable, VZ backend' docker --context colima-macbook-setup version --format '{{.Server.Version}}'
log_info "Use docker --context colima-macbook-setup; the existing global Docker context was not changed."
