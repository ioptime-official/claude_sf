---
name: salesforce-conventions
description: House rules for writing Apex, triggers, flows and LWC in this codebase. Use when creating or changing any Salesforce metadata, or reviewing it.
---
# Salesforce conventions

## Apex
- `with sharing` by default. `without sharing` needs a one-line justification comment.
- No SOQL or DML inside loops. Collect IDs, query once, use a `Map`.
- Everything must work for 200 records (trigger batch size). Test with exactly 200.
- One trigger per object; the trigger only delegates to a service/handler class.
- Enforce CRUD/FLS on user-facing reads and writes: `WITH USER_MODE` or `Security.stripInaccessible`.
- Bind variables in SOQL, never string concatenation.
- No hardcoded record IDs, org IDs, URLs or credentials. Use Custom Metadata or Named Credentials.

## Tests
- Assert behavior, not just "no exception". Cover positive, negative, bulk (200) and null.
- `@TestSetup` for shared data. Never `SeeAllData=true`.
- Flows are tested through the DML that fires them (insert/update, then assert side effects).

## Flows
- Prefer before-save record-triggered flows for same-record field updates (no DML cost).
- One record-triggered flow per object per timing where possible; use entry criteria and
  "only when record is changed to meet criteria" to avoid re-firing.
- Always add fault paths on create/update/delete elements.

## LWC
- Base Lightning components and SLDS; no inline styles; no hardcoded labels (use Custom Labels).
- Wire adapters over imperative Apex where possible; handle loading and error states.

## Delivery
- Source format (SFDX). Metadata goes through a PR; never edit production in Setup.
- Validate-only deploy plus `RunLocalTests` is the merge gate. Coverage threshold is enforced in CI.
