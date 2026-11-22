# AGENTS.md

Rules for AI agents (Claude Code, GitHub Copilot) working in this repository. `CLAUDE.md` imports this file; put shared rules here.

## Overview

Ansible automation for two independent targets:

- **Local Mac** (`localhost-mac.yml`): development environment (Homebrew packages, programming languages, development tools)
- **k3s server** (`k3s-mac-mini.yml`): a remote Mac mini 2018 running Ubuntu Server 26.04, managed over SSH

## Repository Boundary

This repository owns the hosts. A separate private repository, `<k8s-manifests-repo>` (not created yet; replace the placeholder with its name), owns what runs inside the k3s cluster. What needs root on a host belongs here; what `kubectl` can apply belongs there.

- Here: the OS, the k3s binary, `/etc/rancher/k3s/` (`config.yaml`, `registries.yaml`), kernel parameters, storage mounts, kubeconfig retrieval, the k9s kiosk
- There: namespaces, RBAC, workloads, Ingress, Helm charts, `HelmChartConfig` for the components k3s ships, the GitOps controller, in-cluster secrets
- Do not add manifests here, neither in `/var/lib/rancher/k3s/server/manifests/` nor through `kubernetes.core.k8s`: deleting a file from that directory leaves its resources in the cluster, and nothing reconciles drift
- A change that spans both, such as `disable:` for a shipped component or a CNI replacement, starts here; its replacement goes in the other repository

## Public Repository

This repository is public, and squash merges copy PR text permanently into git history. Keep confidential and personal information out of everything published: Ansible configuration, source code and comments, documentation, commit messages, branch names, and GitHub PRs, issues, reviews, and comments.

- Secrets (passwords, tokens, private keys, kubeconfig): store in 1Password and commit only `op://` references
- Personal information (real names, email addresses, employer or customer names, absolute home paths): omit, or use placeholders and `~`
- Identifying values (public IP and MAC addresses, key fingerprints, Claude session URLs): use placeholders such as `<server-ip>`, or read them from `ansible_facts`
- Accepted exceptions: the k3s server's private IP and host name, the login user that matches the GitHub handle, 1Password vault and item names, and upstream attribution in imported third-party files
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

Validation is `ansible-lint` (local and CI) and `--check --diff`; there are no tests. In a dry-run, `ignored` tasks are expected on a fresh k3s server and for the SOPS copy when its binary is not in `/tmp`.

The k3s server is live: dry-run first, and get the user's approval before executing or rebooting.

This applies to every agent. `.claude/settings.json` enforces part of it for Claude Code only; with Copilot, never allow `ansible`, `ansible-playbook`, `ssh`, or `kubectl` without confirmation.

## Development Rules

Before every commit, run `env -u ANSIBLE_HOME ansible-lint` and fix every finding. When the fix would change behavior, suppress it with an inline `# noqa: <rule>`. The only global exception is `yaml[line-length]` in `.ansible-lint`, because a `noqa` inside the embedded systemd unit would be written to the server. When local and CI results differ, the version pinned in `ansible-lint.yml` decides.

Then stage the changes, have them reviewed for correctness and for security, and resolve the findings or get the user's decision on them. Work on a branch; `master` accepts only commits that passed the required checks.

Use the `ansible-verify` skill to validate a change and the `update-versions` skill to bump pinned versions.

After adding a workflow or changing any `uses:`, run `gh actions-lock --no-narrow` and commit `.github/workflows/actions.lock` with it. Without `--no-narrow` it rewrites the SHA pins to tags. Never edit the lockfile by hand. CI runs `gh actions-lock --verify`. If a Dependabot PR fails that check, run the same command on its branch.

## AI Content

Rules here override the imported content below. Do not edit imported files; change the pinned commit in `scripts/update-ai-content.sh`, run it, and review `git diff --cached` in full, including new files.

- ansible-community/ai-forge, installed with Lola (`pip install lola-ai==0.7.1`): the `write-*`, `ansible-zen`, and `ansible-markdown-docs` skills, and the `ansible-*` commands
- github/awesome-copilot: `.github/instructions/ansible.instructions.md`
- Claude Code and Copilot CLI both read `.claude/skills` and `.claude/commands`, so do not copy skills elsewhere
- `write-module`, `write-module-tests`, `write-content-tests`, `ansible-scaffold-collection`, and `ansible-collection-inclusion-review` come with the modules; do not invoke them unless the user asks: this repository has no custom modules, collections, or Molecule
- Ignore skills named in the imported content but absent here, such as `run-tests` and `changelog-fragment`
- Scaffolding must not overwrite `AGENTS.md` or `CLAUDE.md`, and new workflows must pin actions by SHA

Where this repository differs from the imported content:

- Secrets come from 1Password (`op://`), not Ansible Vault
- No `backup: true` on files that hold credentials; backups would keep old tokens on disk
- No staging inventory, Molecule, role README, or platform variable files; the hosts are listed under Overview
- `ignore_errors: "{{ ansible_check_mode }}"` is accepted for tasks that cannot work on a first dry-run
- Keep existing key order and quoting; do not reformat code that `ansible-lint` accepts
- Do not apply automatic fixes from a review to `tasks/k3s/`, `k3s-mac-mini.yml`, or `inventory.yml` without the user's approval
- For review rules, use `.claude/skills/write-content/reference.md` instead of fetching them from the web
- Install tools with Homebrew, mise, or `uv`, not `pip install` (Lola is the exception)
- `ansible-markdown-docs`: use `curl -sL --proto-redir '=https'` with the URL quoted, because docs.ansible.com redirects `/ansible/latest/`; check that the final URL is still on docs.ansible.com

## Prerequisites

- Homebrew must be installed first
- Ansible installed via `brew install ansible`
- `ansible-lint` installed via `brew install ansible-lint`
- For updating imported AI content: `pip install lola-ai==0.7.1`
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

Helper scripts live in `scripts/`. The target layout and its migration steps are in `docs/ansible-improvement-plan.md`; follow it when adding Macs or k3s nodes.

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
