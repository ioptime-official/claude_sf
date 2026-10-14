#!/usr/bin/env bash
# Tests scripts/org-test.sh and the org-evidence rule in scripts/verify.sh using a fake `sf`.
# No real org is touched. The fake records every call so we can prove what was (not) run.
cd "$(dirname "$0")/../.." || exit 1
src="$PWD"
fail=0
ok()  { echo "PASS $1"; }
bad() { echo "FAIL $1 ($2)"; fail=1; }

work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
bin="$work/bin"; mkdir -p "$bin"

# ---- fake sf -------------------------------------------------------------
cat > "$bin/sf" <<'FAKE'
#!/usr/bin/env bash
echo "$*" >> "${FAKE_LOG:?}"
args="$*"
case "$args" in
  *"data query"*)
    printf '{"status":0,"result":{"records":[{"Name":"FakeOrg","IsSandbox":%s,"OrganizationType":"%s"}]}}' \
      "${FAKE_ISSANDBOX:-false}" "${FAKE_ORGTYPE:-Developer Edition}" ;;
  *"deploy validate"*)
    if [ "${FAKE_FLAKE_VALIDATE:-0}" = 1 ] && [ ! -f "$FAKE_LOG.vflaked" ]; then
      touch "$FAKE_LOG.vflaked"
      echo '{"status":1,"name":"Error","message":"fetch failed"}'; exit 1
    fi
    if [ "${FAKE_VALIDATE_OK:-1}" = 1 ]; then
      echo '{"status":0,"result":{"id":"0AfVALID","status":"Succeeded","success":true,"numberComponentsDeployed":3,"numberComponentsTotal":3,"numberTestsCompleted":4}}'
    else
      echo '{"status":1,"result":{"id":"0AfVALID","status":"Failed","success":false,"details":{"componentFailures":[{"fullName":"Broken","problem":"compile error"}]}}}'
      exit 1
    fi ;;
  *"deploy start"*)
    if [ "${FAKE_FLAKE_DEPLOY:-0}" = 1 ]; then
      echo '{"status":1,"name":"Error","message":"fetch failed"}'; exit 1
    fi
    echo '{"status":0,"result":{"id":"0AfDEPLOY","status":"Succeeded","success":true}}' ;;
  *"apex run test"*)
    pass=4; failn=0; outcome=Passed
    [ "${FAKE_TESTS_FAIL:-0}" = 1 ] && { pass=3; failn=1; outcome=Failed; }
    cat <<JSON
{"status":0,"result":{"summary":{"outcome":"$outcome","passing":$pass,"failing":$failn,"testRunId":"707RUN","testRunCoverage":"${FAKE_COVERAGE:-96%}","orgWideCoverage":"90%"},
 "tests":[{"FullName":"AccountServiceTest.applyRating_handlesBulk200","Outcome":"Pass","RunTime":12},
          {"FullName":"HotAccountFlowTest.hotAccount_getsFollowUpTask","Outcome":"$([ "$failn" = 1 ] && echo Fail || echo Pass)","RunTime":30,"Message":"assertion failed"}],
 "coverage":{"coverage":[{"name":"AccountService","coveredPercent":100}]}}}
JSON
    ;;
  *) echo '{"status":0,"result":{}}' ;;
esac
FAKE
chmod +x "$bin/sf"

# ---- a throwaway Salesforce repo ----------------------------------------
proj="$work/proj"; mkdir -p "$proj/src/main/classes"
echo '{"packageDirectories":[{"path":"src/main","default":true}]}' > "$proj/sfdx-project.json"
echo 'public class Foo {}' > "$proj/src/main/classes/Foo.cls"
git -C "$proj" init -q && git -C "$proj" config user.email t@t && git -C "$proj" config user.name t
git -C "$proj" add -A && git -C "$proj" commit -qm init

run_org() { # [env assignments...] -- args
  : > "$work/calls.log"
  ( cd "$proj" && env PATH="$bin:$PATH" FAKE_LOG="$work/calls.log" TMPDIR="$work/tmp" ORG_TEST_SKIP_NVM=1 \
      CLAUDE_PROJECT_DIR="$proj" "$@" bash "$src/scripts/org-test.sh" ) >"$work/out.txt" 2>&1
  rc=$?
}
mkdir -p "$work/tmp"
called() { grep -q "$1" "$work/calls.log"; }

# 1. Production-like org: refused, nothing deployed
run_org FAKE_ISSANDBOX=false FAKE_ORGTYPE="Enterprise Edition"
if [ $rc -eq 3 ] && grep -q REFUSED "$work/out.txt" && ! called "deploy start" && ! called "deploy validate"; then
  ok "production org refused before any validate or deploy"
else bad "production org refused" "rc=$rc"; fi

# 2. Production org + --validate-only: allowed, but still never deploys
run_org FAKE_ISSANDBOX=false FAKE_ORGTYPE="Enterprise Edition" -- 2>/dev/null
: > "$work/calls.log"
( cd "$proj" && env PATH="$bin:$PATH" FAKE_LOG="$work/calls.log" TMPDIR="$work/tmp" ORG_TEST_SKIP_NVM=1 \
    CLAUDE_PROJECT_DIR="$proj" FAKE_ISSANDBOX=false FAKE_ORGTYPE="Enterprise Edition" \
    bash "$src/scripts/org-test.sh" --validate-only ) >"$work/out.txt" 2>&1; rc=$?
if [ $rc -eq 0 ] && called "deploy validate" && ! called "deploy start"; then ok "validate-only allowed on non-sandbox, never deploys"
else bad "validate-only on non-sandbox" "rc=$rc"; fi

# 3. Developer Edition org: validate, deploy, run tests, in that order
rm -rf "$work/tmp"/*
run_org FAKE_ISSANDBOX=false FAKE_ORGTYPE="Developer Edition"
order="$(grep -n -E 'deploy validate|deploy start|apex run test' "$work/calls.log" | sed -E 's/^[0-9]+://' | awk '{print $2" "$3}' | tr '\n' '|')"
if [ $rc -eq 0 ] && grep -q "RESULT   : PASS" "$work/out.txt" \
   && [ "$(grep -c 'deploy validate' "$work/calls.log")" = 1 ] && called "deploy start" && called "apex run test"; then
  ok "Developer Edition: validated, deployed and tested in the org"
else bad "Developer Edition happy path" "rc=$rc"; fi
first="$(grep -n 'deploy validate' "$work/calls.log" | head -1 | cut -d: -f1)"
second="$(grep -n 'deploy start' "$work/calls.log" | head -1 | cut -d: -f1)"
third="$(grep -n 'apex run test' "$work/calls.log" | head -1 | cut -d: -f1)"
[ "$first" -lt "$second" ] && [ "$second" -lt "$third" ] && ok "order is validate then deploy then test" || bad "order" "$first/$second/$third"
grep -q "PASS  AccountServiceTest.applyRating_handlesBulk200" "$work/out.txt" \
  && ok "report lists each Salesforce test by name" || bad "report lists tests" "$(cat "$work/out.txt" | tail -5)"

# 4. Sandbox (not Developer Edition) also allowed
rm -rf "$work/tmp"/*
run_org FAKE_ISSANDBOX=true FAKE_ORGTYPE="Enterprise Edition"
[ $rc -eq 0 ] && called "deploy start" && ok "sandbox org allowed to deploy" || bad "sandbox org allowed" "rc=$rc"

# 5. Validation fails: stop, never deploy
rm -rf "$work/tmp"/*
run_org FAKE_VALIDATE_OK=0 FAKE_ISSANDBOX=false FAKE_ORGTYPE="Developer Edition"
if [ $rc -eq 1 ] && ! called "deploy start" && grep -q "compile error" "$work/out.txt"; then ok "failed validation stops before deploy and shows why"
else bad "failed validation stops" "rc=$rc"; fi

# 6. Tests fail in the org: failure, and no evidence recorded
rm -rf "$work/tmp"/*
run_org FAKE_TESTS_FAIL=1 FAKE_ISSANDBOX=false FAKE_ORGTYPE="Developer Edition"
if [ $rc -eq 1 ] && ! ls "$work"/tmp/claude-org-test/evidence-*.json >/dev/null 2>&1; then ok "failing org tests fail the run and record no evidence"
else bad "failing org tests" "rc=$rc"; fi

# 7. Coverage below the gate fails
rm -rf "$work/tmp"/*
run_org FAKE_COVERAGE="60%" FAKE_ISSANDBOX=false FAKE_ORGTYPE="Developer Edition"
[ $rc -eq 1 ] && grep -qi "below" "$work/out.txt" && ok "coverage gate enforced" || bad "coverage gate" "rc=$rc"

# 8. A transient network error on validate is retried once and then succeeds
rm -rf "$work/tmp"/*; rm -f "$work/calls.log.vflaked"
run_org FAKE_FLAKE_VALIDATE=1 FAKE_ISSANDBOX=false FAKE_ORGTYPE="Developer Edition"
if [ $rc -eq 0 ] && [ "$(grep -c 'deploy validate' "$work/calls.log")" = 2 ] && grep -q "retrying once" "$work/out.txt"; then
  ok "transient network error on validate is retried once"
else bad "validate retry" "rc=$rc validates=$(grep -c 'deploy validate' "$work/calls.log")"; fi

# 9. A network error on the DEPLOY is never retried (could double-apply), and shows the message
rm -rf "$work/tmp"/*; rm -f "$work/calls.log.vflaked"
run_org FAKE_FLAKE_DEPLOY=1 FAKE_ISSANDBOX=false FAKE_ORGTYPE="Developer Edition"
if [ $rc -eq 1 ] && [ "$(grep -c 'deploy start' "$work/calls.log")" = 1 ] && grep -q "error: fetch failed" "$work/out.txt" \
   && ! ls "$work"/tmp/claude-org-test/evidence-*.json >/dev/null 2>&1; then
  ok "deploy is never retried, error shown, no evidence recorded"
else bad "deploy not retried" "rc=$rc starts=$(grep -c 'deploy start' "$work/calls.log")"; fi

# ---- verify.sh evidence rule -------------------------------------------
verify() { # [env...]
  ( cd "$proj" && env PATH="$bin:$PATH" TMPDIR="$work/tmp" CLAUDE_PROJECT_DIR="$proj" "$@" \
      bash "$src/scripts/verify.sh" --changed --no-salesforce ) >"$work/v.txt" 2>&1
  vrc=$?
}
rm -rf "$work/tmp"/*; mkdir -p "$work/tmp"

echo 'public class Foo { Integer x; }' > "$proj/src/main/classes/Foo.cls"   # an uncommitted Salesforce change

verify
if [ $vrc -eq 1 ] && grep -q "no org test has been run" "$work/v.txt"; then ok "changed Salesforce code without an org test is rejected"
else bad "no-evidence rejected" "rc=$vrc $(tail -3 "$work/v.txt")"; fi

run_org FAKE_ISSANDBOX=false FAKE_ORGTYPE="Developer Edition"
verify
[ $vrc -eq 0 ] && grep -q "tested in the org" "$work/v.txt" && ok "after an org test the same code is accepted" || bad "evidence accepted" "rc=$vrc $(tail -3 "$work/v.txt")"

echo 'public class Foo { Integer y; }' > "$proj/src/main/classes/Foo.cls"   # change code AFTER testing
verify
if [ $vrc -eq 1 ] && grep -q "changed since the last org test" "$work/v.txt"; then ok "evidence goes stale when the code changes"
else bad "stale evidence rejected" "rc=$vrc"; fi

verify CI=true
[ $vrc -eq 0 ] && ok "CI is exempt (it runs its own org gates)" || bad "CI exempt" "rc=$vrc"

exit $fail
