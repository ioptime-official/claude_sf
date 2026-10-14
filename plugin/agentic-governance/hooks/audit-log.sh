#!/usr/bin/env bash
# PostToolUse (all tools): append one JSON line per tool call, outside the repo.
# Records what happened, not file contents; likely secrets in commands are masked.
set -u
dir="${CLAUDE_AUDIT_DIR:-$HOME/.claude/audit}"
mkdir -p "$dir" 2>/dev/null || exit 0
HOOK_INPUT="$(cat)"
export AUDIT_DIR="$dir" AUDIT_PROJECT="$(basename "${CLAUDE_PROJECT_DIR:-$(pwd)}")" HOOK_INPUT
python3 - <<'PY'
import datetime, json, os, re, sys

try:
    d = json.loads(os.environ.get("HOOK_INPUT") or "{}")
except Exception:
    sys.exit(0)

MASK = re.compile(r"(sk-ant-[A-Za-z0-9_\-]{8,}|AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9]{20,}|force://\S+|"
                  r"(?i:(?:password|secret|token|api[_-]?key)\s*[=:]\s*\S+)|Bearer\s+\S+)")
ti = d.get("tool_input", {}) or {}
tr = d.get("tool_response", {})
summary = ti.get("command") or ti.get("file_path") or ti.get("pattern") or ti.get("url") or ""
rec = {
    "ts": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
    "session": d.get("session_id", ""),
    "tool": d.get("tool_name", ""),
    "summary": MASK.sub("[MASKED]", str(summary))[:300],
    "ok": not (isinstance(tr, dict) and (tr.get("is_error") or tr.get("error"))),
}
day = datetime.date.today().strftime("%Y%m%d")
path = os.path.join(os.environ["AUDIT_DIR"], f'{os.environ["AUDIT_PROJECT"]}-{day}.jsonl')
with open(path, "a") as f:
    f.write(json.dumps(rec) + "\n")
PY
exit 0
