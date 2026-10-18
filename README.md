# Personalized macOS Setup Automation

A complete, production-quality repository that automates the setup, configuration, and customization of an Apple Silicon MacBook exclusively for the current user.

## Design Philosophy

- **Zero Privilege Escalation:** No `sudo`, root access, or administrator passwords are required.
- **Idempotent Execution:** Safe to run repeatedly. Existing configurations and applications are detected and preserved.
- **User-Level Only:** Applications are installed into `~/Applications`, binaries to `~/.local/bin`.
- **No Intrusive Prompts:** Modifies settings transparently using safe lower-level APIs (e.g. SQLite for desktop pictures) instead of AppleScript prompts.
- **Dry-Run Supported:** Verify what will change before it happens.

## Repository Architecture

```text
macbook-setup/
├── README.md
├── Makefile               # Test and lint commands
├── setup.sh               # Main entrypoint
├── uninstall.sh           # Safe teardown of installed artifacts
├── config/                # User configuration overrides
├── scripts/               # Core logic and installation modules
│   ├── install/           # Individual application setup scripts
│   ├── customize/         # macOS preferences (Dock, Wallpaper, Trackpad)
│   ├── utils/             # Shared utilities (Logging, Backup, Report)
│   └── common.sh          # Global variables and initialization
├── dotfiles/              # Placeholder for Zsh and Git configurations
└── tests/                 # Bats-core test suite
```

## Supported Applications & Tools

* **CLI & Runtimes:** Git, Node.js (via NVM), Python (via uv), Java (via SDKMAN!), Docker & Colima, GitHub CLI, AWS CLI.
* **Development GUI:** IntelliJ IDEA, Visual Studio Code, DBeaver Community.
* **Browsers & Tools:** Google Chrome, DuckDuckGo (Mac Browser), Maccy, Ghostty, btop, Gradle, Oh My Zsh.

## Pre-requisites

- An Apple Silicon (ARM64) MacBook.
- Supported version of macOS.
- Active internet connection.

## Usage

1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-username/macbook-setup.git
   cd macbook-setup
   ```

2. **Configure your preferences:**
   ```bash
   cp config/user.example.env config/user.env
   nano config/user.env
   ```

3. **Preview the execution (Dry-Run):**
   ```bash
   ./setup.sh --dry-run
   ```

4. **Execute the setup:**
   ```bash
   ./setup.sh
   ```

### Command Line Options

- `--dry-run`: Show what would be installed/configured without making changes.
- `--only <csv>`: Run only specific components (e.g., `--only git,node,docker`).
- `--skip <csv>`: Skip specific components (e.g., `--skip macos-customization`).
- `--validate`: Verify that expected applications and binaries are present in your paths.

## Desktop Setup Report

Instead of fragile macOS desktop aliases, the setup will generate a `Setup_Report.md` on your Desktop detailing:
- What was installed.
- The current installed version.
- The latest available version at the time of execution.
- Command-line instructions or notes on how to update each tool later.

## Testing and Development

We use `bats-core` for unit testing and validation, and `shellcheck` for static analysis.
To run tests locally:
```bash
make test
make lint
```

## Security

- Do **not** commit `user.env` to version control.
- GitHub Actions CI/CD runs on every PR to ensure scripts remain idempotent and free of `sudo`.
