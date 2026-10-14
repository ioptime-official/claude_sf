#!/usr/bin/env bash
# Behavioural tests for the bounded Stop-hook verification loop, run in a throwaway git repo.
cd "$(dirname "$0")/../.." || exit 1
hook="$PWD/.claude/hooks/stop-verify-gate.sh"
fail=0
ok()  { echo "PASS $1"; }
bad() { echo "FAIL $1 ($2)"; fail=1; }

work="$(mktemp -d)"; cap="$(mktemp -d)"; trap 'rm -rf "$work" "$cap"' EXIT
git -C "$work" init -q && git -C "$work" config user.email t@t && git -C "$work" config user.name t
echo base > "$work/app.js" && git -C "$work" add -A && git -C "$work" commit -qm init

run() { # session  -> sets rc, err, out
  err="$cap/err"; out="$cap/out"
  printf '{"session_id":"%s"}' "$1" | CLAUDE_PROJECT_DIR="$work" bash "$hook" >"$out" 2>"$err"; rc=$?
}

# 1. clean tree -> allow
VERIFY_CMD='exit 1' run s1
[ $rc -eq 0 ] && ok "clean tree allows stop" || bad "clean tree allows stop" "rc=$rc"

# 2. markdown-only change -> allow even if verify would fail
echo "# notes" > "$work/NOTES.md"
VERIFY_CMD='exit 1' run s1
[ $rc -eq 0 ] && ok "docs-only change is not gated" || bad "docs-only change is not gated" "rc=$rc"
rm "$work/NOTES.md"

# 3. code change + passing verify -> allow
echo change >> "$work/app.js"
VERIFY_CMD='echo ok' run s2
[ $rc -eq 0 ] && ok "passing verify allows stop" || bad "passing verify allows stop" "rc=$rc"

# 4. code change + failing verify -> blocked with feedback (attempt 1 of 3)
VERIFY_CMD='echo "1 test failing: foo" ; exit 1' VERIFY_MAX_ATTEMPTS=3 run s3
if [ $rc -eq 2 ] && grep -q "attempt 1 of 3" "$err" && grep -q "foo" "$err"; then ok "failing verify blocks with output"
else bad "failing verify blocks with output" "rc=$rc"; fi

# 5. second failure -> still blocked, attempt 2
VERIFY_CMD='exit 1' VERIFY_MAX_ATTEMPTS=3 run s3
[ $rc -eq 2 ] && grep -q "attempt 2 of 3" "$err" && ok "counter increments" || bad "counter increments" "rc=$rc"

# 6. third failure -> loop is bounded: allow stop and escalate
VERIFY_CMD='exit 1' VERIFY_MAX_ATTEMPTS=3 run s3
if [ $rc -eq 0 ] && grep -q "ESCALATE" "$out"; then ok "bounded: escalates after max attempts"
else bad "bounded: escalates after max attempts" "rc=$rc out=$(cat "$out")"; fi

# 7. sessions are independent
VERIFY_CMD='exit 1' VERIFY_MAX_ATTEMPTS=3 run s4
[ $rc -eq 2 ] && grep -q "attempt 1 of 3" "$err" && ok "sessions have separate counters" || bad "sessions have separate counters" "rc=$rc"

# 8. success resets the counter
VERIFY_CMD='echo ok' run s4
VERIFY_CMD='exit 1' VERIFY_MAX_ATTEMPTS=3 run s4
[ $rc -eq 2 ] && grep -q "attempt 1 of 3" "$err" && ok "success resets counter" || bad "success resets counter" "rc=$rc"

exit $fail
