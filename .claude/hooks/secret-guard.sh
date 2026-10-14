#!/usr/bin/env bash
# PreToolUse (Edit|Write|MultiEdit): refuse to write likely secrets into the repo.
# Exit 2 + a message naming the pattern and line (never the secret itself).
# Add the marker "allowlist-secret" on a line to permit a deliberate fake value.
set -u
HOOK_INPUT="$(cat)"; export HOOK_INPUT
python3 - <<'PY'
import json, os, re, sys

try:
    data = json.loads(os.environ.get("HOOK_INPUT") or "{}")
except Exception:
    sys.exit(0)

ti = data.get("tool_input", {}) or {}
chunks = []
if isinstance(ti.get("content"), str):
    chunks.append(ti["content"])
if isinstance(ti.get("new_string"), str):
    chunks.append(ti["new_string"])
for e in ti.get("edits", []) or []:
    if isinstance(e, dict) and isinstance(e.get("new_string"), str):
        chunks.append(e["new_string"])

PATTERNS = [
    ("AWS access key id", r"AKIA[0-9A-Z]{16}"),
    ("Anthropic API/OAuth token", r"sk-ant-[A-Za-z0-9_\-]{20,}"),
    ("GitHub token", r"gh[pousr]_[A-Za-z0-9]{30,}"),
    ("Salesforce SFDX auth URL", r"force://[^\s'\"]*@"),
    ("Salesforce session id", r"00D[A-Za-z0-9]{12,15}![A-Za-z0-9_.]{20,}"),
    ("private key block", r"-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----"),
    ("hardcoded credential", r"(?i)\b(?:password|passwd|secret|api[_-]?key|access[_-]?token|client[_-]?secret)\b\s*[:=]\s*[\"'][A-Za-z0-9/+_\-\.]{12,}[\"']"),
]

hits = []
for chunk in chunks:
    for i, line in enumerate(chunk.splitlines(), 1):
        if "allowlist-secret" in line:
            continue
        for name, rx in PATTERNS:
            if re.search(rx, line):
                hits.append((name, i))

if hits:
    path = ti.get("file_path", "<file>")
    print(f"BLOCKED by secret-guard: possible secret in content for {path}:", file=sys.stderr)
    for name, i in hits[:5]:
        print(f"  - {name} (line {i} of the new content)", file=sys.stderr)
    print("Use an environment variable or secret store instead. If this is a deliberate fake, "
          "add 'allowlist-secret' to that line.", file=sys.stderr)
    sys.exit(2)
PY
exit $?
