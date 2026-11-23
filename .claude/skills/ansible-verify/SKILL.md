---
name: ansible-verify
description: Validate a change to this repository's playbooks, tasks, or workflows with lint, syntax checks, lockfile verification, and dry-runs. Use after editing any Ansible or workflow file and before committing.
---

# Validate a change

Run the steps in order and stop at the first failure. Report each command with its result, and say what was not run.

1. Lint, including syntax checks: `env -u ANSIBLE_HOME ansible-lint`
2. If `.github/workflows/` changed: `gh actions-lock --verify`
3. If `scripts/` changed: `shellcheck` on each changed `sh` or `bash` script
4. If `localhost-mac.yml` or `tasks/*.yml` changed: `ansible-playbook localhost-mac.yml --diff --check`
5. If `k3s-mac-mini.yml`, `inventory/`, or `tasks/k3s/` changed, ask the user first, because 1Password prompts for approval:
   `ansible-playbook -i inventory k3s-mac-mini.yml --become-password-file scripts/become-password.sh --diff --check`
   Add the opt-in parts that the change affects, or their tasks are skipped: `--tags all,kiosk` for `kiosk.yml` and `k9s_*`, `--tags all,console` for `console.yml` and `console_kernel_params`, `--tags all,upgrade` for `upgrade.yml`; combine them as `all,kiosk,console`. Expect `changed=0` unless the change is meant to alter the server; `upgrade` also reports pending apt packages.

Never drop `--check` here. A dry-run skips `command` and `shell` tasks, so list the changed ones as not exercised.
