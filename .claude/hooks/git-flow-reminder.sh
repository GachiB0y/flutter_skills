#!/bin/bash
# Git Flow Reminder — SessionStart hook
# Shows a reminder if the user is on a base branch (dev/master/main)

CONFIG_FILE=".claude/git-flow.yaml"

# Read base_branch from config, default to "dev"
if [ -f "$CONFIG_FILE" ]; then
  BASE_BRANCH=$(grep '^base_branch:' "$CONFIG_FILE" | head -1 | sed 's/base_branch:[[:space:]]*//')
else
  BASE_BRANCH="dev"
fi

CURRENT_BRANCH=$(git branch --show-current 2>/dev/null)

# Exit silently if not in a git repo
if [ -z "$CURRENT_BRANCH" ]; then
  exit 0
fi

# Check if on base branch, master, or main
if [ "$CURRENT_BRANCH" = "$BASE_BRANCH" ] || [ "$CURRENT_BRANCH" = "master" ] || [ "$CURRENT_BRANCH" = "main" ]; then
  echo "You are on branch '$CURRENT_BRANCH'. If starting a new task, tell the task number or use /git-start"
fi
