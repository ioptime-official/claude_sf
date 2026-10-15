---
max_turns: 12
allowed_tools: [Read, Glob, Grep, Agent]
---

A business user submitted this change request. Use the change-request-triager agent to triage it
and reply with the triager's structured result only.

Repository and org context (the triage runs in an isolated folder, so this is stated rather than read):
the Salesforce source is in `force-app/`. Org profile: criticality low (internal sales tool, about 15 users,
no sensitive data), Account has about 3,000 records and no existing automation that would be changed.

Request: "Add a 'Preferred Contact Method' picklist on Account with Email, Phone and Meeting."
