# Org profile

The agent reads this file to choose solutions and set autonomy tiers without asking the business
user technical questions. A human owns it and keeps it current; the agent never edits it. Anything
left blank is treated cautiously (see the `salesforce-solution-design` skill). Do not put secrets,
auth URLs or customer data here.

| Field | Value | Notes |
|---|---|---|
| Criticality | standard | `low` (internal, small, no sensitive data), `standard`, or `high` (regulated, customer/financial/health data, or 500+ active users). `high` pushes changes to existing automation up one tier |
| Org edition and type | | e.g. Enterprise, production with a full sandbox named `staging` |
| Sandbox alias for agent testing | dev | Must be on the hook allowlist (`SF_ALLOWED_ORG_ALIASES`) |
| Active users (approx.) | | |
| Key roles / permission sets | | |
| Sharing model (OWD) | | e.g. Account: Private |
| Largest objects (records) | | e.g. Account 1.2M, Case 8M. Over 100k means T2 for logic that touches them |
| Sensitive data present | | e.g. none, PII, financial, health |
| Integrations | | Named Credentials and systems on the other side |
| Change windows | | e.g. no production releases Mon-Fri 08:00-18:00 |
| Release approver(s) | | Who approves the `production` Environment |
| Compliance notes | | e.g. SOX change record, GDPR retention |
