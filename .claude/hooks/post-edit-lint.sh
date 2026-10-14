#!/usr/bin/env bash
# PostToolUse (Edit|Write|MultiEdit): cheap, instant checks on the file just written.
# Heavy checks (tests, org validation) belong to the Stop hook, not here.
set -u
input="$(cat)"
f="$(printf '%s' "$input" | python3 -c 'import sys,json
try: print(json.load(sys.stdin).get("tool_input",{}).get("file_path",""))
except Exception: print("")' 2>/dev/null)"
[ -f "$f" ] || exit 0
fail() { echo "post-edit-lint: $1" >&2; exit 2; }
case "$f" in
  *.php) command -v php >/dev/null && { php -l "$f" >/dev/null 2>&1 || fail "PHP syntax error in $f"; } ;;
  *.json) python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$f" 2>/dev/null || fail "invalid JSON in $f" ;;
  *.xml) python3 -c 'import sys,xml.dom.minidom as m; m.parse(sys.argv[1])' "$f" 2>/dev/null || fail "malformed XML in $f" ;;
esac
exit 0
