---
name: update-versions
description: Update a version pinned in this repository (k3s, k9s, socket_vmnet, SOPS, hishtory, Ansible collections, gh-actions-lock, or GitHub Actions) together with its checksum or lockfile. Use when asked to bump, upgrade, or check for newer pinned versions.
---

# Update a pinned version

Change one component per branch. Read its release notes first and report breaking changes.

| Component | Where | Also update |
|---|---|---|
| k3s | `k3s_version` in `inventory/group_vars/k3s.yml` | `k3s_installer_sha256` |
| k9s | `k9s_version` in `inventory/host_vars/mac-mini-2018.yml` | `k9s_deb_sha256` |
| socket_vmnet | `socket_vmnet_version` in `inventory/group_vars/vm_hosts.yml` | `socket_vmnet_sha256` (the arm64 line of the release's `SHA256SUMS`) |
| SOPS, hishtory | `*_version` in `tasks/tools.yml` | `*_sha256`. hishtory is skipped on Macs that already have it, so tell the user |
| Ansible collections | `requirements.yml` | match the versions bundled with Homebrew's ansible |
| Lola | `lola_version` and the header of `scripts/update-ai-content.sh` | the versions in `AGENTS.md`; check that its hook and install behavior has not changed |
| gh-actions-lock | `verify-lockfile.yml` | the version in `AGENTS.md` |
| GitHub Actions | `uses:` in `.github/workflows/` | `gh actions-lock --no-narrow` |

## Checksums

Hash the same file the playbook downloads, and compare it with the release's published checksum when there is one. Download to a file first: piping a failed `curl` into `shasum` prints the hash of empty input.

```shell
curl -fsSL -o "$TMPDIR/pin" "<url>" && shasum -a 256 "$TMPDIR/pin"
```

- k3s: `https://raw.githubusercontent.com/k3s-io/k3s/<version, with + as %2B>/install.sh`
- k9s: `https://github.com/derailed/k9s/releases/download/<version>/k9s_linux_amd64.deb`
- socket_vmnet: `https://github.com/lima-vm/socket_vmnet/releases/download/<version>/socket_vmnet-<version without v>-arm64.tar.gz` (compare with the release's `SHA256SUMS`)
- SOPS: `https://github.com/getsops/sops/releases/download/<version>/sops-<version>.darwin.arm64`
- hishtory: `https://github.com/ddworken/hishtory/releases/download/<version>/hishtory-darwin-arm64` (not the `-unsigned` asset)

## k3s

Do not skip a Kubernetes minor version. Once an agent play exists (planned in `docs/ansible-improvement-plan.md`, stage 4), apply the change to the servers first, then to the agents: an agent must not run a newer version than the servers. Applying the change restarts the live cluster, so dry-run it and get the user's approval before executing.

Finish with the `ansible-verify` skill.
