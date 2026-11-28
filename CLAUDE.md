@AGENTS.md

# Claude Code

The reviews required before every commit are `/code-review` and `/security-review`. `/security-review` receives only committed changes, so point its review at `git diff --cached`.

`.claude/settings.json` asks before the usual commands that reach the k3s server. It is not a boundary: the approval rule in `AGENTS.md` applies to every command, and wrapper scripts or other shells must not be used to avoid the prompt.

## Language
Respond to the user in Japanese, including summaries, reports and routine output. Code, commit messages and identifiers may stay in English unless a repo convention says otherwise.

## Verify before reporting
- Never state system state (timezone, service status, message delivery, counts) without checking it first with a command.
- After a change that affects running processes (timezone, config, permissions), check whether a restart is needed and confirm the visible result.
- When reporting 'added N items', the count must match the items actually confirmed by reading them back.
- A cross-session message is 'delivered' only when it was not held for approval.

After making the change, don't tell me it's done until you've shown me command output that proves the final state on every affected host (including running processes that may need a restart), and listed anything you could not verify.
