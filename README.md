# Infra.mac

A repository for managing macOS infrastructure using Ansible.

## Prerequisites

- Install Homebrew
  ```shell
  $ /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  ```

- Install Ansible
  ```shell
  $ brew install ansible
  ```

- Install ansible-lint (also installed by `localhost-mac.yml`)
  ```shell
  $ brew install ansible-lint
  ```

## Usage

### Local Mac

```shell
# Run a dry-run to see potential changes
$ ansible-playbook localhost-mac.yml -e mac_profile=personal --diff --check

# Execute the playbook
$ ansible-playbook localhost-mac.yml -e mac_profile=personal
```

Every Mac gets the Homebrew packages in `vars/mac/common.yml` plus those in `vars/mac/<profile>.yml`. The playbook fails without a profile. To add a Mac, add a profile file with `mac_profile_brew_formulae` and `mac_profile_brew_casks`. Removing a package from a list does not uninstall it.

`localhost-mac.yml` does not edit shell configuration, so a new Mac needs these lines in `~/.zshrc` (or `$ZDOTDIR/.zshrc`); only zsh is covered. Put them after `compinit` and other Ctrl+R integrations, and before tool activation such as mise. Until they are added, hishtory records nothing and `sdk` is not found.

```shell
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export CARGO_HOME="$XDG_DATA_HOME/cargo" RUSTUP_HOME="$XDG_DATA_HOME/rustup"
export KREW_ROOT="$XDG_DATA_HOME/krew"
typeset -U path PATH
export PATH="$HOME/.local/bin:$CARGO_HOME/bin:$KREW_ROOT/bin:$PATH:$HOME/.hishtory"
[[ -s "$HOME/.hishtory/config.zsh" ]] && source "$HOME/.hishtory/config.zsh"
# Keep SDKMAN last
export SDKMAN_DIR="$XDG_DATA_HOME/sdkman"
[[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]] && source "$SDKMAN_DIR/bin/sdkman-init.sh"
```

### Lint

```shell
$ env -u ANSIBLE_HOME ansible-lint
```

### k3s server and agent (Mac mini 2018 / Ubuntu Server 26.04, and the VM on the M4)

Complete the one-time setup (SSH key and sudo password in 1Password) first:
[docs/k3s-mac-mini-setup.md](docs/k3s-mac-mini-setup.md)

```shell
# Run a dry-run to see potential changes
$ ansible-playbook -i inventory k3s-mac-mini.yml --become-password-file scripts/become-password.sh --diff --check

# Install/upgrade/configure k3s (restarts it when the version or config changes) and write ~/.kube/config-home on the local Mac
$ ansible-playbook -i inventory k3s-mac-mini.yml --become-password-file scripts/become-password.sh

# Also run the opt-in parts
#   upgrade: apt upgrade (never reboots)
#   console: kernel parameters (applied on next reboot) and console log level for the attached display
#   kiosk:   show k9s on tty1 as an unprivileged user with read-only access (log in with Ctrl+Alt+F2); use with console
$ ansible-playbook -i inventory k3s-mac-mini.yml --become-password-file scripts/become-password.sh --tags all,upgrade,console,kiosk

# Back up the datastore and the server token, encrypted with age on the local Mac
# (take one before upgrading k3s or adding a node; see docs/k3s-backup-restore.md)
$ ansible-playbook -i inventory k3s-mac-mini.yml --become-password-file scripts/become-password.sh --tags backup

# Update only the server (agents follow in a later run)
$ ansible-playbook -i inventory k3s-mac-mini.yml --become-password-file scripts/become-password.sh --limit k3s_server

# Reboot the server (one host at a time)
$ ansible mac-mini-2018 -i inventory -b --become-password-file scripts/become-password.sh -m reboot

# Use the cluster from the local Mac
$ KUBECONFIG=~/.kube/config-home kubectl get nodes
```

### VM host for the k3s agent (M4 Mac mini / macOS)

Complete the one-time setup (SSH key and sudo password in 1Password) first:
[docs/k3s-vm-host-setup.md](docs/k3s-vm-host-setup.md)

```shell
# Dry-run, then keep the Mac awake, restart it after a power failure,
# and run the k3s agent VM (Lima, bridged to the LAN at a fixed IP, started at boot)
$ ansible-playbook -i inventory k3s-vm-host.yml --become-password-file scripts/vm-host-become-password.sh --diff --check
$ ansible-playbook -i inventory k3s-vm-host.yml --become-password-file scripts/vm-host-become-password.sh
```

## Directory Structure

```
.
├── .ansible-lint           # ansible-lint settings
├── .claude/                # Skills, commands, and permissions for AI agents
├── .github/
│   ├── dependabot.yml      # Weekly GitHub Actions updates
│   ├── instructions/       # Ansible instructions for Copilot
│   └── workflows/          # CI (ansible-lint, lockfile verification) and actions.lock
├── AGENTS.md               # Rules for AI agents (CLAUDE.md imports it)
├── renovate.json           # Weekly PRs for pinned tool versions (checksums are updated by hand)
├── .gitignore
├── localhost-mac.yml       # Main Ansible playbook (local Mac)
├── k3s-mac-mini.yml        # Ansible playbook for the k3s server
├── k3s-vm-host.yml         # Ansible playbook for the macOS host of the k3s VM
├── vars/mac/               # Homebrew packages: common.yml for every Mac, <profile>.yml per Mac
├── inventory/              # Inventory for the k3s nodes and the VM host (hosts.yml, group_vars, host_vars)
├── requirements.yml        # Collections ansible-lint needs
├── README.md               # This documentation file
├── docs/
│   ├── ansible-improvement-plan.md  # Target layout and migration steps
│   ├── k3s-backup-restore.md  # Backing up and restoring the k3s datastore
│   ├── k3s-mac-mini-setup.md  # One-time setup before running k3s-mac-mini.yml
│   └── k3s-vm-host-setup.md   # One-time setup before running k3s-vm-host.yml
├── scripts/
│   ├── become-password.sh  # Reads the k3s server's sudo password from 1Password
│   ├── vm-host-become-password.sh  # Reads the VM host's sudo password from 1Password
│   └── update-ai-content.sh  # Imports third-party AI content at pinned commits (needs Lola)
├── third_party/            # Licenses of the imported AI content
└── tasks/
    ├── homebrew.yml        # Tasks for Homebrew formulae and casks (lists in vars/mac/)
    ├── tools.yml           # Tasks for other tools (Krew plugins, SOPS, hishtory, Alacritty terminfo)
    ├── langs.yml           # Tasks for language tools (Rust, SDKMAN)
    ├── macos_defaults.yml  # Tasks for macOS system preferences
    ├── k3s/                # Tasks for the k3s server
    └── vm_host/            # Tasks for the macOS host of the k3s VM
```

The repository is organized as follows:

- **localhost-mac.yml**: The main Ansible playbook that orchestrates the setup process.
- **tasks/**: Directory containing modular Ansible task files:
  - **homebrew.yml**: Manages Homebrew formulae and casks.
  - **tools.yml**: Installs various development and operational tools.
  - **langs.yml**: Sets up programming language environments and tools.
- **scripts/**: Contains helper scripts used during the setup process.
