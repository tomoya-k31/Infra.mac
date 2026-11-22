# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Ansible automation for two independent targets:

- **Local Mac** (`localhost-mac.yml`): development environment (Homebrew packages, programming languages, development tools)
- **k3s server** (`k3s-mac-mini.yml`): a remote Mac mini 2018 running Ubuntu Server 26.04, managed over SSH

## Public Repository

This repository is public, and squash merges copy PR text permanently into git history. Keep confidential and personal information out of everything published: Ansible configuration, source code and comments, documentation, commit messages, branch names, and GitHub PRs, issues, reviews, and comments.

- Secrets (passwords, tokens, private keys, kubeconfig): store in 1Password and commit only `op://` references
- Personal information (real names, email addresses, employer or customer names, absolute home paths): omit, or use placeholders and `~`
- Identifying values (public IP and MAC addresses, key fingerprints, Claude session URLs): use placeholders such as `<server-ip>`, or read them from `ansible_facts`
- Accepted exceptions: the k3s server's private IP and host name, the login user that matches the GitHub handle, and 1Password vault and item names
- Before every commit, push, or GitHub post, review the full text, including pasted command output (`--diff`, `ssh -v`, logs). Report findings to the user by location, with the value masked

## Commands

```shell
# Local Mac: dry-run, then execute
ansible-playbook localhost-mac.yml --diff --check
ansible-playbook localhost-mac.yml

# k3s server: dry-run, then execute (may prompt for 1Password approval)
ansible-playbook -i inventory.yml k3s-mac-mini.yml --become-password-file scripts/become-password.sh --diff --check
ansible-playbook -i inventory.yml k3s-mac-mini.yml --become-password-file scripts/become-password.sh
```

`--check --diff` is the only validation (no lint, tests, or CI). On a fresh k3s server, its `ignored` tasks are expected.

The k3s server is live: dry-run first, and get the user's approval before executing or rebooting.

## Development Rules

Before every commit, stage the changes, run both `/code-review` and `/security-review`, and resolve their findings or get the user's decision on them. `/security-review` receives only committed changes, so point its review at `git diff --cached`.

## Prerequisites

- Homebrew must be installed first
- Ansible installed via `brew install ansible`
- k3s server: when SSH, sudo, or 1Password access fails, or the server is rebuilt, follow `docs/k3s-mac-mini-setup.md`

## Architecture

`localhost-mac.yml` orchestrates four task modules:

1. **tasks/homebrew.yml** - Homebrew formulae and casks
2. **tasks/langs.yml** - Language runtime installations (Rust, SDKMAN, pipx)
3. **tasks/tools.yml** - Additional tools (Krew, SOPS, hishtory, git-worktree-runner, Alacritty terminfo)
4. **tasks/macos_defaults.yml** - macOS system preferences via `defaults` (screenshot location)

`k3s-mac-mini.yml` imports `tasks/k3s/`:

1. **server.yml** - k3s installation and readiness check
2. **kubeconfig.yml** - kubeconfig on the server and `~/.kube/config-home` on the local Mac
3. **upgrade.yml**, **console.yml**, **kiosk.yml** - opt-in parts tagged `never`; add them with `--tags all,upgrade,console,kiosk`

Helper scripts live in `scripts/`.

## Key Patterns

- XDG Base Directory paths are used consistently (e.g., `$XDG_DATA_HOME/rustup`)
- Removing an entry from `tasks/homebrew.yml` does not uninstall the package
- `localhost-mac.yml` runs locally (`hosts: localhost`, `connection: local`) and needs no inventory

### k3s server

- `scripts/become-password.sh` must stay executable; otherwise Ansible uses its text as the password
- kubeconfig holds cluster-admin credentials: tasks that write it set `diff: false`, and tasks whose content passes through Ansible set `no_log: true`
- `k3s_version` and `k3s_installer_sha256` change together; so do `k9s_version` and `k9s_deb_sha256`
- Set `become: true` per task, so facts and `~` resolve to the login user
- Network configuration (netplan) is managed by hand, because Ansible depends on it to connect
- Reboots are manual: the cluster is a single node
