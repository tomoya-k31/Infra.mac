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
$ ansible-playbook localhost-mac.yml --diff --check

# Execute the playbook
$ ansible-playbook localhost-mac.yml
```

### Lint

```shell
$ env -u ANSIBLE_HOME ansible-lint
```

### k3s server (Mac mini 2018 / Ubuntu Server 26.04)

Complete the one-time setup (SSH key and sudo password in 1Password) first:
[docs/k3s-mac-mini-setup.md](docs/k3s-mac-mini-setup.md)

```shell
# Run a dry-run to see potential changes
$ ansible-playbook -i inventory.yml k3s-mac-mini.yml --become-password-file scripts/become-password.sh --diff --check

# Install/upgrade/configure k3s (restarts it when the version or config changes) and write ~/.kube/config-home on the local Mac
$ ansible-playbook -i inventory.yml k3s-mac-mini.yml --become-password-file scripts/become-password.sh

# Also run the opt-in parts
#   upgrade: apt upgrade (never reboots)
#   console: kernel parameters (applied on next reboot) and console log level for the attached display
#   kiosk:   show k9s on tty1 as an unprivileged user with read-only access (log in with Ctrl+Alt+F2); use with console
$ ansible-playbook -i inventory.yml k3s-mac-mini.yml --become-password-file scripts/become-password.sh --tags all,upgrade,console,kiosk

# Reboot the server
$ ansible k3s -i inventory.yml -b --become-password-file scripts/become-password.sh -m reboot

# Use the cluster from the local Mac
$ KUBECONFIG=~/.kube/config-home kubectl get nodes
```

## Directory Structure

```
.
├── .ansible-lint           # ansible-lint settings
├── .github/workflows/      # CI (ansible-lint, lockfile verification) and actions.lock
├── AGENTS.md               # Rules for AI agents (CLAUDE.md imports it)
├── .claude/                # Skills, commands, and permissions for AI agents
├── .github/instructions/   # Ansible instructions for Copilot
├── .gitignore
├── localhost-mac.yml       # Main Ansible playbook (local Mac)
├── k3s-mac-mini.yml        # Ansible playbook for the k3s server
├── inventory.yml           # Inventory for the k3s server
├── requirements.yml        # Collections ansible-lint needs
├── README.md               # This documentation file
├── docs/
│   ├── ansible-improvement-plan.md  # Target layout and migration steps
│   └── k3s-mac-mini-setup.md  # One-time setup before running k3s-mac-mini.yml
├── scripts/
│   ├── become-password.sh  # Reads the k3s server's sudo password from 1Password
│   ├── install_krew.sh     # Script to install Krew (kubectl plugin manager)
│   └── update-ai-content.sh  # Imports third-party AI content at pinned commits
├── third_party/            # Licenses of the imported AI content
└── tasks/
    ├── homebrew.yml        # Tasks for Homebrew (tap, install packages)
    ├── tools.yml           # Tasks for other tools (Krew, SOPS)
    ├── langs.yml           # Tasks for language tools (Rust, SDKMAN, Rye)
    └── k3s/                # Tasks for the k3s server
```

The repository is organized as follows:

- **localhost-mac.yml**: The main Ansible playbook that orchestrates the setup process.
- **tasks/**: Directory containing modular Ansible task files:
  - **homebrew.yml**: Manages Homebrew taps and package installations.
  - **tools.yml**: Installs various development and operational tools.
  - **langs.yml**: Sets up programming language environments and tools.
- **scripts/**: Contains helper scripts used during the setup process.
