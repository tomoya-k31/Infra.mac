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

```shell
# Lint (installs the collections in requirements.yml into .ansible/).
# With ANSIBLE_HOME set, they would go to the user collection path and shadow the ones ansible-playbook uses.
env -u ANSIBLE_HOME ansible-lint
```

Validation is `ansible-lint` (local and CI) and `--check --diff`; there are no tests. On a fresh k3s server, the `ignored` tasks in the dry-run are expected.

The k3s server is live: dry-run first, and get the user's approval before executing or rebooting.

## Development Rules

Before every commit, run `env -u ANSIBLE_HOME ansible-lint` and fix every finding. When the fix would change behavior, suppress it with an inline `# noqa: <rule>`. The only global exception is `yaml[line-length]` in `.ansible-lint`, because a `noqa` inside the embedded systemd unit would be written to the server. When local and CI results differ, the version pinned in `ansible-lint.yml` decides.

Then stage the changes, run both `/code-review` and `/security-review`, and resolve their findings or get the user's decision on them. `/security-review` receives only committed changes, so point its review at `git diff --cached`.

After adding a workflow or changing any `uses:`, run `gh actions-lock --no-narrow` and commit `.github/workflows/actions.lock` with it. Without `--no-narrow` it rewrites the SHA pins to tags. Never edit the lockfile by hand. CI runs `gh actions-lock --verify`.

## Prerequisites

- Homebrew must be installed first
- Ansible installed via `brew install ansible`
- `ansible-lint` installed via `brew install ansible-lint`
- For workflow changes: `gh extension install github/gh-actions-lock --pin v0.5.1` (same version as `verify-lockfile.yml`)
- k3s server: when SSH, sudo, or 1Password access fails, or the server is rebuilt, follow `docs/k3s-mac-mini-setup.md`

## Architecture

`localhost-mac.yml` orchestrates four task modules:

1. **tasks/homebrew.yml** - Homebrew formulae and casks
2. **tasks/langs.yml** - Language runtime installations (Rust, SDKMAN, pipx)
3. **tasks/tools.yml** - Additional tools (Krew, SOPS, hishtory, git-worktree-runner, Alacritty terminfo)
4. **tasks/macos_defaults.yml** - macOS system preferences via `defaults` (screenshot location)

`k3s-mac-mini.yml` imports `tasks/k3s/`:

1. **server.yml** - k3s installation, config, and readiness check; restarts the live cluster when the version, flannel backend, or node IP changes
2. **kubeconfig.yml** - admin kubeconfig at `~/.kube/config-home` on the local Mac only; on the server use `sudo k3s kubectl`
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
- `k3s_flannel_backend` is `host-gw`: every node must be on the same L2 network, and every server must use the same value
- `node-ip` is pinned to the host's IPv4 address: k3s exits when an auto-detected node IP changes, such as when IPv6 appears after boot
- Reboots are manual: the cluster is a single node
