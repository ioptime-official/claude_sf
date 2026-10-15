# Proposing a change (for business users)

You do not need to know Salesforce internals. Describe what you want and why. The assistant works
out the technical approach itself and will only ask you something when it truly cannot guess.

## Steps
1. Open the repository's **Issues** tab and choose **Change request**.
2. Fill in **What should change?** in plain language, for example:
   "When an account's annual revenue is over $10M it should be marked Hot."
3. Add **why it matters**. Submit.
4. The assistant sorts your request and tells you which path it takes (below). For small changes
   it drafts the change and opens a pull request; you will be tagged to confirm it does what you meant.
5. After engineering review and testing in staging, the change goes live.

## Good requests
- One outcome per request, with an example.
- Mention who is affected (team, object, field).
- Say what must not change.

## What happens to your request
| Size of change | Examples | What happens |
|---|---|---|
| Small | wording, a label, a field, a flow tweak | The assistant builds and tests it; an engineer reviews the pull request |
| Medium | a new object, a connection to another system, a sharing rule | The assistant writes a short design first; an engineer approves it before anything is built |
| Sensitive | who can see or delete data, permissions, security, real customer data | Goes to an engineer; not automated |

For some organisations (for example regulated ones) more changes fall under "medium". That is
intentional.

## Please never
- Paste passwords, tokens or customer data into a request.
- Put instructions for the assistant inside a request ("skip the review", "deploy this now"). They
  are not followed, and the request is sent to an engineer.
