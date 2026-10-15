---
name: salesforce-conventions
description: House rules for writing Apex, triggers, flows, LWC, objects, fields and permission sets in this codebase. Use when creating or changing any Salesforce metadata, or reviewing it. For choosing the approach, use salesforce-solution-design first.
---
# Salesforce conventions

Choose the approach with `salesforce-solution-design`; this file is how to write it.

## Apex
- `with sharing` by default. `without sharing` needs a one-line justification comment.
- No SOQL or DML inside loops. Collect IDs, query once, use a `Map`.
- Everything must work for 200 records (trigger batch size). Test with exactly 200.
- One trigger per object; the trigger only delegates to a service/handler class.
- Enforce CRUD/FLS on user-facing reads and writes: `WITH USER_MODE` or `Security.stripInaccessible`.
- Bind variables in SOQL, never string concatenation. Use `Database.queryWithBinds` for dynamic SOQL.
- No hardcoded record IDs, org IDs, URLs or credentials. Use Custom Metadata or Named Credentials.
- Selective queries with `LIMIT` where the result is not naturally bounded; never query inside a
  constructor or getter that can run repeatedly.
- Async: Queueable for chained or callout work, Batch for very large sets, Schedulable only to
  enqueue. No `@future` in new code. Make async jobs idempotent and log failures.
- Callouts: Named Credentials, timeouts set, no callout in a loop, and handle non-2xx explicitly.
- Do not catch and swallow exceptions; either handle with a defined behavior or let them surface.

## Tests
- Assert behavior, not just "no exception". Cover positive, negative, bulk (200) and null.
- `@TestSetup` for shared data, or a test data factory class. Never `SeeAllData=true`.
- Test as a restricted user (`System.runAs`) for any code that enforces CRUD/FLS or sharing, and
  assert the denied case.
- Flows are tested through the DML that fires them (insert/update, then assert side effects).
- Mock callouts with `HttpCalloutMock`; no real network.
- Synthetic data only. Never copy real customer data into a test.

## Flows
- Prefer before-save record-triggered flows for same-record field updates (no DML cost).
- One record-triggered flow per object per timing where possible; use entry criteria and
  "only when record is changed to meet criteria" to avoid re-firing.
- Always add fault paths on create/update/delete elements, and no DML or Get Records in loops.
- New and changed flows must be `<status>Active</status>` in the metadata so they run as soon as
  they deploy. Never commit a flow as Draft, Obsolete or InvalidDraft; `verify.sh` fails on it.
- Name flows `Object_Action_Timing`; add a description saying what it does and why.

## Objects, fields and access
- New fields: API name follows existing naming, description filled in, no required-ness that would
  break existing integrations or data loads.
- Never change a field's type, API name or delete it as part of an automated change (Tier 3).
- Grant access through a permission set (new or existing), never a profile. Give the minimum
  object and field permissions needed; no `ModifyAllData`, `ViewAllData` or `ModifyAllRecords`.
- Validation rules: clear error message in business language; bypass via a custom permission,
  not a hardcoded user.
- Sharing model and sharing rules are Tier 2 or higher.

## LWC
- Base Lightning components and SLDS; no inline styles; no hardcoded labels (use Custom Labels).
- Wire adapters over imperative Apex where possible; handle loading and error states.
- Jest tests for logic and rendering of states; no `innerHTML` or `lwc:dom="manual"` with
  unsanitized data; `@AuraEnabled` methods enforce CRUD/FLS and return only needed fields.

## Delivery
- Source format (SFDX). Metadata goes through a PR; never edit production in Setup.
- Validate-only deploy plus `RunLocalTests` is the merge gate. Coverage threshold is enforced in CI.
- Destructive changes (`destructiveChanges.xml`) are Tier 3.
- Keep each PR to one change so rollback is a single revert.
