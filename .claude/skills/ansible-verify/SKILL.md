---
name: ansible-verify
description: Validate a change to this repository's playbooks, tasks, or workflows with lint, syntax checks, lockfile verification, and dry-runs. Use after editing any Ansible or workflow file and before committing.
---

# Validate a change

Run the steps in order and stop at the first failure. Report each command with its result, and say what was not run.

1. Lint, including syntax checks: `env -u ANSIBLE_HOME ansible-lint`
2. If `.github/workflows/` changed: `gh actions-lock --verify`
3. If `scripts/` changed: `shellcheck` on each changed `sh` or `bash` script
4. If `localhost-mac.yml`, `tasks/*.yml`, or `vars/mac/` changed: `ansible-playbook localhost-mac.yml -e mac_profile=<profile> --diff --check` for each profile the change touches (`personal` when only `common.yml` changed)
5. If `k3s-mac-mini.yml`, the `k3s` part of `inventory/` (the `k3s` group in `hosts.yml`, `group_vars/k3s*.yml`, and `host_vars/` of hosts in the `k3s` group), or `tasks/k3s/` changed, ask the user first, because 1Password prompts for approval:
   `ansible-playbook -i inventory k3s-mac-mini.yml --become-password-file scripts/become-password.sh --diff --check`
   Add the opt-in parts that the change affects, or their tasks are skipped: `--tags all,kiosk` for `kiosk.yml` and `k9s_*`, `--tags all,console` for `console.yml` and `console_kernel_params`, `--tags all,upgrade` for `upgrade.yml`, `--tags backup` for `backup.yml` (a dry-run skips every task, so it touches nothing and writes no backup); combine them as `all,kiosk,console`. Expect `changed=0` unless the change is meant to alter the server; `upgrade` also reports pending apt packages.

6. If `k3s-vm-host.yml`, `tasks/vm_host/`, or the `vm_hosts` part of `inventory/` (the `vm_hosts` group in `hosts.yml`, `group_vars/vm_hosts.yml`, and `host_vars/` of hosts in the `vm_hosts` group) changed, ask the user first, because 1Password prompts for approval, then run `ansible-playbook -i inventory k3s-vm-host.yml --become-password-file scripts/vm-host-become-password.sh --diff --check`.

   A change to `hosts.yml` outside both groups, or to `group_vars/all*`, runs both steps 5 and 6.

Never drop `--check` here. A dry-run skips `command` and `shell` tasks, so list the changed ones as not exercised.
