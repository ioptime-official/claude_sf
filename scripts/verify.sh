#!/usr/bin/env bash
# Runs the right checks for every stack present (or only those with changes).
#   scripts/verify.sh [--changed [BASE]] [--full] [--no-salesforce]
#     --changed [BASE]  only stacks with changes vs BASE (default HEAD) plus uncommitted files
#     --full            also run production builds
#     --no-salesforce   skip the org validate (CI runs that in its own workflow)
#     --only STACK      run just one of: salesforce dotnet react wordpress
# Exit 0 = everything that ran passed. Exit 1 = at least one check failed (summary on stderr).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "${VERIFY_ROOT:-${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}}"
export PATH="$HOME/.dotnet:$PATH"

CHANGED=0 BASE=HEAD FULL=0 SKIP_SF=0 ONLY=
while [ $# -gt 0 ]; do
  case "$1" in
    --changed) CHANGED=1; if [ $# -gt 1 ] && [[ "$2" != --* ]]; then BASE="$2"; shift; fi ;;
    --full) FULL=1 ;;
    --no-salesforce) SKIP_SF=1 ;;
    --only) ONLY="${2:?--only needs a stack}"; shift ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

info="$(python3 "$SCRIPT_DIR/detect-stacks.py")"
if [ "$CHANGED" = 1 ]; then
  stacks="$(python3 "$SCRIPT_DIR/detect-stacks.py" --changed "$BASE")"
else
  stacks="$(python3 - <<PY
import json; d=json.loads('''$info''')
print("\n".join(n for n in ("salesforce","dotnet","react","wordpress") if d.get(n)))
PY
)"
fi
[ -z "$ONLY" ] || stacks="$(printf '%s\n' "$stacks" | grep -x "$ONLY" || true)"
[ -n "$stacks" ] || { echo "verify: nothing to check"; exit 0; }

field() { # stack key -> newline list
  python3 - "$1" "$2" <<PY
import json,sys; d=json.loads('''$info'''); s,k=sys.argv[1],sys.argv[2]; v=d.get(s)
if s=="salesforce": print("\n".join(v["packageDirs"]) if v else "")
elif k=="root": print("\n".join(e["root"] for e in v))
elif k=="tests": print("\n".join(t for e in v for t in e["tests"]))
PY
}

failed=()
tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT

check() { # name command...
  local name="$1"; shift
  if "$@" >"$tmp" 2>&1; then echo "PASS  $name"
  else echo "FAIL  $name" >&2; tail -n 40 "$tmp" >&2; failed+=("$name"); fi
}
skip() { echo "SKIP  $1 ($2)"; }

for s in $stacks; do
  case "$s" in
    react)
      while read -r root; do
        [ -n "$root" ] || continue
        command -v npm >/dev/null || { skip "react:$root" "npm missing"; continue; }
        check "react tests ($root)" bash -c "cd '$root' && { [ -d node_modules ] || npm install --no-audit --no-fund >/dev/null; } && npm test --silent"
        [ "$FULL" = 1 ] && check "react build ($root)" bash -c "cd '$root' && npm run build --silent"
      done < <(field react root)
      ;;
    dotnet)
      if ! command -v dotnet >/dev/null; then skip "dotnet" "SDK not installed"; continue; fi
      while read -r t; do
        [ -n "$t" ] || continue
        check "dotnet test ($t)" dotnet test "$t" --configuration Release --nologo --verbosity quiet
      done < <(field dotnet tests)
      ;;
    wordpress)
      if ! command -v php >/dev/null; then skip "wordpress" "php missing"; continue; fi
      while read -r root; do
        [ -n "$root" ] || continue
        check "php lint ($root)" bash -c "find '$root' -name '*.php' -print0 | xargs -0 -n1 php -l >/dev/null"
        for tf in "$root"/tests/*test*.php; do
          [ -f "$tf" ] && check "php test ($tf)" php "$tf"
        done
      done < <(field wordpress root)
      ;;
    salesforce)
      if [ "$SKIP_SF" = 1 ]; then skip "salesforce" "--no-salesforce"; continue; fi
      if ! command -v sf >/dev/null; then skip "salesforce" "sf CLI not installed"; continue; fi
      if [ -s "$HOME/.nvm/nvm.sh" ] && [ "$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)" -lt 22 ]; then
        # shellcheck disable=SC1091
        . "$HOME/.nvm/nvm.sh" >/dev/null 2>&1 && nvm use 22 >/dev/null 2>&1
      fi
      alias_="${SF_SANDBOX_ALIAS:-dev}"
      if ! sf org display --target-org "$alias_" --json >/dev/null 2>&1; then
        skip "salesforce" "org '$alias_' not authenticated"; continue
      fi
      dirs=(); while read -r d; do [ -n "$d" ] && dirs+=(--source-dir "$d"); done < <(field salesforce dirs)
      check "salesforce validate + Apex tests ($alias_)" \
        sf project deploy validate "${dirs[@]}" --target-org "$alias_" --test-level RunLocalTests --wait 10
      ;;
  esac
done

if [ ${#failed[@]} -gt 0 ]; then
  echo "verify: ${#failed[@]} check(s) failed: ${failed[*]}" >&2
  exit 1
fi
echo "verify: all checks passed"
