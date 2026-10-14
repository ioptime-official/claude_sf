#!/usr/bin/env bash
# Runs the full local stack and the cross-system Playwright spec against your dev org.
#   scripts/run-e2e-local.sh [org-alias]      (default alias: dev)
# Needs: dotnet 8 SDK, npm, curl, and these exported in your shell (never commit them):
#   SF_INSTANCE_URL     My Domain URL (falls back to `sf org display` if the CLI is available)
#   SF_CLIENT_ID        Connected/External Client App consumer key (client-credentials flow)
#   SF_CLIENT_SECRET    its consumer secret
# The Salesforce CLI redacts access tokens, so this uses the same OAuth client-credentials
# flow as CI instead of extracting a session token.
set -euo pipefail
cd "$(dirname "$0")/.."
org="${1:-dev}"
export PATH="$HOME/.dotnet:$PATH"

for c in dotnet npm curl; do command -v "$c" >/dev/null || { echo "missing: $c" >&2; exit 1; }; done

if [ -z "${SF_INSTANCE_URL:-}" ] && command -v sf >/dev/null && command -v jq >/dev/null; then
  SF_INSTANCE_URL="$(sf org display --target-org "$org" --json | jq -r '.result.instanceUrl')"
fi
: "${SF_INSTANCE_URL:?set SF_INSTANCE_URL}" "${SF_CLIENT_ID:?set SF_CLIENT_ID}" "${SF_CLIENT_SECRET:?set SF_CLIENT_SECRET}"
export SF_INSTANCE_URL SF_CLIENT_ID SF_CLIENT_SECRET
export AllowedOrigin="http://localhost:5173"
export REACT_URL="http://localhost:5173"
export VITE_API_URL="http://localhost:5000"

pids=()
cleanup() { for p in "${pids[@]:-}"; do kill "$p" 2>/dev/null || true; done; }
trap cleanup EXIT

echo "==> Starting .NET API on :5000"
ASPNETCORE_URLS="http://localhost:5000" dotnet run --project apps/dotnet-api/src/Api >/tmp/e2e-api.log 2>&1 &
pids+=($!)

echo "==> Starting React on :5173"
(cd apps/react-web && npm install --no-audit --no-fund >/dev/null && npx vite --port 5173 --strictPort >/tmp/e2e-web.log 2>&1) &
pids+=($!)

echo "==> Waiting for services"
for url in http://localhost:5000/health http://localhost:5173; do
  for _ in $(seq 1 60); do curl -fs "$url" >/dev/null 2>&1 && break; sleep 1; done
  curl -fs "$url" >/dev/null || { echo "service did not start: $url (see /tmp/e2e-*.log)" >&2; exit 1; }
done

echo "==> Playwright"
npm install --no-audit --no-fund >/dev/null
npx playwright install chromium >/dev/null
npx playwright test tests/e2e/account-wizard.spec.ts
