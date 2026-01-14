#!/bin/bash
# Install git hooks for the grocery_planner project

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_DIR="$SCRIPT_DIR/git-hooks"
GIT_HOOKS_DIR="$SCRIPT_DIR/../.git/hooks"

echo "Installing git hooks..."

# Check if .git directory exists
if [ ! -d "$GIT_HOOKS_DIR" ]; then
  echo "Error: .git/hooks directory not found. Are you in the project root?"
  exit 1
fi

# Install pre-commit hook
if [ -f "$HOOKS_DIR/pre-commit" ]; then
  cp "$HOOKS_DIR/pre-commit" "$GIT_HOOKS_DIR/pre-commit"
  chmod +x "$GIT_HOOKS_DIR/pre-commit"
  echo "✓ Installed pre-commit hook"
else
  echo "✗ pre-commit hook not found in $HOOKS_DIR"
  exit 1
fi

echo ""
echo "Git hooks installed successfully!"
echo ""
echo "The pre-commit hook will run 'mix precommit' before each commit."
echo "To bypass the hook temporarily, use: git commit --no-verify"
