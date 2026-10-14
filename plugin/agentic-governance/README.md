# agentic-governance (Claude Code plugin)

Generated from the source repo by `scripts/build-plugin.sh`; do not edit by hand.

- **Hooks**: block production deploys (Salesforce CLI and Azure CLI), secret scan on writes,
  protected paths (guardrails, CI, env files), audit log, bounded verification loop on Stop.
- **Agents**: apex-reviewer, code-reviewer, security-reviewer, test-writer, change-request-triager.
- **Commands**: /propose-change, /deploy-sandbox.
- **Skills**: salesforce-conventions, writing-change-requests, deployment-runbook.

Install (Claude Code 2.1.275+):

    /plugin install agentic-governance --marketplace ZeeshanFarooq0312/agentic-salesforce-pipeline

Works on any repo: stacks are discovered from file contents (`sfdx-project.json` package
directories, `.csproj`, React in `package.json`, WordPress plugin headers).
