---
name: git-commit
description: Commit changes following project conventions from .claude/git-flow.yaml. Formats commit message with ticket number, type, and description. Use for all commits in the project.
---

# Git Commit — Commit by Convention

## When to Use

- When you or the agent want to commit changes
- When the agent suggests a commit after a logical chunk of work
- After completing a plan step (superpowers integration)

## Flow

### Step 1: Read Config

Read `.claude/git-flow.yaml` and extract:
- `commit_template` — message format
- `commit_types` — available types (if template uses `{type}`)
- `commit_body` — whether to add body description
- `ticket_pattern` — regex to extract ticket from branch name

### Step 2: Extract Ticket from Branch

Run `git branch --show-current` to get the current branch name.

Extract ticket number by matching `ticket_pattern` regex against the branch name.

If no ticket found → ask the user for the ticket number.

### Step 3: Check Changes

Run `git status --short` to see what changed.

**If no changes:**
- Report: "Nothing to commit — working tree is clean."
- Stop.

**If only unstaged changes:**
- Show the list of changed files
- Ask: "Which files should I stage?" or suggest relevant files based on the current task context
- Stage selected files with `git add {files}`

**If staged changes exist:**
- Continue with staged changes

### Step 4: Analyze Changes

Run `git diff --staged` to see what will be committed.

Summarize the changes to understand what was done.

### Step 5: Generate Commit Message

Parse `commit_template` and fill variables:

- `{ticket}` — extracted from branch name in Step 2
- `{message}` — generate a short (3-8 words) imperative description of changes (e.g. "create auth repository", "fix login validation")
- `{type}` — if template uses it: detect from changes:
  - New files/features → `feat`
  - Bug fixes → `fix`
  - Code restructuring → `refactor`
  - Documentation → `docs`
  - Tests → `test`
  - Build/config → `chore`
- `{scope}` — if template uses it: detect from changed file paths (feature name, module name)

**If `commit_body: true`:**
Generate 2-4 bullet points describing key changes:
```
- Added AuthRepository interface in domain layer
- Implemented AuthRepositoryImpl with Dio client
- Registered repository in DI container
```

### Step 6: Show and Confirm

Show the full commit message:

```
{formatted title}

{formatted body if commit_body: true}
```

Example:
```
#228: create auth repository

- Added AuthRepository interface in domain layer
- Implemented AuthRepositoryImpl with Dio client
```

Ask: "Commit with this message? (yes / edit / cancel)"

- **yes** → proceed to Step 7
- **edit** → ask what to change, regenerate
- **cancel** → stop

### Step 7: Commit

```bash
git add {relevant files}
git commit -m "{title}" -m "{body}"
```

Use HEREDOC for multi-line messages:
```bash
git commit -m "$(cat <<'EOF'
{title}

{body}
EOF
)"
```

Report success: "Committed: `{title}`"

### Edge Cases

- **On base branch (dev/master/main)** → warn: "You're on {branch}. Consider creating a feature branch first with /git-start"
- **Merge conflicts in staged files** → report and suggest resolution
- **Empty commit message** → regenerate, never commit with empty message
