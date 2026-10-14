---
description: Propose a change in plain English (for non-technical users)
argument-hint: <describe the change you want>
---
A business user wants this change: $ARGUMENTS

Follow this process exactly:

1. Use the `change-request-triager` subagent to produce a structured request. Show it to the user and ask for confirmation. Stop here if it lists open questions.
2. If Risk is high or Needs engineer review is yes, do NOT implement. Open a GitHub issue using the change-request template and tell the user an engineer will pick it up.
3. Otherwise create a branch `ai/<short-slug>` and implement the change with matching tests. Use `python3 <scripts-dir>/detect-stacks.py` to find where each stack lives; never assume folder names.
4. Verify: `bash <scripts-dir>/verify.sh --changed`. Fix failures and re-run. The Stop hook will also hold you to this and escalates to a human after repeated failures, so do not try to bypass it.
5. Review the result: `apex-reviewer` for Salesforce changes, `code-reviewer` for other stacks, and `security-reviewer` always. Fix blockers.
6. If you changed rating thresholds anywhere, change all three stacks together (see CLAUDE.md).
7. Open a pull request using the PR template. Never merge it and never deploy; CI and a human approval gate handle that.
8. Reply in plain language: what changed, how to preview it, and what happens next.

_`<scripts-dir>` is the helper-script directory announced in the session context._
