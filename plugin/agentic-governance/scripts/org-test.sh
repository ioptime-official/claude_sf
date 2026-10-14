#!/usr/bin/env bash
# Test a Salesforce change IN THE ORG before it goes anywhere else.
#
#   scripts/org-test.sh [--org ALIAS] [--validate-only] [--min-coverage N]
#
# What it does, in order (stops at the first failure):
#   1. Look up what kind of org ALIAS is (Organization.IsSandbox / OrganizationType).
#   2. Validate the source against the org (validate-only; runs the Apex tests in the org).
#   3. Deploy it. ONLY if the org is a sandbox or a Developer Edition org. Never otherwise.
#   4. Run the Apex test suite in the org and read the per-test results back.
#   5. Enforce the coverage gate and print a report with deploy IDs, each test and coverage.
#   6. Record evidence tied to a fingerprint of the source, so verify.sh can tell whether the
#      code being finished is the code that was tested.
#
# Exit codes: 0 passed, 1 failed (validate, deploy, tests or coverage), 3 refused (org type),
#             2 usage / environment problem.
#
# Env: SF_SANDBOX_ALIAS (default dev), COVERAGE_MIN (default 85), ORG_TEST_SKIP_NVM=1.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "${VERIFY_ROOT:-${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}}" || exit 2

ALIAS="${SF_SANDBOX_ALIAS:-dev}"
MIN_COV="${COVERAGE_MIN:-85}"
VALIDATE_ONLY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --org) ALIAS="${2:?--org needs an alias}"; shift ;;
    --validate-only) VALIDATE_ONLY=1 ;;
    --min-coverage) MIN_COV="${2:?--min-coverage needs a number}"; shift ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

command -v sf >/dev/null 2>&1 || { echo "org-test: sf CLI not installed" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "org-test: python3 required" >&2; exit 2; }

# Recent CLI releases need Node 22+.
if [ -z "${ORG_TEST_SKIP_NVM:-}" ] && [ -s "$HOME/.nvm/nvm.sh" ] \
   && [ "$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)" -lt 22 ]; then
  # shellcheck disable=SC1091
  . "$HOME/.nvm/nvm.sh" >/dev/null 2>&1 && nvm use 22 >/dev/null 2>&1
fi

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
jget() { python3 -c 'import json,sys
d=json.load(open(sys.argv[1]))
for k in sys.argv[2].split("."):
    d = d.get(k) if isinstance(d, dict) else None
print("" if d is None else d)' "$1" "$2"; }

# Package directories come from sfdx-project.json, never from a hardcoded path.
dirs=()
while IFS= read -r d; do [ -n "$d" ] && dirs+=(--source-dir "$d"); done < <(
  python3 "$SCRIPT_DIR/detect-stacks.py" | python3 -c 'import json,sys
sf=json.load(sys.stdin).get("salesforce") or {}
print("\n".join(sf.get("packageDirs", [])))')
[ ${#dirs[@]} -gt 0 ] || { echo "org-test: no Salesforce package directories found" >&2; exit 2; }

# ---- 1. What kind of org is this? ----
# Run an sf command that writes JSON to a file. Retries on transient network errors only
# (fetch failed, reset, timeout). Never used for the deploy itself: a retried deploy could
# double-apply if the first attempt actually reached the org.
sf_json() { # outfile tries -- command...
  local out="$1" tries="$2"; shift 3
  local n=0 rc
  while :; do
    "$@" >"$out" 2>"$out.err"; rc=$?
    n=$((n + 1))
    if [ "$n" -lt "$tries" ] && grep -qiE 'fetch failed|ECONNRESET|ETIMEDOUT|EAI_AGAIN|socket hang up' "$out" "$out.err" 2>/dev/null; then
      echo "   (transient network error, retrying once)" >&2; sleep 5; continue
    fi
    return $rc
  done
}

show_error() { # json-file : print the CLI's own error message when there is no result
  local m; m="$(jget "$1" message)"
  [ -n "$m" ] && echo "  error: $m"
  return 0
}

if ! sf_json "$tmp/org.json" 2 -- sf data query --query "SELECT Name, IsSandbox, OrganizationType FROM Organization" \
      --target-org "$ALIAS" --json; then
  echo "org-test: could not query org '$ALIAS' (not authenticated or network problem)" >&2
  show_error "$tmp/org.json" >&2; tail -n 3 "$tmp/org.json.err" >&2; exit 2
fi
python3 - "$tmp/org.json" >"$tmp/org.env" <<'PY'
import json, sys
r = json.load(open(sys.argv[1]))["result"]["records"][0]
print(f'ORG_NAME={json.dumps(r.get("Name",""))}')
print(f'ORG_SANDBOX={"1" if r.get("IsSandbox") else "0"}')
print(f'ORG_TYPE={json.dumps(r.get("OrganizationType",""))}')
PY
# shellcheck disable=SC1091
. "$tmp/org.env"

can_deploy=0
if [ "$ORG_SANDBOX" = "1" ] || [ "$ORG_TYPE" = "Developer Edition" ]; then can_deploy=1; fi

echo "== Salesforce org test"
echo "Org      : $ORG_NAME ($ORG_TYPE, sandbox=$ORG_SANDBOX), alias '$ALIAS'"
if [ "$can_deploy" = 0 ]; then
  if [ "$VALIDATE_ONLY" = 1 ]; then
    echo "Policy   : not a sandbox or Developer Edition org, so validate-only is allowed but deploy is not"
  else
    echo "REFUSED  : '$ALIAS' is a $ORG_TYPE org that is not a sandbox. Deploys are only allowed to a" >&2
    echo "           sandbox or a Developer Edition org. Use --validate-only, or point --org at one." >&2
    exit 3
  fi
else
  echo "Policy   : sandbox / Developer Edition, deploy allowed"
fi

fail() { echo "FAIL     : $1" >&2; exit 1; }

summarize_failures() { # json-file
  python3 - "$1" <<'PY'
import json, sys
try:
    r = json.load(open(sys.argv[1])).get("result", {})
except Exception:
    sys.exit(0)
det = r.get("details", {}) or {}
for f in (det.get("componentFailures") or [])[:8]:
    print(f'  component {f.get("fullName")}: {f.get("problem")}')
for t in ((det.get("runTestResult") or {}).get("failures") or [])[:8]:
    print(f'  test {t.get("name")}.{t.get("methodName")}: {t.get("message")}')
PY
}

# ---- 2. Validate in the org ----
echo "-- 1/3 validate (no changes made to the org)"
sf_json "$tmp/validate.json" 2 -- sf project deploy validate "${dirs[@]}" --target-org "$ALIAS" \
  --test-level RunLocalTests --wait 15 --json
vrc=$?
VAL_ID="$(jget "$tmp/validate.json" result.id)"
VAL_STATUS="$(jget "$tmp/validate.json" result.status)"
if [ $vrc -ne 0 ] || [ "$VAL_STATUS" != "Succeeded" ]; then
  echo "Validate : FAILED (${VAL_STATUS:-no result}) id=${VAL_ID:--}"
  show_error "$tmp/validate.json"; summarize_failures "$tmp/validate.json"
  fail "validation against '$ALIAS' failed; nothing was deployed"
fi
echo "Validate : PASS  id=$VAL_ID  components=$(jget "$tmp/validate.json" result.numberComponentsDeployed)/$(jget "$tmp/validate.json" result.numberComponentsTotal)  tests=$(jget "$tmp/validate.json" result.numberTestsCompleted)"

if [ "$VALIDATE_ONLY" = 1 ]; then
  echo "Mode     : validate-only; no deploy, no evidence recorded"
  exit 0
fi

# ---- 3. Deploy (sandbox / Developer Edition only; checked above) ----
echo "-- 2/3 deploy to '$ALIAS'"
sf_json "$tmp/deploy.json" 1 -- sf project deploy start "${dirs[@]}" --target-org "$ALIAS" \
  --test-level RunLocalTests --wait 15 --json
drc=$?
DEP_ID="$(jget "$tmp/deploy.json" result.id)"
DEP_STATUS="$(jget "$tmp/deploy.json" result.status)"
if [ $drc -ne 0 ] || [ "$DEP_STATUS" != "Succeeded" ]; then
  echo "Deploy   : FAILED (${DEP_STATUS:-no result}) id=${DEP_ID:--}"
  show_error "$tmp/deploy.json"; summarize_failures "$tmp/deploy.json"
  fail "deploy to '$ALIAS' failed"
fi
echo "Deploy   : PASS  id=$DEP_ID"

# ---- 4. Run the Apex tests in the org and read results back ----
echo "-- 3/3 run Apex tests in the org"
sf_json "$tmp/tests.json" 2 -- sf apex run test --test-level RunLocalTests --code-coverage --wait 15 \
  --target-org "$ALIAS" --json
if [ -z "$(jget "$tmp/tests.json" result.summary.outcome)" ]; then
  echo "Tests    : no result returned"; show_error "$tmp/tests.json"
  fail "could not read Apex test results from '$ALIAS'"
fi
python3 - "$tmp/tests.json" <<'PY'
import json, sys
r = json.load(open(sys.argv[1])).get("result", {})
s = r.get("summary", {})
print(f'Tests    : {s.get("passing", 0)} passed, {s.get("failing", 0)} failed, '
      f'outcome={s.get("outcome")}, testRunId={s.get("testRunId")}')
for t in r.get("tests", []):
    mark = "PASS" if t.get("Outcome") == "Pass" else "FAIL"
    name = t.get("FullName") or f'{t.get("ApexClass", {}).get("Name")}.{t.get("MethodName")}'
    print(f'  {mark}  {name}  ({t.get("RunTime", "?")} ms)')
    if mark == "FAIL" and t.get("Message"):
        print(f'        {str(t["Message"])[:160]}')
cov = (r.get("coverage") or {}).get("coverage") or []
if cov:
    print("Coverage by class:")
    for c in sorted(cov, key=lambda c: c.get("name", "")):
        print(f'  {c.get("name"):32} {c.get("coveredPercent")}%')
print(f'Coverage : run {s.get("testRunCoverage")}, org-wide {s.get("orgWideCoverage")}')
PY

# ---- 5. Gate ----
if ! bash "$SCRIPT_DIR/check-apex-coverage.sh" "$tmp/tests.json" "$MIN_COV" >"$tmp/gate.txt" 2>&1; then
  cat "$tmp/gate.txt" >&2
  fail "Apex tests or coverage gate failed in the org"
fi
sed 's/^/Gate     : /' "$tmp/gate.txt" | head -1

# ---- 6. Evidence, tied to the exact source that was tested ----
fp="$(python3 "$SCRIPT_DIR/sf-fingerprint.py")"
key="$(pwd | cksum | awk '{print $1}')"
edir="${TMPDIR:-/tmp}/claude-org-test"; mkdir -p "$edir"
python3 - "$tmp/tests.json" "$edir/evidence-$key.json" "$fp" "$ALIAS" "$ORG_NAME" "$ORG_TYPE" "$VAL_ID" "$DEP_ID" <<'PY'
import datetime, json, sys
tests, out, fp, alias, name, typ, val, dep = sys.argv[1:9]
s = json.load(open(tests)).get("result", {}).get("summary", {})
json.dump({
    "passed": True, "mode": "deploy", "fingerprint": fp, "alias": alias, "org": name, "orgType": typ,
    "validateId": val, "deployId": dep, "passing": s.get("passing"), "failing": s.get("failing"),
    "coverage": s.get("testRunCoverage"),
    "at": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
}, open(out, "w"), indent=2)
PY
echo "Evidence : recorded for source fingerprint ${fp:0:12}"
echo "RESULT   : PASS - change validated, deployed and tested in '$ALIAS'"
exit 0
