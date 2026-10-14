#!/usr/bin/env bash
# Local equivalent of .github/workflows/claude-change-request.yml.
# Usage: scripts/run-change-request.sh "<plain-English request>" [area]
#   area: react | dotnet | wordpress | salesforce   (hint only; default: react)
# Env:  DRY_RUN=1 prints the prompt and exits without calling Claude.
set -euo pipefail
cd "$(dirname "$0")/.."

request="${1:?usage: $0 \"<request text>\" [area]}"
area="${2:-react}"

[ -z "$(git status --porcelain)" ] || { echo "Working tree not clean; commit or stash first." >&2; exit 1; }
base="$(git rev-parse --abbrev-ref HEAD)"
slug="$(printf '%s' "$request" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | cut -c1-40 | sed 's/^-//;s/-$//')"
branch="ai/$slug"

prompt="Business request (area: $area): $request

Follow CLAUDE.md. Implement this on the current branch with matching tests, then run the checks for the stack you touched. Triage risk first: if it touches permissions, deletion, integrations or production data, stop and explain instead of implementing. Do not commit, push, merge or deploy. Finish with a short plain-language summary."

if [ "${DRY_RUN:-0}" = "1" ]; then
  echo "[dry run] branch: $branch (from $base)"; echo "$prompt"; exit 0
fi

command -v claude >/dev/null || { echo "claude CLI not found" >&2; exit 1; }
git checkout -q -b "$branch"
echo "==> Branch $branch. Asking Claude to implement..."

claude -p "$prompt" \
  --allowedTools "Read,Edit,Write,Grep,Glob,Bash(git status:*),Bash(git diff:*),Bash(npm install:*),Bash(npm test:*),Bash(npm run build:*),Bash(npx vitest:*),Bash(php:*),Bash(cd:*)" \
  --max-turns 30 --output-format text | tee .local-run-summary.txt

changed="$(git status --porcelain | awk '{print $2}')"
[ -n "$changed" ] || { echo "No changes were made."; git checkout -q "$base"; git branch -D "$branch" -q; rm -f .local-run-summary.txt; exit 0; }

echo "==> Independent verification (not trusting the agent's own report)"
bash scripts/verify.sh --changed --full || { echo "Verification failed; branch $branch left uncommitted for inspection." >&2; exit 1; }

echo "==> Read-only review by the code-reviewer subagent"
git add -A -- . ':!.local-run-summary.txt'
claude -p "Use the code-reviewer subagent on the staged changes (git diff --cached). Output a concise markdown review with an APPROVE or REQUEST CHANGES verdict." \
  --allowedTools "Read,Grep,Glob,Bash(git diff:*)" --max-turns 15 --output-format text | tee .local-review.md

git commit -q -m "feat: $request

Requested via local change-request flow.

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
rm -f .local-run-summary.txt
echo
echo "==> Done. Review the diff, then publish it yourself:"
echo "    git show --stat HEAD"
echo "    git push -u origin $branch   # then open a PR on GitHub"
