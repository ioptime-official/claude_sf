---
name: deployment-runbook
description: Promotion path, approval gates, rollback and hotfix steps for releasing changes. Use when asked how a change reaches production, or when a release or validation fails.
---
# Deployment runbook

## Promotion path
1. PR opened from an `ai/*` or feature branch. CI runs: verification, coverage gate, AI review.
2. **Org test** in a sandbox or Developer Edition org: `scripts/org-test.sh` validates, deploys and
   runs the Apex tests in the org, and records evidence tied to the exact source tested. CI also
   runs a validate-only deploy with `RunLocalTests`.
3. Human approval on the PR (required reviewer) and green `gate` status. Approval depth follows
   the tier: T0/T1 one reviewer; T2 the approved design plus one reviewer; T3 is done by an
   engineer and should get a second reviewer (branch protection only enforces one today; raise it
   or use CODEOWNERS to make this binding).
4. Merge to `main` triggers deploy to **staging**, then end-to-end tests.
5. **Production** deploy waits on the `production` Environment approval.

The agent stops at step 1. It never holds production credentials.

## Before asking for production approval
- The PR has the decision record, the org-test report and a rollback line.
- Anything the metadata deploy cannot carry is listed: data fixes, manual Setup steps, record
  type or app assignments, scheduled job activation, and the order they run in.
- The release does not combine a data change with a metadata change unless rollback for both is written.
- Deploy outside business hours for `high` criticality orgs, or when the change touches shared automation.

## If validation fails
- Read the first failing component and test; fix at the source, re-run the verify script on changed stacks.
- Common causes: missing dependency in the package directory, a test that depends on org data,
  coverage below the gate, a flow deployed as Draft, an API version mismatch.
- Three failed attempts: the loop escalates to a human. Do not retry blindly or against another org.

## Rollback
1. Revert the merge commit on `main` (`git revert -m 1 <sha>`), open a PR, approve.
2. The pipeline redeploys the reverted source through the same gates.
3. Urgent: redeploy the previous tagged release via the `production` approval gate.
4. Data changes made by the release are not undone by a metadata rollback; list them in the PR.
5. Metadata that cannot be reverted by redeploy (deleted fields, changed field types) is why those
   changes are Tier 3 and need a data backup plan from an engineer first.

## Hotfix
A production incident does not change who deploys. An engineer opens a PR from a `hotfix/*` branch;
the same gates run with the full tests; the `production` approver may approve on a shortened
review. The agent may draft the fix and tests on the branch (T1 rules) but never deploys it.

## Evidence to keep
Deploy ID, test results, coverage, approver name, the decision record, and the audit log entries
for the session.
