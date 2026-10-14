#!/usr/bin/env bash
# SessionStart: inject what the agent needs to be effective, so rules need no hardcoded paths.
# Anything printed to stdout is added to the session context.
here="$(cd "$(dirname "$0")" && pwd)"
for d in "$here/../../scripts" "$here/../scripts"; do
  [ -f "$d/detect-stacks.py" ] && scripts="$(cd "$d" && pwd)" && break
done
[ -n "${scripts:-}" ] || exit 0
echo "## Pipeline context"
echo "Helper scripts: $scripts (detect-stacks.py, verify.sh). Wherever instructions say <scripts-dir>, use this directory. They run against the project directory."
echo "Detected stacks:"
python3 "$scripts/detect-stacks.py" 2>/dev/null | python3 -c '
import json,sys
d=json.load(sys.stdin)
sf=d.get("salesforce")
print("  salesforce: " + (", ".join(sf["packageDirs"]) if sf else "none"))
for k in ("dotnet","react","wordpress"):
    print(f"  {k}: " + (", ".join(e["root"] for e in d[k]) or "none"))
'
echo "Rules: never deploy to production; verify with verify.sh before finishing; the Stop hook enforces it."
exit 0
