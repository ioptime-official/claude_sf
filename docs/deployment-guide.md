# Deployment guide

## One-time setup
0. Use Node 22 or newer for the Salesforce CLI (`nvm install 22`); Node 20 crashes recent CLI releases.
1. Create a Dev Hub (or use a sandbox) and authenticate: `sf org login web --alias sandbox`.
2. Get its auth URL: `sf org display --target-org sandbox --verbose` and store as
   GitHub secret `SF_SANDBOX_AUTH_URL`. Repeat for `SF_STAGING_AUTH_URL`, `SF_PROD_AUTH_URL`.
3. Add ONE Claude credential as a repo secret, plus `SF_STAGING_URL` (for Playwright):
   - `CLAUDE_CODE_OAUTH_TOKEN`: run `claude setup-token` locally (needs a Claude Pro/Max
     subscription). Good for personal/portfolio use; usage counts against your plan limits.
   - `ANTHROPIC_API_KEY`: from the Anthropic Console, pay-as-you-go. Preferred for team CI.
4. Create GitHub Environments `ai-change`, `staging`, `production`; add required reviewers.
5. Enable branch protection on `main`: `bash scripts/setup-branch-protection.sh <owner/repo>`
   (requires PR, 1 approval, and the always-on `gate` status from `ci-gate.yml`).

## Day to day
| Event | What runs |
|---|---|
| Issue labeled `ai-change` | Claude implements on a branch and opens a PR |
| PR opened/updated | Claude review + validate-only deploy to sandbox |
| Merge to `main` | Deploy to staging, then E2E, then production after approval |

## Local development
```bash
bash scripts/setup-scratch-org.sh
sf apex run test --test-level RunLocalTests --target-org scratch
npm install && npx playwright test
bash tests/hooks/test-block-prod-deploy.sh
```
