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

```shell
# Run a dry-run to see potential changes
$ ansible-playbook localhost-mac.yml --diff --check

# Execute the playbook
$ ansible-playbook localhost-mac.yml
```

## Directory Structure

```
.
├── .gitignore
├── localhost-mac.yml       # Main Ansible playbook
├── README.md               # This documentation file
├── scripts/
│   └── install_krew.sh     # Script to install Krew (kubectl plugin manager)
└── tasks/
    ├── homebrew.yml        # Tasks for Homebrew (tap, install packages)
    ├── tools.yml           # Tasks for other tools (Krew, SOPS)
    └── langs.yml           # Tasks for language tools (Rust, SDKMAN, Rye)
```

The repository is organized as follows:

- **localhost-mac.yml**: The main Ansible playbook that orchestrates the setup process.
- **tasks/**: Directory containing modular Ansible task files:
  - **homebrew.yml**: Manages Homebrew taps and package installations.
  - **tools.yml**: Installs various development and operational tools.
  - **langs.yml**: Sets up programming language environments and tools.
- **scripts/**: Contains helper scripts used during the setup process.
