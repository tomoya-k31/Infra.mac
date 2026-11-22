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

## Usage

### Local Mac

```shell
# Run a dry-run to see potential changes
$ ansible-playbook localhost-mac.yml --diff --check

# Execute the playbook
$ ansible-playbook localhost-mac.yml
```

### k3s server (Mac mini 2018 / Ubuntu Server 26.04)

Complete the one-time setup (SSH key and sudo password in 1Password) first:
[docs/k3s-mac-mini-setup.md](docs/k3s-mac-mini-setup.md)

```shell
# Run a dry-run to see potential changes
$ ansible-playbook -i inventory.yml k3s-mac-mini.yml --become-password-file scripts/become-password.sh --diff --check

# Install/upgrade k3s and write ~/.kube/config-home on the local Mac
$ ansible-playbook -i inventory.yml k3s-mac-mini.yml --become-password-file scripts/become-password.sh

# Also run the opt-in parts
#   upgrade: apt upgrade (never reboots)
#   console: kernel parameters for the attached display (applied on next reboot)
#   kiosk:   autologin on tty1 and show k9s (anyone at the machine gets a logged-in shell)
$ ansible-playbook -i inventory.yml k3s-mac-mini.yml --become-password-file scripts/become-password.sh --tags all,upgrade,console,kiosk

# Reboot the server
$ ansible k3s -i inventory.yml -b --become-password-file scripts/become-password.sh -m reboot

# Use the cluster from the local Mac
$ KUBECONFIG=~/.kube/config-home kubectl get nodes
```

## Directory Structure

```
.
├── .gitignore
├── localhost-mac.yml       # Main Ansible playbook (local Mac)
├── k3s-mac-mini.yml        # Ansible playbook for the k3s server
├── inventory.yml           # Inventory for the k3s server
├── README.md               # This documentation file
├── docs/
│   └── k3s-mac-mini-setup.md  # One-time setup before running k3s-mac-mini.yml
├── scripts/
│   ├── become-password.sh  # Reads the k3s server's sudo password from 1Password
│   └── install_krew.sh     # Script to install Krew (kubectl plugin manager)
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
