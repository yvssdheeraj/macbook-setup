# User-only MacBook setup

Provision development tools and selected preferences on an Apple Silicon Mac,
without `sudo`, administrator passwords, or package managers in system prefixes.
This is a small Bash orchestrator, with a Ruby standard-library helper for
configuration, receipts, backups, and reports; no configuration-management
framework is required.

## Requirements and limits

- macOS 13 or newer on Apple Silicon, a non-root account, and internet access.
- Usable Git, Ruby, curl, shasum, tar, and unzip. Apple's Git requires developer
  tools to have been provisioned separately. Source builds also need a working
  compiler/SDK; setup never installs these with administrator access.
- Home-directory Homebrew is a **Tier 3 configuration**, not the normal supported
  Apple Silicon prefix. Bottles may be unavailable or incompatible, and source
  builds can fail. Some apps require a newer macOS than this script's minimum.

Delivery prefers home-directory Homebrew, then a verified upstream binary or
application bundle, then a supported source build where implemented. There is no
universal source fallback. Packages requiring privileged installers, system
services, unavailable build tools, or unsupported distributions are reported as
blocked/failed. Setup exits nonzero if any selected component is incomplete.
It does not unpack privileged installers to bypass their requirements.

Homebrew is bootstrapped from its current stable upstream Git tag, rather than
the standard installer, which rejects typical long home prefixes. Formula
installs and app bundles remain subject to their upstream compatibility rules.
See Homebrew's [installation documentation](https://docs.brew.sh/Installation)
and [support tiers](https://docs.brew.sh/Support-Tiers).

## Configure and run

```bash
cp config/user.example.env config/user.env
# Set GIT_USER_NAME and GIT_USER_EMAIL before selecting the Git component.
./setup.sh --dry-run
./setup.sh --only git,node,python,java,gh,dotfiles
```

`config/user.env` is ignored by Git and parsed as **data, not shell code**.
Use absolute paths for overrides; `$HOME`, `~`, command substitutions, and shell
expansion are not supported in values. Quote values containing spaces.
Existing environment variables override configuration values.

```bash
./setup.sh --list
./setup.sh                              # Default development environment
./setup.sh --skip docker                # Useful inside a macOS VM
./setup.sh --only browsers,cli-tools
./setup.sh --only appearance,trackpad    # Desktop changes are opt-in
./setup.sh --dry-run --update --only node,python
./setup.sh --update --only node,python
./setup.sh --validate --only git,node,python
./setup.sh --config /absolute/path/to/preferences.env --only git
```

Dependencies are included automatically: Gradle needs Java, and shell integration
needs Oh My Zsh. Explicitly skipping a required dependency is an error.
Independent components continue after failures; dependent components are blocked.

Default components are Git, Node, Python, Java, Docker/Colima/Lima, Maccy, VS Code,
GitHub CLI, AWS CLI v2, IntelliJ IDEA, Chrome, DuckDuckGo, Ghostty, Oh My Zsh and
its plugins, Gradle, DBeaver, btop, and dotfiles. `homebrew` can also be selected
explicitly. Aliases are `browsers`, `cli-tools`, and `macos-customization`.
Appearance, trackpad, wallpaper, and Dock changes are not selected by default.
Current IntelliJ uses a unified application; paid features require a license.

`--dry-run` validates inputs and prints the selected plan without downloads or
filesystem changes. It does not prove that an upstream install will succeed.
`--validate` runs health probes without setup writes or reports; third-party
commands can maintain their own caches.

## Versions and ownership

Fresh installs resolve stable applications/CLIs, latest LTS Node, stable Python,
Temurin LTS Java, and stable Gradle. Concrete versions/revisions are recorded in
each run's report, not permanently pinned. Normal reruns preserve working
installations; explicit runtime requests can add a missing version alongside an
existing installation.

`--update` updates repo-owned installations only, retaining their delivery method.
Existing tools/apps are reused, not automatically adopted. With `JAVA_LTS=latest`,
an owned Java update stays on its current LTS major; request a specific LTS major
to change lines. Project runtime constraints and the Gradle Wrapper should still
be used. Automatically resolving new upstream versions can expose compatibility
changes; inspect the report and use explicit versions where necessary.

Downloads use HTTPS and SHA256 when upstream supplies one. Application bundles
also undergo code-signature and Gatekeeper assessment. Casks marked `no_check`
rely on those application checks; setup does not invent a checksum or remove
quarantine/security protections. Cask install/uninstall hooks are restricted;
the direct bundle fallback copies the app without executing those hooks.

## Files and preferences

| Resource | Default location |
| --- | --- |
| Homebrew | `~/.homebrew` |
| Applications | `~/Applications` |
| Executables | `~/.local/bin` |
| Managed data | `~/.local/share/macbook-setup` |
| State, backups, logs, Markdown/JSON reports | `~/Library/Application Support/macbook-setup` |
| Temporary staging | `~/Library/Caches/macbook-setup` |
| Runtime managers | `~/.nvm`, `~/.sdkman` |

Configured destinations must resolve inside your home, including symlink
ancestors. A user-owned executable link may refer to an existing system
application; setup never owns or removes its target.

Git uses a managed include; shell integration uses a marked `.zshrc` block.
Existing Git settings, shell configuration, Oh My Zsh theme/plugins, and AWS
credentials are preserved. Optional AWS defaults are shell environment values,
not edits to `~/.aws/config`. Ghostty uses the built-in Menlo font.
Open a new shell after installing dotfiles.
Python's versioned executables are added to PATH; use `uv run --python VERSION`
or a project virtual environment rather than replacing macOS's Python.

Desktop changes are journaled for restoration. Dock customization only appends
Chrome, never clears the layout. Wallpaper uses System Events rather than a
private database; macOS may require Automation approval or manual action.
Trackpad values can be checked automatically, but physical behavior requires
testing on the MacBook.

Docker uses the dedicated `macbook-setup` Colima profile with VM data under the
managed data directory. It does not change the global Docker context or SSH
configuration. Use `docker --context colima-macbook-setup ...`.
Login startup is opt-in through `COLIMA_START_AT_LOGIN=true` and a user
LaunchAgent. Stop this profile before updating container binaries; running
workloads are not interrupted automatically.

## Removal and recovery

```bash
./uninstall.sh --dry-run
./uninstall.sh --yes
```

Removal uses recorded ownership, not a hard-coded list of paths. Unchanged files
are removed or restored from their original backup; managed blocks are removed
without discarding unrelated edits. Changed files, changed app bundles, and
packages updated outside setup are retained with an incomplete-removal result.
Service/profile shutdown failures stop removal before dependencies are deleted.

Homebrew itself, Colima VM data, backups, and reports are intentionally retained.
Do not delete the ownership file to "reset" setup: doing so loses the ability to
distinguish managed resources from pre-existing ones.

A lock prevents simultaneous runs. After a crash, inspect `STATE_DIR/lock/pid`
and confirm that process is no longer the setup process before removing only
that lock's `pid` file and empty directory. Inspect partial destinations before
retrying: ambiguous interrupted writes are preserved rather than overwritten.
Failed DMG detaches retain staging and report its path; detach the reported
volume before cleaning that specific staging directory.

## Testing with UTM and locally

Use a clean ARM64 macOS UTM guest, a non-admin account, and a powered-off clean
clone. Avoid sharing the host home. Exercise dry-run, install, rerun, validation,
update, and removal inside the guest; compare pre-existing configurations before
and after. Skip Docker initially: macOS-guest nested virtualization is not a
dependable Colima test target. Check containers and physical trackpad behavior
on compatible hardware separately. See the [UTM macOS guest guide](https://docs.getutm.app/guest-support/macos/).

```bash
make test-deps  # Optional: prefetch test dependencies without running tests
make test       # Isolated HOME, mocked installers/platform; no real provisioning
make lint       # Requires ShellCheck; also checks Ruby and Bash syntax
make policy     # Focused user-only boundary checks
make upstream   # Opt-in real-network metadata checks, not full installations
```

Make downloads checksum-verified, pinned release archives of Bats and its
support/assertion helpers on demand into
`~/Library/Caches/macbook-setup/test-deps`. Subsequent runs reuse the cache without
downloading again. There are no Git submodules, full dependency clones, global
installs, or additional package managers. The unused `bats-file` dependency is
not downloaded. Test-tool pins do not change the stable/LTS provisioning policy.
An optional absolute `TEST_DEPS_DIR` override must still resolve inside your
home; for example, `TEST_DEPS_DIR="$HOME/.cache/macbook-setup/test-deps" make test`.
An incomplete cache or interrupted bootstrap is reported explicitly rather than
silently overwritten. Inspect the named directory or lock before removing it
and retrying. The test cache is separate from provisioning state and is not
needed by `setup.sh`.

CI runs lint and isolated lifecycle tests on Linux/macOS, enforces user-only
boundaries, and checks current upstream metadata weekly. Automated fixtures do
not replace a fresh-Mac/VM acceptance run.
