#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash). Blocks deploys that could reach production:
#   - Salesforce (sf / sfdx): must be validate-only or target an allowlisted sandbox alias
#   - Azure CLI (az webapp/functionapp/deployment ...): must be what-if or target a non-prod slot
# Exit 2 = block and feed stderr back to Claude. Exit 0 = allow.
set -u

ALLOWED="${SF_ALLOWED_ORG_ALIASES:-sandbox,dev,staging,scratch}"
input="$(cat)"

if command -v jq >/dev/null 2>&1; then
  cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty')"
else
  cmd="$(printf '%s' "$input" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("tool_input",{}).get("command",""))')"
fi

block() { echo "BLOCKED by block-prod-deploy hook: $1" >&2; exit 2; }

# ---------- Azure CLI ----------
if printf '%s' "$cmd" | grep -Eq '(^|[;&|[:space:]])az[[:space:]]+(webapp[[:space:]]+(deploy|deployment)|functionapp[[:space:]]+(deploy|deployment)|staticwebapp[[:space:]]+deploy|deployment[[:space:]]+(group|sub|mg|tenant)[[:space:]]+create|containerapp[[:space:]]+(up|update))'; then
  if printf '%s' "$cmd" | grep -Eq -- '--what-if|[[:space:]]what-if([[:space:]]|$)|--dry-run'; then
    exit 0
  fi
  slot="$(printf '%s' "$cmd" | sed -nE 's/.*--slot[ =]+([^ ]+).*/\1/p' | head -n1 | tr '[:upper:]' '[:lower:]')"
  [ -n "$slot" ] || block "az deploy has no --slot; it would hit the production slot. Use --what-if or --slot staging."
  case "$slot" in prod|production|live) block "az deploy targets production slot '$slot'.";; esac
  exit 0
fi

# ---------- Salesforce ----------
if ! printf '%s' "$cmd" | grep -Eq '(sf|sfdx)[[:space:]]+(project[[:space:]]+deploy|force:(source|mdapi):deploy)'; then
  exit 0
fi

# Validate-only / dry-run is always safe.
if printf '%s' "$cmd" | grep -Eq 'deploy[[:space:]]+validate|--dry-run|--checkonly'; then
  exit 0
fi

org="$(printf '%s' "$cmd" | sed -nE 's/.*(--target-org|--targetusername|[[:space:]]-o|[[:space:]]-u)[ =]+([^ ]+).*/\2/p' | head -n1)"
[ -n "$org" ] || block "deploy has no explicit --target-org; default org may be production. Use --dry-run or specify an allowlisted sandbox alias ($ALLOWED)."

lower="$(printf '%s' "$org" | tr '[:upper:]' '[:lower:]')"
case "$lower" in *prod*|*production*|*live*) block "target org '$org' looks like production.";; esac

IFS=',' read -ra ok <<<"$ALLOWED"
for a in "${ok[@]}"; do [ "$lower" = "$a" ] && exit 0; done
block "target org '$org' is not in the sandbox allowlist ($ALLOWED)."
