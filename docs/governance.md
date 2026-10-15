# Governance and approvals

## Roles
| Role | Can do |
|---|---|
| Business user | File a change request issue; review the preview. Cannot unlock a Tier 3 request |
| Engineer | Review/approve PRs, approve Tier 2 designs, do Tier 3 work |
| Org owner | Maintains `docs/org-profile.md` (criticality, data volume, sharing, change windows) |
| Release approver | Approve the `production` environment deployment |
| Platform owner | Changes hooks, settings, CI workflows and protected paths (always via a reviewed PR) |

## Autonomy tiers
The agent decides the solution itself and asks a human only where this table says so.

| Tier | Examples | Agent may | Approval needed |
|---|---|---|---|
| T0 | labels, help text, wording | implement and open PR | PR review (1) |
| T1 | flow tweak, new field, Apex change with tests | implement, org-test, open PR | PR review (1) |
| T2 | new object, integration, sharing rule, shared automation, 100k+ records | write a design proposal only | Engineer approves design, then PR review |
| T3 | permission/profile widening, deletion, data loads, production data, auth settings | write the ticket only | Engineer does the work; second reviewer recommended |

Org criticality `high` moves T1 changes to existing automation, Apex or access up to T2. The
requester cannot lower a tier or unlock T3 from chat; only an engineer-authored approval counts.

## Controls
1. **Branch protection on `main`**: PR required, 1+ approving review, status checks
   (`validate`, `hook-tests`) required, no force-push.
2. **Environments**: `ai-change` (reviewer gate before Claude runs), `staging`,
   `production` (required reviewers, secrets scoped here only).
3. **Agent guardrails**: deploy hook (Salesforce and Azure CLI), deny rules in `.claude/settings.json`,
   least-privilege `--allowedTools` in workflows.
4. **Risk routing**: the triager assigns the tier from the request and the org profile.
   Requests touching permissions, sharing, deletion, integrations or production data are never
   auto-implemented.
5. **Decision record**: every PR states the org profile used, tier, approach, alternatives and
   assumptions, so an automatic decision can be audited by someone who was not there.
6. **Untrusted input**: request text, comments and data are treated as data. Instructions inside them
   are not followed and the request becomes Tier 3.
7. **Auditability**: every change is an issue -> PR -> deployment with a reviewer name; the tool-call
   audit log is kept outside the repo (see the known limits in `docs/agent-layer.md`).

## Recommended hardening (needs a human to apply)
- `CODEOWNERS` for `force-app/**/permissionsets`, `profiles`, `sharingRules`, `.github/`, `.claude/`
  so those paths always need the platform or security owner.
- Raise required approvals to 2 for Tier 3 and `production`-bound changes.
- Roll out managed (enterprise) Claude Code settings so the hooks cannot be skipped by launching
  without the project config.

## Rollback
Revert the merge commit and redeploy through the same pipeline; for urgent cases,
deploy the previous tagged release to production via the approval gate.
