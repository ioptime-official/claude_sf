#!/usr/bin/env bash
# Stop hook: the agent may not declare "done" while verification fails.
# Bounded loop: after MAX failed attempts it stops blocking and tells a human to take over.
#
#   exit 2 + stderr  -> Claude is told to keep working (attempt N of MAX)
#   exit 0           -> allowed to stop (clean, passing, or escalated)
#
# Env: VERIFY_MAX_ATTEMPTS (default 3), VERIFY_CMD (default scripts/verify.sh --changed --no-salesforce
#      unless VERIFY_SALESFORCE=1), CLAUDE_PROJECT_DIR.
set -u
root="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$root" || exit 0
max="${VERIFY_MAX_ATTEMPTS:-3}"

input="$(cat)"
session="$(printf '%s' "$input" | python3 -c 'import sys,json
try: print(json.load(sys.stdin).get("session_id","default"))
except Exception: print("default")' 2>/dev/null)"
session="${session//[^A-Za-z0-9_-]/_}"

# Keep state OUTSIDE the work tree: a counter file inside the repo would itself look like a
# code change and keep the gate firing forever.
key="$(printf '%s' "$root" | cksum | awk '{print $1}')"
state_dir="${TMPDIR:-/tmp}/claude-verify-gate"
mkdir -p "$state_dir"
counter="$state_dir/attempts-$key-$session"

# Only gate when there are code changes (ignore docs, markdown and our own state).
dirty="$(git status --porcelain 2>/dev/null | awk '{print $NF}' | grep -Ev '(\.md$|^docs/)' | head -n1)"
if [ -z "$dirty" ]; then rm -f "$counter"; exit 0; fi

if [ -n "${VERIFY_CMD:-}" ]; then
  cmd="$VERIFY_CMD"
elif [ "${VERIFY_SALESFORCE:-0}" = "1" ]; then
  cmd="bash scripts/verify.sh --changed"
else
  cmd="bash scripts/verify.sh --changed --no-salesforce"
fi

out="$(bash -c "$cmd" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ]; then rm -f "$counter"; exit 0; fi

n=$(( $(cat "$counter" 2>/dev/null || echo 0) + 1 ))
echo "$n" > "$counter"

if [ "$n" -ge "$max" ]; then
  rm -f "$counter"
  msg="ESCALATE: verification still failing after $max attempts. Stopping the loop; a human should review."
  printf '{"systemMessage": %s}\n' "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$msg")"
  echo "$out" | tail -n 20 >&2
  exit 0
fi

{
  echo "Verification failed (attempt $n of $max). Fix the failures below, then finish again:"
  echo "$out" | tail -n 40
} >&2
exit 2
