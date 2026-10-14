# agentic-salesforce-pipeline

<!-- DRAFT: rewrite the rules below in your own words before showing this to anyone. -->

An AI-assisted, governed change pipeline. Claude proposes changes; hooks, CI and humans
decide what ships. This file must work in any client repo, so it never assumes folder names.

## Hard rules
- NEVER deploy to production or to any org/slot not on the allowlist. The PreToolUse hook
  enforces this (Salesforce and Azure CLI). Do not work around it. Production deploys happen
  only in CI behind a GitHub Environment approval.
- Never commit secrets, auth URLs, tokens or `.sfdx/` / `.sf/` contents. Do not try to
  extract access tokens from the Salesforce CLI; it redacts them on purpose.
- Work on a branch named `ai/<short-slug>`; never push to `main`.
- Every production-code change needs a test change in the same PR.

## Stack discovery (do this first, never assume paths)
Run `python3 scripts/detect-stacks.py`. It reports, from file contents:
- Salesforce package directories (from `sfdx-project.json`)
- .NET service roots and test projects, React apps, WordPress plugins/themes

Use those paths in every command and review. Do not hardcode `force-app/` or `apps/`.

## The verification loop
- Verify with `bash scripts/verify.sh --changed` (add `--full` for builds, `--only <stack>`
  for one stack). It runs the right checks per discovered stack.
- A Stop hook re-runs verification when you try to finish with code changes. If it fails you
  are sent back to fix it, at most 3 times; after that it escalates to a human. Do not
  suppress, edit or bypass the hook to get out of the loop.
- Salesforce validation is validate-only (no deploy) against the sandbox alias.

## Conventions
- **Apex**: `with sharing` by default; no SOQL/DML in loops; bulk-safe for 200 records;
  one trigger per object with logic in a service class; tests assert behavior.
- **LWC**: base Lightning components, SLDS, no inline styles.
- **.NET**: validate request models, no secrets in config files, typed HTTP clients.
- **React**: no secrets in `VITE_*` variables, tests with Testing Library.
- **WordPress**: escape output, nonces and capability checks, `$wpdb->prepare`.

## Guardrails you will meet
Production deploys, secrets in written content, and edits to guardrails, CI workflows or env
files are blocked by hooks. They are not suggestions; do not look for ways around them. If a
block is wrong, say so and a human will change the rule.

## Review agents
`apex-reviewer` (Salesforce), `code-reviewer` (.NET/React/WordPress/CI), `security-reviewer`
(every PR), `test-writer` (missing tests), `change-request-triager` (business requests).

## Cross-stack invariant (this demo)
Rating thresholds (>= 10,000,000 Hot, >= 1,000,000 Warm, else Cold) are identical in Apex
(`AccountService`), C# (`RatingService`) and PHP (`acct_rating_for`). Change all together.

## Commands
- Agent-layer tests: `npm run test:agent-layer`
- Rebuild the plugin after changing the agent layer: `npm run build:plugin`
- Everything except the org: `npm run verify`
- Change request, locally: `bash scripts/run-change-request.sh "<request>"`
