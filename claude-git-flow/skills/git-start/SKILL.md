---
name: git-start
description: Create a feature branch following project git-flow conventions. Use when starting a new task, before writing any code. Reads branch naming config from .claude/git-flow.yaml.
---

# Git Start — Create Feature Branch

## When to Use

- Before starting work on a new task
- When switching from one task to another
- When on base branch (dev/master/main) and about to write code

## Flow

### Step 1: Read Config

Read `.claude/git-flow.yaml` and extract:
- `base_branch` — branch to fork from
- `branch_template` — naming pattern
- `branch_types` — available branch types
- `ticket_pattern` — regex for ticket number validation

### Step 2: Check Current State

Run `git branch --show-current` to get the current branch.

**If on a feature branch (not base_branch, not master, not main):**
- Tell the user: "You're on branch `{current}`. Want to create a new branch for a different task?"
- If user says no → stop
- If user says yes → check for uncommitted changes:
  - If uncommitted changes exist → offer to commit via `/git-commit` skill first
  - After committing (or if clean) → switch to base_branch: `git checkout {base_branch}`

**If on base_branch / master / main:**
- Continue to Step 3

### Step 3: Update Base Branch

Run: `git pull origin {base_branch}`

If pull fails (conflicts, etc.) → report error and suggest manual resolution. Stop.

### Step 4: Ask for Ticket Number

Ask the user: "What's the ticket number? (expected format: `{ticket_pattern}`)"

If `.claude/git-flow.yaml` has `branch_example`, show it as the concrete shape the user's answer should produce. That field is the source of truth for ticket-prefix style in this project.

**Normalize the input before validation.** If the user types a value missing a literal prefix that the pattern requires (e.g. `3018` when the pattern is `#\d+`), prepend the missing prefix automatically and echo the result back to confirm. Users rarely type punctuation prefixes; silently dropping them and ending up with a branch that `git-commit` can't parse is the failure mode to avoid.

Validate the (normalized) answer against `ticket_pattern`.
- If still invalid → show expected format and `branch_example`, ask again
- If valid → continue

### Step 5: Generate Branch Name

Parse `branch_template` for required variables:

- `{ticket}` — use the ticket number from Step 4
- `{description}` — generate 2-3 word kebab-case description from conversation context. Show to user for confirmation.
- `{type}` — if template contains `{type}`:
  - Try to detect from conversation context (fix, feature, refactor)
  - If unclear, ask user. Default: first item in `branch_types`
- `{scope}` — if template contains `{scope}`:
  - Ask the user for scope (e.g. "payments", "auth", "core")

Assemble branch name from template by replacing variables.

### Step 6: Confirm and Create

Show: "Creating branch: `{assembled_branch_name}` from `{base_branch}`. OK?"

If `branch_example` is set in config, show it next to the assembled name so the user can sanity-check the shape matches the project convention.

On confirmation:
```bash
git checkout -b {assembled_branch_name}
```

Report success: "Branch `{assembled_branch_name}` created. Ready to work."

### Edge Cases

- **base_branch not found locally** → `git fetch origin {base_branch} && git checkout {base_branch}`
- **Branch name already exists** → report and ask user to pick a different description
- **Not a git repo** → report error and stop
