@AGENTS.md

# Claude Code

The reviews required before every commit are `/code-review` and `/security-review`. `/security-review` receives only committed changes, so point its review at `git diff --cached`.

`.claude/settings.json` asks before the usual commands that reach the k3s server. It is not a boundary: the approval rule in `AGENTS.md` applies to every command, and wrapper scripts or other shells must not be used to avoid the prompt.
