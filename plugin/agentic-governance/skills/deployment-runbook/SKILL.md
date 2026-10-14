---
name: deployment-runbook
description: Promotion path, approval gates and rollback steps for releasing changes. Use when asked how a change reaches production, or when a release fails.
---
# Deployment runbook

## Promotion path
1. PR opened from an `ai/*` or feature branch. CI runs: verification, coverage gate, AI review.
2. **Org test** in a sandbox or Developer Edition org: `scripts/org-test.sh` validates, deploys and
   runs the Apex tests in the org, and records evidence tied to the exact source tested. CI also
   runs a validate-only deploy with `RunLocalTests`.
3. Human approval on the PR (required reviewer) and green `gate` status.
4. Merge to `main` triggers deploy to **staging**, then end-to-end tests.
5. **Production** deploy waits on the `production` Environment approval.

The agent stops at step 1. It never holds production credentials.

## If validation fails
- Read the first failing component and test; fix at the source, re-run the verify script on changed stacks.
- Three failed attempts: the loop escalates to a human. Do not retry blindly.

## Rollback
1. Revert the merge commit on `main` (`git revert -m 1 <sha>`), open a PR, approve.
2. The pipeline redeploys the reverted source through the same gates.
3. Urgent: redeploy the previous tagged release via the `production` approval gate.
4. Data changes made by the release are not undone by a metadata rollback; list them in the PR.

## Evidence to keep
Deploy ID, test results, coverage, approver name, and the audit log entries for the session.
