#!/usr/bin/env bash

COMPONENTS="homebrew git node python java docker maccy vscode gh aws intellij chrome duckduckgo ghostty oh-my-zsh gradle dbeaver btop dotfiles appearance trackpad wallpaper dock"
DEFAULT_COMPONENTS="git node python java docker maccy vscode gh aws intellij chrome duckduckgo ghostty oh-my-zsh gradle dbeaver btop dotfiles"
SELECTED=""
EXCLUDED=""

expand_component() {
    case "$1" in
        browsers) printf '%s\n' chrome duckduckgo ;;
        cli-tools) printf '%s\n' gh aws ;;
        macos-customization) printf '%s\n' appearance trackpad wallpaper dock ;;
        *)
            case " $COMPONENTS " in
                *" $1 "*) printf '%s\n' "$1" ;;
                *) log_error "Unknown component: $1"; return 1 ;;
            esac
            ;;
    esac
}

component_dependencies() {
    case "$1" in
        gradle) printf '%s\n' java ;;
        dotfiles) printf '%s\n' oh-my-zsh ;;
    esac
}

add_component() {
    local component="$1" dependency
    case " $EXCLUDED " in
        *" $component "*) log_error "Required dependency $component was explicitly skipped."; return 1 ;;
    esac
    case " $SELECTED " in *" $component "*) return 0 ;; esac
    for dependency in $(component_dependencies "$component"); do
        add_component "$dependency" || return
    done
    SELECTED="${SELECTED:+$SELECTED }$component"
}

parse_component_list() {
    local list="$1" item expanded
    [[ -n "$list" && "$list" != ,* && "$list" != *, && "$list" != *,,* && "$list" != *[[:space:]]* ]] ||
        { log_error "Expected a nonempty comma-separated component list: $list"; return 1; }
    local items=()
    IFS=, read -r -a items <<< "$list"
    for item in "${items[@]}"; do
        expanded="$(expand_component "$item")" || return
        printf '%s\n' "$expanded"
    done
}

select_components() {
    local only="$1" skip="$2" candidates component
    if [[ -n "$skip" ]]; then
        EXCLUDED="$(parse_component_list "$skip")" || return
        EXCLUDED="${EXCLUDED//$'\n'/ }"
    fi
    if [[ -n "$only" ]]; then
        candidates="$(parse_component_list "$only")" || return
    else
        candidates="$DEFAULT_COMPONENTS"
    fi
    for component in $candidates; do
        case " $EXCLUDED " in
            *" $component "*)
                [[ -z "$only" ]] || { log_error "$component is both selected and skipped."; return 1; }
                continue
                ;;
        esac
        add_component "$component" || return
    done
    [[ -n "$SELECTED" ]] || { log_error "No components selected."; return 1; }
}

component_script() {
    case "$1" in
        node) printf '%s\n' install/nvm-node.sh ;;
        python) printf '%s\n' install/uv-python.sh ;;
        java) printf '%s\n' install/sdkman-java.sh ;;
        docker) printf '%s\n' install/docker-colima.sh ;;
        gh|aws) printf '%s\n' install/cli-tools.sh ;;
        chrome|duckduckgo) printf '%s\n' install/browsers.sh ;;
        appearance|trackpad|wallpaper|dock|dotfiles) printf 'customize/%s.sh\n' "$1" ;;
        *) printf 'install/%s.sh\n' "$1" ;;
    esac
}
