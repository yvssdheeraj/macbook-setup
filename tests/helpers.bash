# shellcheck disable=SC2016
setup_fixture() {
    load "${BATS_SUPPORT_DIR:?Run tests through make test}/load.bash"
    load "${BATS_ASSERT_DIR:?Run tests through make test}/load.bash"
    export TEST_REPO
    TEST_REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    export HOME="$BATS_TEST_TMPDIR/home with spaces"
    mkdir -p "$HOME" "$BATS_TEST_TMPDIR/bin"
    unset NVM_DIR SDKMAN_DIR ZSH BREW_PREFIX LOCAL_BIN APP_DIR STATE_DIR CACHE_DIR DATA_DIR
    unset NODE_VERSION PYTHON_VERSION JAVA_VERSION JAVA_LTS GRADLE_VERSION DRY_RUN MODE
    unset GIT_CONFIG_GLOBAL GIT_CONFIG_SYSTEM BASH_ENV ENV
    export STATE_DIR="$HOME/state" CACHE_DIR="$HOME/cache" DATA_DIR="$HOME/data"
    export BREW_PREFIX="$HOME/brew" LOCAL_BIN="$HOME/bin" APP_DIR="$HOME/Applications"
    export NVM_DIR="$HOME/nvm" SDKMAN_DIR="$HOME/sdkman" ZSH="$HOME/oh-my-zsh"
    export GIT_CONFIG_NOSYSTEM=1
    export GIT_USER_NAME="Setup Test" GIT_USER_EMAIL="setup@example.invalid"
    export PATH="$BATS_TEST_TMPDIR/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    export COMMAND_LOG="$BATS_TEST_TMPDIR/commands.log"
    cd "$TEST_REPO" || return
    stub uname '
case "$1" in -s) echo "${TEST_OS:-Darwin}";; -m) echo "${TEST_ARCH:-arm64}";; *) /usr/bin/uname "$@";; esac'
    stub sw_vers 'echo 15.0'
    stub xcode-select 'exit "${NO_DEVELOPER_TOOLS:-0}"'
    stub curl 'printf "curl %s\n" "$*" >> "$COMMAND_LOG"; exit 22'
    stub sudo 'printf "FORBIDDEN sudo\n" >> "$COMMAND_LOG"; exit 99'
    stub git '
if [[ "${1:-}" == -C && "${3:-}" == rev-parse ]]; then
    printf "0123456789012345678901234567890123456789\n"
else
    /usr/bin/git "$@"
fi'
}

stub() {
    printf '#!/usr/bin/env bash\nset -euo pipefail\n%s\n' "$2" > "$BATS_TEST_TMPDIR/bin/$1"
    chmod +x "$BATS_TEST_TMPDIR/bin/$1"
}

fixture_run() {
    run bash -c 'set -euo pipefail; source scripts/common.sh; initialize_run; export CURRENT_COMPONENT=fixture; '"$1"
}

home_digest() {
    ruby -rdigest -rjson -e '
root = ENV.fetch("HOME")
puts JSON.generate(Dir.glob("#{root}/**/*", File::FNM_DOTMATCH).sort.reject { |p| %w[. ..].include?(File.basename(p)) }.map { |p| [p.delete_prefix(root), File.directory?(p) ? "directory" : Digest::SHA256.file(p).hexdigest] })'
}

latest_report_status() {
    ruby -rjson -e '
path = Dir.glob("#{ENV.fetch("STATE_DIR")}/reports/*.md.json").max_by { |p| File.mtime(p) }
puts JSON.parse(File.read(path)).fetch("components").last.fetch("status")'
}
