---
description: Add a new Homebrew package to tasks/homebrew.yml
argument-hint: "[package-name]"
---

Add the Homebrew package "$ARGUMENTS" to `tasks/homebrew.yml`.

1. Create a branch from an up-to-date `master`.
2. Run `brew info` to confirm the exact name and whether it is a formula or a cask.
3. Add a formula to the matching section of `Install homebrew packages`, with an aligned English comment. Add a cask to `Install homebrew cask applications`. Skip it if it is already listed.
4. Validate with the `ansible-verify` skill.
5. Follow the Development Rules in `AGENTS.md` before committing. Push and create a PR only when the user asks.
