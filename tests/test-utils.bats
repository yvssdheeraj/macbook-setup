#!/usr/bin/env bats
# shellcheck disable=SC2016
load helpers

setup() { setup_fixture; }

@test "argument execution preserves spaces and does not interpret shell code" {
    fixture_run 'execute_cmd printf "%s" "value; touch $HOME/pwned"'
    assert_success
    assert_output --partial 'value; touch'
    [[ ! -e "$HOME/pwned" ]]
}

@test "managed files preserve the original and restore it on uninstall" {
    printf 'original\n' > "$HOME/config"
    fixture_run 'printf "managed\n" | managed_file "$HOME/config"; support uninstall'
    assert_success
    [[ "$(cat "$HOME/config")" == original ]]
}

@test "managed file reruns do not replace the original backup" {
    printf 'original\n' > "$HOME/config"
    fixture_run 'printf "managed\n" | managed_file "$HOME/config"; printf "managed\n" | managed_file "$HOME/config"; printf "updated\n" | managed_file "$HOME/config"; support uninstall'
    assert_success
    [[ "$(cat "$HOME/config")" == original ]]
}

@test "an interrupted snapshot does not authorize overwriting an unexpected destination" {
    fixture_run 'snapshot_path "$HOME/config"; printf "unexpected\n" > "$HOME/config"; printf "managed\n" | managed_file "$HOME/config"'
    assert_failure
    assert_output --partial 'Interrupted installation needs inspection'
    [[ "$(cat "$HOME/config")" == unexpected ]]
}

@test "an intended write after an interrupted external installer seals the pending receipt" {
    fixture_run 'snapshot_path "$HOME/config"; printf "managed\n" > "$HOME/config"; printf "managed\n" | managed_file "$HOME/config"; support uninstall'
    assert_success
    [[ ! -e "$HOME/config" ]]
}

@test "managed directory symlinks restore their original target" {
    mkdir "$HOME/original" "$HOME/replacement"
    ln -s original "$HOME/current"
    fixture_run 'managed_link "$HOME/current" "$HOME/replacement"; support uninstall'
    assert_success
    [[ -L "$HOME/current" && "$(readlink "$HOME/current")" == original ]]
}

@test "tree replacement stages alongside its destination and supports a later replacement" {
    mkdir "$HOME/first" "$HOME/second"
    printf 'first\n' > "$HOME/first/config"
    printf 'second\n' > "$HOME/second/config"
    fixture_run 'snapshot_path "$HOME/tree"; support replace-tree "$HOME/first" "$HOME/tree"; seal_path "$HOME/tree"; snapshot_path "$HOME/tree"; support replace-tree "$HOME/second" "$HOME/tree"; seal_path "$HOME/tree"'
    assert_success
    [[ "$(cat "$HOME/tree/config")" == second ]]
    [[ -f "$HOME/first/config" && -f "$HOME/second/config" ]]
    run find "$HOME" -name 'tree.incoming-*' -o -name 'tree.previous-*'
    assert_success
    assert_output ''
}

@test "permission changes count as user edits during removal" {
    fixture_run 'printf "managed\n" | managed_file "$HOME/config"; chmod 644 "$HOME/config"; support uninstall'
    assert_failure
    [[ -f "$HOME/config" ]]
}

@test "a preference command that succeeds without changing the value reports failure" {
    stub defaults 'if [[ "$1" == write ]]; then exit 0; fi; echo "does not exist" >&2; exit 1'
    fixture_run 'support preference NSGlobalDomain AppleInterfaceStyle string Dark'
    assert_failure
    assert_output --partial 'Preference write did not take effect'
}

@test "uninstall preserves edits made after installation and reports incomplete removal" {
    fixture_run 'printf "managed\n" | managed_file "$HOME/config"; printf "personal\n" > "$HOME/config"; support uninstall'
    assert_failure
    assert_output --partial 'Retaining user-modified'
    [[ "$(cat "$HOME/config")" == personal ]]
}

@test "block removal preserves unrelated edits made after setup" {
    printf 'personal=before\n' > "$HOME/config"
    fixture_run 'printf "managed=true\n" | managed_block "$HOME/config"; printf "personal=after\n" >> "$HOME/config"; support uninstall'
    assert_success
    [[ "$(cat "$HOME/config")" == $'personal=before\npersonal=after' ]]
}

@test "managed blocks preserve a user-owned symlink" {
    printf 'personal\n' > "$HOME/real-config"
    ln -s real-config "$HOME/config"
    fixture_run 'printf "managed\n" | managed_block "$HOME/config"; support uninstall'
    assert_success
    [[ -L "$HOME/config" ]]
    [[ "$(cat "$HOME/real-config")" == personal ]]
}

@test "edited managed blocks are not silently replaced" {
    fixture_run 'printf "managed\n" | managed_block "$HOME/config"; sed "s/managed$/personal/" "$HOME/config" > "$HOME/edited"; mv "$HOME/edited" "$HOME/config"; printf "new\n" | managed_block "$HOME/config"'
    assert_failure
    assert_output --partial 'Managed block was edited'
}

@test "a direct mutating module cannot bypass the planner in dry-run mode" {
    export DRY_RUN=true
    before="$(home_digest)"
    run bash scripts/install/btop.sh
    assert_failure
    assert_output --partial 'through setup.sh'
    [[ "$(home_digest)" == "$before" ]]
    [[ ! -e "$COMMAND_LOG" ]]
}

@test "a child failure propagates rather than becoming a successful last log line" {
    fixture_run 'execute_cmd false; log_success "not reached"'
    assert_failure
    refute_output --partial 'not reached'
}

@test "read-only uninstall does not create state or change resources" {
    fixture_run 'printf "managed\n" | managed_file "$HOME/config"'
    assert_success
    before="$(home_digest)"
    run bash uninstall.sh --dry-run
    assert_success
    assert_output --partial '[DRY-RUN]'
    [[ "$(home_digest)" == "$before" ]]
}
