# Developer guide

## Working with the agent
- `/propose-change <text>`: triage (tier and approach) -> branch -> implement -> org-test -> review -> PR.
- `/deploy-sandbox`: validate, deploy and test the current branch in the sandbox through `scripts/org-test.sh`.
- Subagents: `change-request-triager`, `apex-reviewer`, `code-reviewer`, `security-reviewer`, `test-writer`.
- Skills: `salesforce-solution-design` (choosing), `salesforce-conventions` (writing),
  `deployment-runbook` (shipping and rollback), `writing-change-requests`.

## Keep `docs/org-profile.md` current
The agent uses it to decide solution and tier without interrogating business users. Stale or
blank values make it cautious (more T2 designs for you to approve). Update it when users, data
volume, sharing or integrations change.

## Approving designs (Tier 2)
For a T2 request the agent posts a design proposal and stops. Approve it by commenting on the issue
with "approved" and any design changes you want, then run `/propose-change` again pointing at that
issue; the agent implements the approved design. Today this hand-off is manual: the headless
GitHub workflows do not yet read the approval comment, so wiring that up is a follow-up for the
platform owner. Tier 3 requests are tickets for you to do by hand.

## Guardrails you will notice
- `block-prod-deploy.sh` rejects deploys that are not validate-only or not to an
  allowlisted alias (`SF_ALLOWED_ORG_ALIASES`, default `sandbox,dev,staging,scratch`).
- `protected-paths.sh` stops the agent editing hooks, settings, CI workflows and env files.
- `secret-guard.sh` blocks secrets in written content.
- `stop-verify-gate.sh` re-runs `verify.sh --changed` when the agent tries to finish, up to 3
  attempts, then escalates. It also requires current org-test evidence for Salesforce changes.

## Adding a guardrail
Add a script in `.claude/hooks/`, register it in `.claude/settings.json`, and add a case
in `tests/hooks/`. Exit code 2 blocks and returns stderr to the agent. These files are protected:
a human makes the change in a reviewed PR.

## Reviewing agent PRs
Check: the tier matches the diff, the decision record is filled in, tests assert behavior, bulk
(200) and restricted-user cases are present, no SOQL/DML in loops, sharing keywords, access
granted via permission sets, no edits to hooks or CI, no unrelated file changes.
