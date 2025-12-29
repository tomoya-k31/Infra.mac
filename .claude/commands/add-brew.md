---
description: Add a new Homebrew package to tasks/homebrew.yml
allowed-tools:
  - Read
  - Edit
  - Bash(git:*)
  - Bash(gh:*)
---

Use the add-homebrew-tool skill to add "$ARGUMENTS" to tasks/homebrew.yml.

After adding the package:
1. Create a git commit with a descriptive message
2. Create a new branch if on master
3. Push the branch and create a PR
4. Enable auto-merge on the PR
