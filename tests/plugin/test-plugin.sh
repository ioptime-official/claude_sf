#!/usr/bin/env bash
# Proves the generated plugin works in a repo that looks nothing like this one:
# custom Salesforce package directory, React app under an arbitrary folder, no .claude/ at all.
cd "$(dirname "$0")/../.." || exit 1
src="$PWD"
P="$src/plugin/agentic-governance"
fail=0
ok()  { echo "PASS $1"; }
bad() { echo "FAIL $1 ($2)"; fail=1; }

bash scripts/build-plugin.sh --check >/dev/null 2>&1 && ok "committed plugin matches source" || bad "committed plugin matches source" "run scripts/build-plugin.sh"

work="$(mktemp -d)"; cap="$(mktemp -d)"; trap 'rm -rf "$work" "$cap"' EXIT
proj="$work/client-repo"
mkdir -p "$proj/src/core/classes" "$proj/storefront/ui/node_modules"
cat > "$proj/sfdx-project.json" <<'JSON'
{"packageDirectories":[{"path":"src/core","default":true}],"sourceApiVersion":"62.0"}
JSON
echo '{"name":"ui","dependencies":{"react":"^18"},"scripts":{"test":"exit 0"}}' > "$proj/storefront/ui/package.json"
echo "console.log(1)" > "$proj/storefront/ui/a.js"
git -C "$proj" init -q && git -C "$proj" config user.email t@t && git -C "$proj" config user.name t
git -C "$proj" add -A && git -C "$proj" commit -qm init

run() { # hook payload [env...]
  local hook="$1" payload="$2"; shift 2
  (cd "$proj" && printf '%s' "$payload" | env CLAUDE_PROJECT_DIR="$proj" "$@" bash "$P/hooks/$hook" >"$cap/out" 2>"$cap/err"); rc=$?
}

# session context discovers the foreign layout
(cd "$proj" && CLAUDE_PROJECT_DIR="$proj" bash "$P/hooks/session-context.sh") >"$cap/ctx" 2>&1
grep -q "salesforce: src/core" "$cap/ctx" && grep -q "react: storefront/ui" "$cap/ctx" \
  && ok "session context discovers custom layout" || bad "session context discovers custom layout" "$(cat "$cap/ctx")"

# stop gate: clean -> allow
run stop-verify-gate.sh '{"session_id":"p1"}'
[ $rc -eq 0 ] && ok "stop gate allows clean tree" || bad "stop gate allows clean tree" "rc=$rc"

# stop gate: change + passing tests -> allow (uses the plugin's own verify.sh on the foreign repo)
echo "console.log(2)" >> "$proj/storefront/ui/a.js"
run stop-verify-gate.sh '{"session_id":"p2"}'
[ $rc -eq 0 ] && ok "stop gate passes real verification on foreign repo" || bad "stop gate passes real verification" "rc=$rc $(cat "$cap/err")"

# stop gate: failing tests -> blocked with output
echo '{"name":"ui","dependencies":{"react":"^18"},"scripts":{"test":"echo BROKEN_TEST && exit 1"}}' > "$proj/storefront/ui/package.json"
run stop-verify-gate.sh '{"session_id":"p3"}'
if [ $rc -eq 2 ] && grep -q "BROKEN_TEST" "$cap/err"; then ok "stop gate blocks on failing foreign tests"
else bad "stop gate blocks on failing foreign tests" "rc=$rc $(head -c 300 "$cap/err")"; fi

# protected paths fall back to the plugin's default list when the project has none
payload="$(python3 -c 'import json; print(json.dumps({"tool_name":"Write","tool_input":{"file_path":".github/workflows/x.yml","content":"x"}}))')"
run protected-paths.sh "$payload"
[ $rc -eq 2 ] && ok "default protected paths apply without project config" || bad "default protected paths" "rc=$rc"

# deploy guard travels with the plugin
payload="$(python3 -c 'import json; print(json.dumps({"tool_name":"Bash","tool_input":{"command":"sf project deploy start --target-org prod"}}))')"
run block-prod-deploy.sh "$payload"
[ $rc -eq 2 ] && ok "production deploy blocked by plugin hook" || bad "production deploy blocked" "rc=$rc"

# hooks.json is well-formed and points only at files that exist
python3 - "$P" <<'PY' && ok "hooks.json references existing scripts" || bad "hooks.json references existing scripts" "see above"
import json, os, re, sys
root = sys.argv[1]
h = json.load(open(f"{root}/hooks/hooks.json"))["hooks"]
missing = []
for entries in h.values():
    for e in entries:
        for hook in e["hooks"]:
            m = re.search(r'\$\{CLAUDE_PLUGIN_ROOT\}/(\S+?)"?$', hook["command"])
            if not m or not os.path.isfile(f"{root}/{m.group(1)}"):
                missing.append(hook["command"])
if missing:
    print("missing:", missing); sys.exit(1)
PY

exit $fail
