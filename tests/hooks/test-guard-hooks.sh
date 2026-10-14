#!/usr/bin/env bash
# Tests for secret-guard, protected-paths and audit-log. Fake secrets are assembled at runtime
# so this file never contains a literal secret (and passes its own secret-guard).
cd "$(dirname "$0")/../.." || exit 1
root="$PWD"; H="$root/.claude/hooks"
fail=0
ok()  { echo "PASS $1"; }
bad() { echo "FAIL $1 ($2)"; fail=1; }
cap="$(mktemp -d)"; trap 'rm -rf "$cap"' EXIT

json() { python3 -c 'import json,sys; print(json.dumps(json.loads(sys.argv[1])))' "$1"; }
run() { # hook  json  [env...] -> rc, $cap/err
  local hook="$1" payload="$2"; shift 2
  printf '%s' "$payload" | env CLAUDE_PROJECT_DIR="$root" "$@" bash "$H/$hook" >"$cap/out" 2>"$cap/err"; rc=$?
}
write_payload() { python3 -c 'import json,sys; print(json.dumps({"tool_name":"Write","tool_input":{"file_path":sys.argv[1],"content":sys.argv[2]}}))' "$1" "$2"; }
bash_payload()  { python3 -c 'import json,sys; print(json.dumps({"tool_name":"Bash","tool_input":{"command":sys.argv[1]}}))' "$1"; }

tok_ant="sk-ant-$(printf 'A%.0s' $(seq 1 30))"
tok_gh="ghp_$(printf 'b%.0s' $(seq 1 36))"
url_sf="force://PlatformCLI::$(printf 'x%.0s' $(seq 1 20))@example.my.salesforce.com"
pw_line="const password = \"$(printf 'Z%.0s' $(seq 1 16))\";"

echo "== secret-guard"
for pair in "anthropic|$tok_ant" "github|$tok_gh" "sfdx-url|$url_sf" "hardcoded-password|$pw_line"; do
  name="${pair%%|*}"; val="${pair#*|}"
  run secret-guard.sh "$(write_payload src/a.js "x = '$val'
$val")"
  if [ $rc -eq 2 ] && ! grep -qF "$val" "$cap/err"; then ok "blocks $name without echoing it"; else bad "blocks $name" "rc=$rc"; fi
done
run secret-guard.sh "$(write_payload src/a.js 'const total = items.length + 1;')"
[ $rc -eq 0 ] && ok "allows normal code" || bad "allows normal code" "rc=$rc"
run secret-guard.sh "$(write_payload src/a.js "k = '$tok_ant' // allowlist-secret")"
[ $rc -eq 0 ] && ok "allowlist marker works" || bad "allowlist marker works" "rc=$rc"
edit="$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Edit","tool_input":{"file_path":"a.js","old_string":"x","new_string":sys.argv[1]}}))' "k='$tok_gh'")"
run secret-guard.sh "$edit"
[ $rc -eq 2 ] && ok "checks Edit new_string" || bad "checks Edit new_string" "rc=$rc"

echo "== protected-paths"
run protected-paths.sh "$(write_payload .claude/settings.json '{}')"
[ $rc -eq 2 ] && ok "blocks editing settings.json" || bad "blocks editing settings.json" "rc=$rc"
run protected-paths.sh "$(write_payload "$root/.claude/hooks/secret-guard.sh" 'x')"
[ $rc -eq 2 ] && ok "blocks editing a hook (absolute path)" || bad "blocks editing a hook" "rc=$rc"
run protected-paths.sh "$(write_payload .github/workflows/ci.yml 'x')"
[ $rc -eq 2 ] && ok "blocks editing CI workflows" || bad "blocks editing CI workflows" "rc=$rc"
run protected-paths.sh "$(write_payload apps/react-web/src/App.jsx 'x')"
[ $rc -eq 0 ] && ok "allows normal source edit" || bad "allows normal source edit" "rc=$rc"
run protected-paths.sh "$(bash_payload "sed -i 's/a/b/' .claude/settings.json")"
[ $rc -eq 2 ] && ok "blocks sed -i on protected file via Bash" || bad "blocks sed -i via Bash" "rc=$rc"
run protected-paths.sh "$(bash_payload "echo x > .github/workflows/deploy.yml")"
[ $rc -eq 2 ] && ok "blocks redirect into workflow via Bash" || bad "blocks redirect via Bash" "rc=$rc"
run protected-paths.sh "$(bash_payload "cat .claude/settings.json")"
[ $rc -eq 0 ] && ok "allows reading protected file" || bad "allows reading protected file" "rc=$rc"
run protected-paths.sh "$(write_payload .claude/settings.json '{}')" ALLOW_PROTECTED_EDIT=1
[ $rc -eq 0 ] && ok "human override works" || bad "human override works" "rc=$rc"

echo "== audit-log"
adir="$cap/audit"
run audit-log.sh "$(bash_payload "curl -H 'Authorization: Bearer abc123secret' https://x && export password=hunter2hunter2")" CLAUDE_AUDIT_DIR="$adir"
f="$(ls "$adir"/*.jsonl 2>/dev/null | head -1)"
if [ -n "$f" ] && python3 -c 'import json,sys; [json.loads(l) for l in open(sys.argv[1])]' "$f" \
   && ! grep -q "abc123secret" "$f" && ! grep -q "hunter2" "$f" && grep -q '"tool": "Bash"' "$f"; then
  ok "writes valid JSONL with secrets masked"
else bad "writes valid JSONL with secrets masked" "file=$f"; fi
[ $rc -eq 0 ] && ok "never blocks the agent" || bad "never blocks the agent" "rc=$rc"

exit $fail
