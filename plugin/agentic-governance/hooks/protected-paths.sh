#!/usr/bin/env bash
# PreToolUse (Edit|Write|MultiEdit|Bash): the agent cannot edit its own guardrails, CI or env files.
# File tools are checked exactly. Bash is checked best-effort (a write verb plus a protected path).
set -u
root="${CLAUDE_PROJECT_DIR:-$(pwd)}"
export PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
[ "${ALLOW_PROTECTED_EDIT:-0}" = "1" ] && exit 0
HOOK_INPUT="$(cat)"; export ROOT="$root" HOOK_INPUT
python3 - <<'PY'
import fnmatch, json, os, re, sys

root = os.environ["ROOT"]
try:
    data = json.loads(os.environ.get("HOOK_INPUT") or "{}")
except Exception:
    sys.exit(0)

pf = os.path.join(root, ".claude", "protected-paths.txt")
if not os.path.isfile(pf):
    pf = os.path.join(os.environ.get("PLUGIN_ROOT", ""), "protected-paths.txt")
if not os.path.isfile(pf):
    sys.exit(0)
globs = [l.strip() for l in open(pf) if l.strip() and not l.lstrip().startswith("#")]

def rel(p):
    p = os.path.normpath(p if os.path.isabs(p) else os.path.join(root, p))
    return os.path.relpath(p, root)

def protected(path):
    r = rel(path)
    if r.startswith(".."):
        return None
    for g in globs:
        if fnmatch.fnmatch(r, g):
            return g
    return None

tool = data.get("tool_name", "")
ti = data.get("tool_input", {}) or {}
block = None

if tool in ("Edit", "Write", "MultiEdit") and ti.get("file_path"):
    g = protected(ti["file_path"])
    if g:
        block = f"{rel(ti['file_path'])} is protected (matches '{g}')"
elif tool == "Bash":
    cmd = ti.get("command", "")
    writes = re.search(r"(>>?|\bsed\s+-i|\btee\b|\brm\b|\bmv\b|\bcp\b|\bchmod\b|\bgit\s+(checkout|rm|restore)\b|\btruncate\b)", cmd)
    if writes:
        for g in globs:
            literal = g.split("*")[0]
            if literal and literal in cmd and not literal.endswith("/") or (g.endswith("/*") and g[:-1] in cmd):
                block = f"command appears to modify a protected path (matches '{g}')"
                break

if block:
    print(f"BLOCKED by protected-paths: {block}. Guardrails, CI workflows and env files are "
          "changed by humans through a reviewed PR, not by the agent.", file=sys.stderr)
    sys.exit(2)
PY
exit $?
