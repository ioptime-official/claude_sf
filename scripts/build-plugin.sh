#!/usr/bin/env bash
# Builds the installable Claude Code plugin from this repo's .claude/ layer.
#   scripts/build-plugin.sh           write plugin/agentic-governance/
#   scripts/build-plugin.sh --check   fail if the committed plugin is out of date
# Source of truth stays in .claude/ and scripts/. The plugin is generated, never hand-edited.
set -euo pipefail
cd "$(dirname "$0")/.."
name=agentic-governance
out="plugin/$name"
check=0; [ "${1:-}" = "--check" ] && check=1
dest="$out"; [ "$check" = 1 ] && dest="$(mktemp -d)/$name"

rm -rf "$dest"
mkdir -p "$dest/.claude-plugin" "$dest/agents" "$dest/commands" "$dest/skills" "$dest/hooks" "$dest/scripts"

cp .claude/agents/*.md "$dest/agents/"
cp .claude/commands/*.md "$dest/commands/"
cp -R .claude/skills/. "$dest/skills/"
if [ -d evals ]; then mkdir -p "$dest/evals"; cp -R evals/. "$dest/evals/"; rm -rf "$dest/evals/results"; fi
cp scripts/detect-stacks.py scripts/verify.sh "$dest/scripts/"
cp .claude/protected-paths.txt "$dest/protected-paths.txt"
for h in block-prod-deploy secret-guard protected-paths audit-log post-edit-lint stop-verify-gate session-context; do
  cp ".claude/hooks/$h.sh" "$dest/hooks/$h.sh"
done
chmod +x "$dest"/hooks/*.sh "$dest"/scripts/*

python3 - "$dest" <<'PY'
import json, os, sys

d = sys.argv[1]


def patch(path, edits):
    s = open(path).read()
    for old, new in edits:
        if old not in s:
            sys.exit(f"build-plugin: expected text not found in {path}: {old[:50]!r}")
        s = s.replace(old, new, 1)
    open(path, "w").write(s)


# 1. Hooks resolve helper scripts relative to the plugin and work on the PROJECT directory.
patch(f"{d}/hooks/stop-verify-gate.sh", [
    ("set -u\n", 'set -u\nPLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"\n'),
    ('cmd="bash scripts/verify.sh --changed"', 'cmd="bash ${PLUGIN_ROOT}/scripts/verify.sh --changed"'),
    ('cmd="bash scripts/verify.sh --changed --no-salesforce"', 'cmd="bash ${PLUGIN_ROOT}/scripts/verify.sh --changed --no-salesforce"'),
])
patch(f"{d}/hooks/protected-paths.sh", [
    ('root="${CLAUDE_PROJECT_DIR:-$(pwd)}"\n',
     'root="${CLAUDE_PROJECT_DIR:-$(pwd)}"\nexport PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"\n'),
    ('pf = os.path.join(root, ".claude", "protected-paths.txt")\nif not os.path.isfile(pf):\n    sys.exit(0)',
     'pf = os.path.join(root, ".claude", "protected-paths.txt")\nif not os.path.isfile(pf):\n'
     '    pf = os.path.join(os.environ.get("PLUGIN_ROOT", ""), "protected-paths.txt")\n'
     'if not os.path.isfile(pf):\n    sys.exit(0)'),
])
patch(f"{d}/hooks/session-context.sh", [
    ('echo "Helper scripts: $scripts (detect-stacks.py, verify.sh). Run them against the project directory."',
     'echo "Helper scripts: $scripts (detect-stacks.py, verify.sh). Wherever instructions say <scripts-dir>, use this directory. They run against the project directory."'),
])

# 2. Agents, commands and skills reference the helper scripts via the session-context directory.
note = "\n\n_`<scripts-dir>` is the helper-script directory announced in the session context._\n"
for sub in ("agents", "commands"):
    for fn in os.listdir(f"{d}/{sub}"):
        fp = f"{d}/{sub}/{fn}"
        t = open(fp).read()
        if "scripts/detect-stacks.py" in t or "scripts/verify.sh" in t:
            t = t.replace("scripts/detect-stacks.py", "<scripts-dir>/detect-stacks.py")
            t = t.replace("scripts/verify.sh", "<scripts-dir>/verify.sh")
            t = t.rstrip("\n") + note
            open(fp, "w").write(t)

# 3. Manifest and hook wiring using ${CLAUDE_PLUGIN_ROOT}.
with open(f"{d}/.claude-plugin/plugin.json", "w") as f:
    json.dump({
        "name": "agentic-governance",
        "version": "0.1.0",
        "description": "Governed AI-assisted change pipeline: guardrail hooks, a bounded verification loop, "
                       "review subagents and skills for Salesforce, .NET, React and WordPress repos.",
        "author": {"name": "Zeeshan Farooq"},
        "keywords": ["salesforce", "governance", "hooks", "code-review", "ci"],
    }, f, indent=2)
    f.write("\n")

R = "${CLAUDE_PLUGIN_ROOT}/hooks/"


def h(script, **kw):
    return {"type": "command", "command": '"' + R + script + '"', **kw}


with open(f"{d}/hooks/hooks.json", "w") as f:
    json.dump({"hooks": {
        "SessionStart": [{"hooks": [h("session-context.sh")]}],
        "PreToolUse": [
            {"matcher": "Bash", "hooks": [h("block-prod-deploy.sh"), h("protected-paths.sh")]},
            {"matcher": "Edit|Write|MultiEdit", "hooks": [h("protected-paths.sh"), h("secret-guard.sh")]},
        ],
        "PostToolUse": [
            {"matcher": "Edit|Write|MultiEdit", "hooks": [h("post-edit-lint.sh")]},
            {"matcher": "*", "hooks": [h("audit-log.sh")]},
        ],
        "Stop": [{"hooks": [h("stop-verify-gate.sh", timeout=600)]}],
    }}, f, indent=2)
    f.write("\n")
PY

cat > "$dest/README.md" <<'MD'
# agentic-governance (Claude Code plugin)

Generated from the source repo by `scripts/build-plugin.sh`; do not edit by hand.

- **Hooks**: block production deploys (Salesforce CLI and Azure CLI), secret scan on writes,
  protected paths (guardrails, CI, env files), audit log, bounded verification loop on Stop.
- **Agents**: apex-reviewer, code-reviewer, security-reviewer, test-writer, change-request-triager.
- **Commands**: /propose-change, /deploy-sandbox.
- **Skills**: salesforce-conventions, writing-change-requests, deployment-runbook.

Install (Claude Code 2.1.275+):

    /plugin install agentic-governance --marketplace ZeeshanFarooq0312/agentic-salesforce-pipeline

Works on any repo: stacks are discovered from file contents (`sfdx-project.json` package
directories, `.csproj`, React in `package.json`, WordPress plugin headers).
MD

if [ "$check" = 1 ]; then
  if diff -r -x results "$dest" "$out" >/dev/null 2>&1; then echo "plugin is up to date"
  else echo "plugin is stale: run scripts/build-plugin.sh" >&2; exit 1; fi
else
  echo "built $out"
fi
