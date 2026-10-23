#!/usr/bin/env bats
# shellcheck disable=SC2016
load helpers

setup() {
    setup_fixture
    stub sysctl 'echo 1'
    stub docker '
printf "docker %s\n" "$*" >> "$COMMAND_LOG"
case "$*" in
    --version) echo "Docker version 28.0";;
    "--context colima-macbook-setup info") exit 0;;
    "--context colima-macbook-setup version"*) echo 28.0;;
    *) exit 2;;
esac'
    stub limactl 'echo "limactl version 1.0"'
    stub colima '
printf "colima %s\n" "$*" >> "$COMMAND_LOG"
case "$1" in
    --version) echo "colima version 1.0";;
    status)
        if [[ -f "$HOME/colima-running" ]]; then echo running;
        else echo "profile is not running" >&2; exit 1; fi;;
    start)
        [[ "$*" == *--activate=false* && "$*" == *--ssh-config=false* ]]
        touch "$HOME/colima-running";;
    stop)
        [[ "${FAIL_COLIMA_STOP:-false}" != true ]] || exit 4
        rm "$HOME/colima-running";;
    *) exit 2;;
esac'
}

@test "starting an existing stopped Colima profile owns only its activation and leaves global contexts alone" {
    mkdir -p "$DATA_DIR/colima/macbook-setup"
    printf 'existing VM data\n' > "$DATA_DIR/colima/macbook-setup/disk"
    run bash setup.sh --only docker
    assert_success
    [[ -f "$HOME/colima-running" ]]
    grep -Fq -- '--activate=false --ssh-config=false --cpus 2' "$COMMAND_LOG"
    run bash uninstall.sh --yes
    assert_success
    [[ ! -e "$HOME/colima-running" ]]
    [[ -f "$DATA_DIR/colima/macbook-setup/disk" ]]
    run grep -Fq 'docker context use' "$COMMAND_LOG"
    assert_failure
}

@test "a failed Colima stop prevents deletion of its dependencies" {
    touch "$HOME/colima-running"
    export FAIL_COLIMA_STOP=true
    fixture_run 'printf "required\n" | managed_file "$HOME/dependency"; support colima "$DATA_DIR/colima"; support uninstall'
    assert_failure
    assert_output --partial 'Could not stop owned Colima profile'
    [[ -f "$HOME/dependency" ]]
}

@test "a loaded unowned LaunchAgent is not adopted or overwritten" {
    export COLIMA_START_AT_LOGIN=true
    mkdir -p "$HOME/Library/LaunchAgents"
    printf 'personal service\n' > "$HOME/Library/LaunchAgents/dev.macbook-setup.colima.plist"
    stub launchctl 'exit 0'
    run bash setup.sh --only docker
    assert_failure
    assert_output --partial 'Loaded LaunchAgent is not unchanged and repo-owned'
    [[ "$(cat "$HOME/Library/LaunchAgents/dev.macbook-setup.colima.plist")" == 'personal service' ]]
    [[ ! -f "$HOME/colima-running" ]]
}

@test "a failed service shutdown stops removal before managed files are deleted" {
    stub launchctl 'if [[ "$1" == print ]]; then exit 0; fi; echo "cannot stop service" >&2; exit 4'
    fixture_run 'printf "agent\n" | managed_file "$HOME/agent.plist"; support service "$HOME/agent.plist"; support uninstall'
    assert_failure
    assert_output --partial 'cannot stop service'
    [[ -f "$HOME/agent.plist" ]]
}
