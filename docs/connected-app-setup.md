# Salesforce API access for the .NET API and E2E tests

Service-to-service calls use the OAuth 2.0 **client-credentials flow**: no user password,
no session token copied from a browser, and the secret lives only in environment
variables / a secret store.

## One-time setup in the org (Developer Edition or sandbox)
1. Setup -> **App Manager** -> **New Connected App** (or **External Client App Manager** in
   newer orgs). Name: `Pipeline Service`.
2. Enable OAuth settings. Callback URL: `https://localhost/callback` (unused).
3. Selected scopes: **Manage user data via APIs (api)**.
4. Tick **Enable Client Credentials Flow**. Save.
5. **Manage -> Edit Policies**: under *Client Credentials Flow* set **Run As** to an
   integration user (a dedicated user with the minimum permissions: create/read/delete Account
   and Task).
6. **Manage Consumer Details**: copy the Consumer Key and Consumer Secret.

## Configure (never commit these)
| Variable | Value |
|---|---|
| `SF_INSTANCE_URL` | My Domain URL, e.g. `https://orgfarm-xxxx-dev-ed.develop.my.salesforce.com` |
| `SF_CLIENT_ID` | Consumer Key |
| `SF_CLIENT_SECRET` | Consumer Secret |

Locally: `export` them in your shell, then `bash scripts/run-e2e-local.sh`.
CI: repository secrets with the same names.

## Notes
- The Salesforce CLI redacts access tokens in its output on purpose; do not try to
  extract one from `sf org display`.
- Use a sandbox or Developer org for E2E. The test creates `E2E-*` accounts and deletes
  them (and any stale ones) during setup and teardown.
