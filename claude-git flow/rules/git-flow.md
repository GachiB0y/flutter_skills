# Git Flow Rules

> Applied to all coding tasks in the project

## Config

Git flow configuration is in `.claude/git-flow.yaml`. Read it before any git operations.

## Rules

### Before Starting a New Task
1. Check current branch. If on base branch (from config `base_branch`) — call `/git-start` skill to create a feature branch
2. If already on a feature branch from a different task — offer to commit/push current work via `/git-commit`, then call `/git-start` for the new task
3. Never write code directly on the base branch (dev/master/main)

### During Work
4. If `suggest_commit_after_logical_chunk: true` in config — propose a commit after completing a logical piece of work (class, module, test file)
5. Use `/git-commit` skill for all commits — it formats messages according to project conventions from `git-flow.yaml`
6. Extract ticket number from the current branch name for commit messages

### On Task Completion
7. If `suggest_pr_on_task_complete: true` in config — propose creating a PR when the task is done
8. Use `/git-pr` skill for PR creation — it formats title and body according to project conventions from `git-flow.yaml`

### Commit Guidelines
9. Always show the commit message to the user for confirmation before committing
10. Stage only relevant files — never use `git add -A` or `git add .`
11. Do not commit sensitive files (.env, credentials, etc.)

### PR Guidelines
12. Always show PR title and body preview before creating
13. Push the branch before creating PR if `auto_push_before_pr: true` in config

### Integration with Superpowers Execution
14. Call `/git-start` BEFORE invoking writing-plans or executing-plans skills
15. Call `/git-commit` AFTER each completed plan step (when subagent finishes a step)
16. Call `/git-pr` AFTER all plan steps are completed and verified
17. Subagents (implementers) do NOT perform git operations — only the main orchestrator agent handles branching, commits, and PRs
