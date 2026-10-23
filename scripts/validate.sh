#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
source "$REPO_ROOT/scripts/packages.sh"

if [[ $# -eq 0 ]]; then
    exec bash "$REPO_ROOT/setup.sh" --validate
fi
component="$1"
case "$component" in
    homebrew) "$BREW_PREFIX/bin/brew" --version ;;
    git)
        git --version
        [[ -n "$(git config --global --includes user.name)" && -n "$(git config --global --includes user.email)" ]] ||
            blocked "Git identity is missing."
        ;;
    node)
        if command -v node >/dev/null; then
            node --version
        else
            version="$(cat "$NVM_DIR/alias/default")"
            [[ "$version" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+$ ]] || blocked "Open a shell with NVM loaded to validate this existing alias."
            "$NVM_DIR/versions/node/v${version#v}/bin/node" --version
        fi
        ;;
    python)
        uv --version
        export UV_PYTHON_INSTALL_DIR="$DATA_DIR/python"
        python="$(uv python find --no-config --system --managed-python --offline --no-python-downloads)"
        "$python" --version
        ;;
    java) "$SDKMAN_DIR/candidates/java/current/bin/java" -version ;;
    gradle)
        export JAVA_HOME="$SDKMAN_DIR/candidates/java/current"
        "$SDKMAN_DIR/candidates/gradle/current/bin/gradle" --version ;;
    docker)
        export COLIMA_HOME="$DATA_DIR/colima"
        colima status --profile macbook-setup
        docker --context colima-macbook-setup info ;;
    gh) gh --version ;;
    aws)
        version="$(aws --version 2>&1)"
        [[ "$version" == aws-cli/2.* ]] || blocked "AWS CLI v2 is not available."
        printf '%s\n' "$version" ;;
    btop) btop --version ;;
    maccy|vscode|intellij|chrome|duckduckgo|ghostty|dbeaver)
        case "$component" in
            maccy) app=Maccy.app ;;
            vscode) app='Visual Studio Code.app' ;;
            intellij) app='IntelliJ IDEA.app' ;;
            chrome) app='Google Chrome.app' ;;
            duckduckgo) app=DuckDuckGo.app ;;
            ghostty) app=Ghostty.app ;;
            dbeaver) app=DBeaver.app ;;
        esac
        if [[ "$component" == intellij ]]; then
            path="$(find_app "$app" 'IntelliJ IDEA CE.app')" || blocked "Missing application: $app"
        else
            path="$(find_app "$app")" || blocked "Missing application: $app"
        fi
        verify_app "$path"
        app_version "$path"
        if [[ "$component" == vscode ]]; then code --version; fi
        ;;
    oh-my-zsh)
        [[ -s "$ZSH/oh-my-zsh.sh" ]] || blocked "Oh My Zsh is missing."
        for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
            [[ -s "$DATA_DIR/zsh-plugins/$plugin/$plugin.zsh" ]] || blocked "Missing Zsh plugin: $plugin"
        done ;;
    dotfiles)
        grep -Fq '# >>> macbook-setup:dotfiles >>>' "$HOME/.zshrc" || blocked "Shell integration is missing."
        zsh -n "$DATA_DIR/shell.zsh"
        ;;
    appearance) [[ "$(defaults read NSGlobalDomain AppleInterfaceStyle)" == Dark ]] ;;
    trackpad)
        for domain in com.apple.driver.AppleBluetoothMultitouch.trackpad com.apple.AppleMultitouchTrackpad; do
            [[ "$(defaults read "$domain" Clicking)" == 1 && "$(defaults read "$domain" TrackpadRightClick)" == 1 ]]
            [[ "$(defaults read "$domain" TrackpadCornerSecondaryClick)" == 0 ]]
        done
        [[ "$(defaults read NSGlobalDomain com.apple.trackpad.scaling)" == 2.4 ]]
        ;;
    wallpaper) support wallpaper-check ;;
    dock)
        path="$(find_app 'Google Chrome.app')" || blocked "Chrome is missing."
        support dock-check "$path" ;;
    *) fatal "Unknown component: $component" ;;
esac
log_success "$component verified."
