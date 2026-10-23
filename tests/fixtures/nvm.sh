#!/usr/bin/env bash
nvm() {
    local version
    case "$1" in
        current)
            if [[ -f "$NVM_DIR/alias/default" ]]; then
                cat "$NVM_DIR/alias/default"
            else
                printf 'none\n'
                return 3
            fi ;;
        version-remote) printf 'v24.2.0\n' ;;
        install)
            version="$2"
            mkdir -p "$NVM_DIR/versions/node/$version/bin" "$NVM_DIR/alias"
            printf '#!/usr/bin/env bash\nprintf "v24.2.0\\n"\n' > "$NVM_DIR/versions/node/$version/bin/node"
            chmod +x "$NVM_DIR/versions/node/$version/bin/node"
            [[ -f "$NVM_DIR/alias/default" ]] || printf '%s\n' "$version" > "$NVM_DIR/alias/default"
            export PATH="$NVM_DIR/versions/node/$version/bin:$PATH"
            ;;
        use)
            export PATH="$NVM_DIR/versions/node/$2/bin:$PATH" ;;
        alias) printf '%s\n' "$3" > "$NVM_DIR/alias/$2" ;;
        which)
            version="$(cat "$NVM_DIR/alias/default")"
            printf '%s\n' "$NVM_DIR/versions/node/$version/bin/node" ;;
        *) return 1 ;;
    esac
}
if [[ -f "$NVM_DIR/alias/default" ]]; then
    version="$(cat "$NVM_DIR/alias/default")"
    export PATH="$NVM_DIR/versions/node/$version/bin:$PATH"
fi
