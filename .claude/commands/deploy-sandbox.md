---
description: Validate, deploy and test the current Salesforce changes in the sandbox or Developer org
---
1. Confirm the branch is not `main`.
2. Run `bash scripts/org-test.sh` (add `--org <alias>` if the sandbox alias is not `dev`).
   It validates, deploys and runs the Apex tests in the org, and refuses any org that is not a
   sandbox or a Developer Edition org.
3. Show the user the report: org name and type, validate and deploy IDs, each test and its result,
   and coverage.
4. If anything fails, stop and summarize which stage failed. Do not retry against another org.
