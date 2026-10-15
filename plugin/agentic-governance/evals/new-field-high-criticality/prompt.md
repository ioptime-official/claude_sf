---
max_turns: 12
allowed_tools: [Read, Glob, Grep, Agent]
---

A business user submitted this change request. Use the change-request-triager agent to triage it
and reply with the triager's structured result only.

Repository and org context (the triage runs in an isolated folder, so this is stated rather than read):
the Salesforce source is in `force-app/`. Org profile: criticality high (regulated financial services, about 2,000 users,
customer financial data), Account has about 1.5 million records. The active record-triggered flow
`Hot_Account_Follow_Up` on Account already exists and the change below would be added to it.

Request: "When an account becomes Hot, also copy the account's annual revenue into a new 'Revenue At Hot' field on the follow-up task."
