---
description: Add a new Homebrew package to vars/mac/
argument-hint: "[package-name]"
---

Add the Homebrew package "$ARGUMENTS" to `vars/mac/common.yml`, or to `vars/mac/<profile>.yml` when only one Mac needs it (ask the user if unclear).

1. Create a branch from an up-to-date `master`.
2. Run `brew info` to confirm the exact name and whether it is a formula or a cask.
3. In `common.yml`, add a formula to the matching section of `mac_brew_formulae`, with an aligned English comment, and a cask to `mac_brew_casks`. In a profile, use `mac_profile_brew_formulae` and `mac_profile_brew_casks`. Skip it if it is already listed in either file.
4. Validate with the `ansible-verify` skill.
5. Follow the Development Rules in `AGENTS.md` before committing. Push and create a PR only when the user asks.
