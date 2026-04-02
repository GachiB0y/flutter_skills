---
name: git-pr
description: Create a pull request following project conventions from .claude/git-flow.yaml. Formats PR title and body from templates, pushes branch, creates PR via gh CLI. Use when task is complete.
---

# Git PR — Create Pull Request

## When to Use

- When the current task is complete and ready for review
- When the agent suggests creating a PR after finishing all work
- When explicitly asked to create a PR

## Prerequisites

- `gh` CLI must be installed and authenticated
- All changes must be committed (or will be committed via /git-commit first)

## Flow

### Step 1: Read Config

Read `.claude/git-flow.yaml` and extract:
- `pr_target_branch` — target branch for PR
- `pr_title_template` — title format
- `pr_body_template` — body format
- `auto_push_before_pr` — whether to push automatically
- `ticket_pattern` — regex to extract ticket from branch name

### Step 2: Extract Ticket and Branch Info

Run `git branch --show-current` to get the current branch name.

Extract ticket number by matching `ticket_pattern` against branch name.

If on base branch (dev/master/main) → report error: "You're on {branch}, not a feature branch. Nothing to create PR for." Stop.

### Step 3: Check for Uncommitted Changes

Run `git status --short`.

If uncommitted changes exist:
- Report: "You have uncommitted changes. Commit first?"
- If yes → invoke `/git-commit` skill
- If no → stop

### Step 4: Push Branch

If `auto_push_before_pr: true`:
```bash
git push -u origin {current_branch}
```

If push fails → report error and suggest resolution. Stop.

If `auto_push_before_pr: false`:
- Check if remote tracking branch exists
- If not → ask: "Branch not pushed. Push to origin?"
- On confirmation → push

### Step 5: Analyze Branch History

Run: `git log {pr_target_branch}..HEAD --oneline`

Collect all commits on this branch to understand the full scope of work.

Also run: `git diff {pr_target_branch}...HEAD --stat` for file-level summary.

### Step 6: Generate PR Title

Parse `pr_title_template` and fill variables:

- `{ticket}` — extracted from branch name
- `{description}` — generate a concise summary of all changes (e.g. "Auth flow implementation")
- `{type}` — if template uses it: detect primary type from commits

### Step 7: Generate PR Body

Parse `pr_body_template` and fill variables:

- `{summary}` — 1-3 bullet points summarizing the work at a high level
- `{changes}` — list of key changes derived from commit history and diff:
  ```
  - Added AuthRepository with login/logout methods
  - Created AuthBloc with token management
  - Added login screen with form validation
  ```
- `{test_plan}` — checklist of testing steps:
  ```
  - [ ] Login with valid credentials
  - [ ] Login with invalid credentials shows error
  - [ ] Logout clears token
  - [ ] Unit tests pass (`make run_test`)
  ```

### Step 8: Show Preview and Confirm

Show full PR preview:

```
Title: #228: Auth flow implementation

Body:
## Summary
- Implemented complete authentication flow with login/logout
- Added token storage and automatic refresh

## Changes
- Added AuthRepository with login/logout methods
- Created AuthBloc with token management
- Added login screen with form validation

## Test plan
- [ ] Login with valid credentials
- [ ] Login with invalid credentials shows error
- [ ] Unit tests pass
```

Ask: "Create PR with this? (yes / edit / cancel)"

- **yes** → proceed to Step 9
- **edit** → ask what to change, regenerate
- **cancel** → stop

### Step 9: Create PR

```bash
gh pr create --base {pr_target_branch} --title "{title}" --body "$(cat <<'EOF'
{body}
EOF
)"
```

Report success: "PR created: {PR_URL}"

### Edge Cases

- **gh not installed** → report: "gh CLI not found. Install it: https://cli.github.com/"
- **gh not authenticated** → report: "Run `gh auth login` first"
- **PR already exists for this branch** → report existing PR URL and ask if user wants to update it
- **No commits on branch** → report: "No commits on this branch yet. Nothing to create PR for."
- **Target branch doesn't exist on remote** → report error and suggest correct target
