# The agent layer: what it is, why it is built this way

This is the part of the repo that makes AI-assisted change safe to run in a client codebase.
The Salesforce, .NET, React and WordPress code is only a fixture to prove it works.

## Design principles
1. **The agent proposes; the pipeline disposes.** The agent edits source and opens a PR. It
   never deploys to production and never holds production credentials.
2. **Controls are enforced by the harness, not requested in a prompt.** A prompt can be
   ignored. A hook that exits non-zero cannot.
3. **Nothing assumes the client's layout.** Stacks are discovered from file contents.
4. **Every control has a test**, and the tests are the proof, not the description.

## Controls

| Control | Mechanism | Stops | Tests |
|---|---|---|---|
| Production deploy block | PreToolUse hook on Bash | `sf`/`sfdx`/`az` deploys that are not validate-only or not aimed at an allowlisted sandbox or non-production slot | 16 |
| MCP deploy denied | `permissions.deny` plus `--orgs` scoped to the sandbox alias | The Salesforce MCP server being used to bypass the Bash hook | config |
| Secret guard | PreToolUse on file writes | API keys, SFDX auth URLs, private keys, hardcoded credentials landing in the repo. Reports the pattern and line, never the value | 7 |
| Protected paths | PreToolUse on file writes and Bash | The agent editing its own hooks and settings, CI workflows or env files | 8 |
| Audit log | PostToolUse on every tool | Nothing; gives a record of every tool call, secrets masked, stored outside the repo | 2 |
| Verification loop | Stop hook | The agent declaring "done" while tests fail. Bounded to 3 attempts, then escalates to a human | 8 |
| Org test before finishing | `scripts/org-test.sh` plus an evidence check in `verify.sh` | Salesforce changes being finished without being validated, deployed and tested in a sandbox or Developer Edition org. Refuses any other org type. Evidence is tied to a fingerprint of the source, so edits after testing invalidate it | 15 |
| Instant lint | PostToolUse on edits | Syntax errors in PHP/JSON/XML caught on the edit rather than at CI | |
| Session context | SessionStart | Agents guessing paths: injects discovered stacks and script locations | |

## The verification loop
```
agent tries to finish
        |
   code changed? --no--> allow
        | yes
   scripts/verify.sh --changed
        |
   pass --> allow            fail --> block, show failures (attempt n of 3)
                                          |
                                  n == 3 --> allow + ESCALATE message to a human
```
- State (the attempt counter) lives **outside the repo**. Inside the repo it would count as a
  code change and keep the gate firing. A test caught this.
- Counters are per session, so two sessions do not interfere.
- Docs-only changes are not gated.

## Testing in the org
Reviews and unit tests are not enough for Salesforce: governor limits, triggers, flows and
sharing only show up in a real org. So `scripts/org-test.sh`:

1. asks the org what it is (`IsSandbox`, `OrganizationType`), and refuses to deploy to
   anything that is not a sandbox or a Developer Edition org (validate-only is allowed anywhere);
2. validates the source, then deploys it, then runs the Apex test suite **in the org** and reads
   each test result back, so the PR carries real deploy IDs, per-test outcomes and coverage;
3. stops at the first failing stage, so a failed validate never reaches deploy;
4. records evidence tied to a fingerprint of the package directories. The Stop hook (through
   `verify.sh --changed`) rejects "done" if Salesforce files changed and there is no matching
   evidence, and also if the code changed after the last org test. CI is exempt because it runs
   its own validate and coverage gates.

It retries a validate or test run once on a transient network error. It never retries a deploy.
Known limit: the evidence is a file the script writes, so an agent that forges it would pass the
local check. The CI re-run and branch protection are the real backstop.

## Stack discovery
`scripts/detect-stacks.py` reads `sfdx-project.json` for Salesforce package directories and
looks for `.csproj` files, React in `package.json`, and WordPress plugin headers. It skips
`node_modules`, `bin`, `obj`. Test coverage includes a layout with non-standard folder names.

## Decision policy: how the agent chooses without asking
The controls above say what the agent cannot do. The decision policy says how it chooses within
them, so business users are not asked technical questions.

1. **Org profile.** `docs/org-profile.md` (human-owned) plus facts discovered from the repo:
   criticality, users, sharing model, data volume, existing automation, integrations. Unknown means
   the cautious default, stated as an assumption.
2. **Solution defaults** (`salesforce-solution-design`): declarative before code, permission sets
   not profiles, extend existing automation, async only when volume or callouts need it.
3. **Autonomy tiers** T0-T3 (`docs/governance.md`). `high` criticality raises T1 changes to
   existing automation, Apex or access to T2. T3 cannot be unlocked by the requester.
4. **Ask a human only** for T2/T3 approval, a materially ambiguous request the org facts cannot
   settle, or a missing fact that makes the change pointless.
5. **Decision record** in every PR so the automatic choice can be audited.
6. **Untrusted input.** Request text and data are never instructions.

This policy is enforced by instruction, the triager's output and reviewer checks, not by a hook.
The hard limits (production, secrets, protected paths, verification) remain hook-enforced. The tier
behavior is covered by evals in `evals/`, which score the triager's Tier and Route.

## Subagents and skills
- **Reviewers**: `apex-reviewer`, `code-reviewer`, `security-reviewer` (read-only tools).
- **Builders**: `test-writer`, `change-request-triager`.
- **Skills**: `salesforce-solution-design`, `salesforce-conventions`, `writing-change-requests`, `deployment-runbook`.
- Reviewers get read-only tools on purpose: a reviewer that can edit will "fix" things it was
  asked to judge.

## Distribution
`scripts/build-plugin.sh` generates `plugin/agentic-governance/` (a Claude Code plugin) from
the same source, rewriting paths so hooks resolve relative to the plugin and operate on the
client's project directory. `--check` fails CI if the generated plugin is stale. A test runs the
plugin's hooks against a throwaway repo with a layout unlike this one.

## Evals
`evals/` holds nine golden cases for the triager: risky permission change, integration,
production-data deletion, ambiguous request, trivial label change, a regression case for a
low-risk flow edit, the same new-field request in a low- and a high-criticality org (the tier must
differ), and a request that carries embedded instructions for the agent. Each checks the triager's
**Route** (`implement`, `clarify` or `escalate`) and, for the new cases, its **Tier**.
Run them with `claude plugin eval plugin/agentic-governance --runs 1 --no-publish`; they score
the plugin against a no-plugin baseline.

Latest results: all nine cases pass with the plugin at 3 runs each (the earlier run caught the triager rating an integration as medium risk, which was fixed). In the first, partly interrupted run the no-plugin baseline scored 0 on every case except one 0.33. The no-plugin baseline fails them all, which is the
expected result because the baseline has no triager (mean uplift about +0.9, under $1.50 per full run).
One run per case is a smoke signal, not a statistic; use `--runs 3` or more before quoting scores.

### What the first live use taught us
A live `/propose-change` on a one-line flow edit was stopped and sent to an engineer queue even
though the triager rated it low risk. Two flaws: "needs engineer review" meant PR review in one
place and "do not implement" in another, and formatting questions were treated as blockers. The
fix was a three-way Route with separate Assumptions (non-blocking) and Blocking questions, and
a regression eval built from the real request.

The same case then failed once for a different reason: the eval ran in an isolated folder with
no repo, so the triager correctly said the flow did not exist. Repository context is now stated
in the eval prompt. Lesson: when an eval fails, check the harness before the prompt.

## What this does not do (known limits)
- **The Bash protection is best-effort.** Protected-paths matches a write verb plus a
  protected path in the command text. A determined agent can obfuscate a command. Treat it as
  a tripwire plus an audit trail; the hard boundary is that production credentials are not
  available to the agent at all, and branch protection requires human approval.
- **Heuristics have false positives.** `cp <protected-file> <elsewhere>` (a read) is blocked.
  Tighten to "protected path is the destination" if that gets in the way.
- **Hooks are only as good as the environment that runs them.** A user who launches Claude
  Code without the project settings, or with a different config, is not covered. Managed
  settings (enterprise policy) close that gap and should be used for a real rollout.
- **Salesforce validation needs an authenticated org.** The Stop hook skips it by default
  (`VERIFY_SALESFORCE=1` turns it on) because it takes about 35 seconds.
- **The headless GitHub workflows have not run on GitHub's runners yet** (account billing lock).
  Their logic is exercised locally.

- **The audit log only records tool calls that succeeded.** It is a PostToolUse hook, and a
  failed command (non-zero exit, a blocked call) never reaches it. Found in the first live run:
  a failed verify and the commit-and-push command were missing from the log. The fix is to also
  register the failure event and to log denials from the blocking hooks. Until then, treat the log
  as "what worked", not "everything the agent tried".
- **Secret scan and lint only see the Edit and Write tools.** An agent that changes a file with
  `sed -i` or a shell heredoc through Bash skips both. The first live run edited the flow that
  way. Scanning staged changes in a pre-commit step closes this regardless of how files change.
- **The agent pushed its branch to the repository's default remote without being asked.** That
  is normal for opening a PR but should target the designated remote deliberately.

## Changing a protected file
The agent cannot. A human edits it in a reviewed PR, or launches Claude Code with
`ALLOW_PROTECTED_EDIT=1` for a deliberate session. This is intentional.
