# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is an Ansible-based macOS infrastructure automation repository. It automates the setup of development environments including Homebrew packages, programming languages, and development tools.

## Commands

```shell
# Dry-run to preview changes
ansible-playbook localhost-mac.yml --diff --check

# Execute the playbook
ansible-playbook localhost-mac.yml
```

## Prerequisites

- Homebrew must be installed first
- Ansible installed via `brew install ansible`

## Architecture

The main playbook (`localhost-mac.yml`) orchestrates three task modules:

1. **tasks/homebrew.yml** - Homebrew taps, formulae, and casks
2. **tasks/langs.yml** - Language runtime installations (Rust, SDKMAN, pipx)
3. **tasks/tools.yml** - Additional tools (Krew, SOPS, hishtory, git-worktree-runner, serena)

Helper scripts live in `scripts/`.

## Key Patterns

- XDG Base Directory paths are used consistently (e.g., `$XDG_DATA_HOME/rustup`)
- tmux is installed from HEAD due to a bug in the stable release
- The playbook runs locally (`hosts: localhost`, `connection: local`)
