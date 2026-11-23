---
name: update-versions
description: Update a version pinned in this repository (k3s, k9s, SOPS, hishtory, git-worktree-runner, Ansible collections, gh-actions-lock, or GitHub Actions) together with its checksum or lockfile. Use when asked to bump, upgrade, or check for newer pinned versions.
---

# Update a pinned version

Change one component per branch. Read its release notes first and report breaking changes.

| Component | Where | Also update |
|---|---|---|
| k3s | `k3s_version` in `k3s-mac-mini.yml` | `k3s_installer_sha256` |
| k9s | `k9s_version` in `k3s-mac-mini.yml` | `k9s_deb_sha256` |
| SOPS, hishtory | `*_version` in `tasks/tools.yml` | `*_sha256`. hishtory is skipped on Macs that already have it, so tell the user |
| git-worktree-runner | commit in `tasks/tools.yml` | the tag in its comment |
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
- SOPS: `https://github.com/getsops/sops/releases/download/<version>/sops-<version>.darwin.arm64`
- hishtory: `https://github.com/ddworken/hishtory/releases/download/<version>/hishtory-darwin-arm64` (not the `-unsigned` asset)

## k3s

Do not skip a Kubernetes minor version. Applying the change restarts the live cluster, so dry-run it and get the user's approval before executing.

Finish with the `ansible-verify` skill.
