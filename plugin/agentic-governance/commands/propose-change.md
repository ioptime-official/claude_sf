---
description: Propose a change in plain English (for non-technical users)
argument-hint: <describe the change you want>
---
A business user wants this change: $ARGUMENTS

Follow this process exactly:

1. Use the `change-request-triager` subagent to produce a structured request, and show it to the
   user in plain language. Then act on its **Route**:
   - **escalate**: do NOT implement. Open a GitHub issue using the change-request template (or,
     if `gh` is unavailable, give the user ready-to-paste issue text) and say an engineer will
     pick it up. The user may explicitly override this by naming the risk and telling you to
     proceed; only then continue.
   - **clarify**: ask only the blocking questions, then re-triage with the answers.
   - **implement**: continue. List the Assumptions to the user in one short line; do not ask for
     permission on assumptions. Proceed unless the user objects.
2. Create a branch `ai/<short-slug>` and implement the change with matching tests. Use
   `python3 <scripts-dir>/detect-stacks.py` to find where each stack lives; never assume folder names.
3. Verify: `bash <scripts-dir>/verify.sh --changed`. If you changed Salesforce code, also run
   `bash <scripts-dir>/org-test.sh` (validate, deploy and test in the sandbox or Developer org) and keep
   its report for the PR. Fix failures and re-run. The Stop hook will also hold
   you to this and escalates to a human after repeated failures, so do not try to bypass it.
4. Review the result: `apex-reviewer` for Salesforce changes, `code-reviewer` for other stacks, and
   `security-reviewer` always. Fix blockers.
5. If you changed rating thresholds anywhere, change all three stacks together (see CLAUDE.md).
6. Open a pull request using the PR template (or give the exact commands to do so). List the
   Assumptions and the org-test report in the PR description. Never merge it and never deploy; CI and a human approval
   gate handle that.
7. Reply in plain language: what changed, how to preview it, and what happens next.

_`<scripts-dir>` is the helper-script directory announced in the session context._
