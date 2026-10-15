## Summary
<!-- What changed and why, in plain language. -->

## Decision record
- **Org profile used** (criticality / org type / data volume / sharing; stated, found or assumed):
- **Tier** (T0-T3) and why, including any criticality adjustment:
- **Chosen approach** (declarative vs code, and the reason):
- **Alternatives rejected**:
- **Assumptions** (defaults chosen without asking):
- **Approved design / approver** (required for T2):

## Test evidence
<!-- Salesforce: org-test report (org name and type, validate and deploy IDs, each test, coverage). -->
<!-- Other stacks: verify.sh output. State any check that was skipped and why. -->

## Risk / rollback
- **Risk** (low / medium / high) and who is affected:
- **Rollback** (usually: revert this PR):
- **Not covered by a metadata rollback** (data changes, manual Setup steps, job activation):

## Reviewer checklist
- [ ] Tier matches the diff (no permission, sharing, deletion, data or auth change in a T0/T1 PR)
- [ ] No edits to hooks, settings, CI workflows or env files unless a human authored them
- [ ] Tests assert behavior; bulk (200) and denied-access cases present where relevant
- [ ] No secrets or real customer data in code, tests, or this description
