# agentic-salesforce-pipeline

An AI-assisted, governed development pipeline for Salesforce (pattern extends to
.NET, React, WordPress and Azure). Business users propose changes in plain English;
Claude Code drafts them; engineers and CI gate what ships.

## What is here
| Piece | Where |
|---|---|
| Project rules for the agent | [CLAUDE.md](CLAUDE.md) |
| Hooks (guardrails, verification loop) | [.claude/hooks/](.claude/hooks/) |
| Subagents | [.claude/agents/](.claude/agents/) |
| Slash commands | [.claude/commands/](.claude/commands/) |
| MCP servers | [.mcp.json](.mcp.json) |
| Skills, evals | [.claude/skills/](.claude/skills/), [evals/](evals/) |
| Installable plugin | [plugin/agentic-governance/](plugin/agentic-governance/) |
| How the agent layer works | [docs/agent-layer.md](docs/agent-layer.md) |
| Headless CI workflows | [.github/workflows/](.github/workflows/) |
| Sample apps (.NET, React, WordPress) | [apps/](apps/) |
| Azure DevOps pipeline | [azure-devops/](azure-devops/) |
| E2E tests | [tests/e2e/](tests/e2e/) |
| Docs | [docs/](docs/) |

See [docs/architecture.md](docs/architecture.md) for the flow diagram.

## Try it
```bash
npm run test:agent-layer   # prove every guardrail and the plugin work
```
