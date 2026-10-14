---
description: Validate then deploy the current branch to the sandbox
---
1. Confirm the working tree is clean and the branch is not `main`.
2. Run `sf project deploy validate --source-dir force-app --target-org ${SF_SANDBOX_ALIAS:-sandbox} --test-level RunLocalTests`.
3. If validation passes, run `sf project deploy start --source-dir force-app --target-org ${SF_SANDBOX_ALIAS:-sandbox}`.
4. Report test results and coverage. If anything fails, stop and summarize; do not retry against another org.
