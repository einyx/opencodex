# OpenCodeX Cloud — wire protocol

> **Authoritative.** This file is the source of truth for the contract between
> the OpenCodeX iOS client and the OpenCodeX Cloud service. The client and the
> service are implemented against this document; when code and this document
> disagree, this document is the bug report.
>
> Status: **proposal (2026-10-27)** — no service exists yet. Product and
> architecture: [`design.md`](design.md). Delivery: [`plan.md`](plan.md).

## The two surfaces

The app talks to **two different hosts**, and confusing them is the most
likely mistake in an implementation.

| Surface | Base URL | Protocol | Auth | Purpose |
|---|---|---|---|---|
| **Control API** | `https://api.opencodex.cloud/v1` | JSON over HTTPS | Bearer access token | Account, entitlement, sandbox lifecycle, repos, billing, usage |
| **Workspace API** | `https://ws.opencodex.cloud/s/<ref>` | The **OpenCode server protocol** (V2) | HTTP basic auth: username `opencode`, password = sandbox token | The agent itself: sessions, messages, SSE, files, diffs |

The workspace is an unmodified upstream `opencode serve`. The app already
speaks that protocol (`Services/APIClient.swift`), so the workspace is a
`HostProfile` like any other. The control API is new code on both sides.

```
app ──control API──▶ service core      (account, plan, allowance, sandbox lifecycle)
app ──workspace API─▶ edge proxy ──▶ tenant sandbox (opencode serve)
                                         │
                                         └──▶ metering gateway ──▶ provider
```

**The workspace host token is a bearer secret.** It is issued once, at
provisioning, and it is the only credential the app holds for the service.

## Conventions

- **Content type**: `application/json; charset=utf-8` in both directions.
  Errors use a problem+json shape (§Errors).
- **Versioning**: the control API is versioned in the path (`/v1`). Within
  `/v1`, changes are **additive only**: new fields, new endpoints, new enum
  values. The client must **ignore unknown fields** and must not fail on an
  unknown enum value — treat it as "not allowed" and fall back.
  A breaking change means `/v2`, served alongside `/v1` for at least 90 days.
- **Timestamps**: RFC 3339, UTC, fractional seconds — `2026-10-27T14:02:03.412Z`.
- **Credits**: **integers only**. 1 credit = $0.01 of provider list cost.
  Never a float, never a currency amount — a currency amount has rounding
  rules that a ledger must not have.
- **Tenant identity is server-minted.** No request body, header or query
  parameter may name a tenant. The access token carries the tenant; the
  service resolves everything from it. A client that sends a tenant id is
  ignoring the contract.
- **Unknown fields in a request body are rejected** (`invalid_request`), so a
  typo fails loudly instead of silently doing nothing.

## Authentication

Sign-in is a passwordless email link. The app holds the tokens in the
Keychain; nothing is stored in `UserDefaults`.

| Endpoint | Request | Response |
|---|---|---|
| `POST /v1/auth/request-link` | `{ "email": "dev@example.com" }` | `202 { "status": "sent" }` |
| `POST /v1/auth/verify` | `{ "email": "...", "code": "123456" }` | `200 { "accessToken", "refreshToken", "expiresAt", "user", "tenant" }` |
| `POST /v1/auth/refresh` | `{ "refreshToken": "..." }` | `200 { "accessToken", "refreshToken", "expiresAt" }` |
| `GET /v1/auth/session` | — | `200 { "user", "tenant", "session" }` |
| `POST /v1/auth/logout` | — | `204` |
| `GET /v1/devices` | — | `200 { "items": [ … ] }` |
| `DELETE /v1/devices/{deviceId}` | — | `204` |

```jsonc
// 200 POST /v1/auth/verify
{
  "accessToken": "<jwt>",           // 15 min
  "refreshToken": "<opaque>",       // 30 days, rotated on every use
  "expiresAt": "2026-10-27T14:17:03.412Z",
  "user":   { "id": "usr_…", "email": "dev@example.com" },
  "tenant": { "id": "ten_…", "plan": "free" }
}
```

Rules:

- `request-link` **always** answers `202` with the same body, whether or not
  the address exists. Enumeration is not an attack surface we accept.
- **Refresh rotation**: every refresh issues a new refresh token and
  invalidates the old one. Presenting an already-used refresh token revokes
  the entire token family and returns `session_revoked` — the device must
  re-authenticate.
- `logout` revokes the current session only. `DELETE /v1/devices/{id}`
  revokes every session of that device.
- Access tokens are sent as `Authorization: Bearer <token>`. The workspace
  uses basic auth instead; **the two must not be interchanged**.

## Entitlement and allowance

```jsonc
// 200 GET /v1/entitlement
{
  "plan": { "id": "pro", "name": "Pro" },
  "credits": {
    "granted": 600,
    "used": 137,
    "remaining": 463,
    "windowResetsAt": "2026-11-27T00:00:00.000Z"
  },
  "models": [
    { "providerID": "zai-coding-plan", "modelID": "glm-5.3-flash", "multiplier": 1, "allowed": true },
    { "providerID": "openai",          "modelID": "gpt-5.6",        "multiplier": 8, "allowed": false }
  ],
  "limits": { "maxRepos": 1, "maxConcurrentSessions": 2, "storageBytes": 1073741824 },
  "source": "apple"          // "apple" | "web" | "internal"
}
```

- `credits.remaining` is `granted - used` **as reported by the service**, not
  computed by the app. The app displays it; it does not do arithmetic on it.
- `models[].allowed` is the **plan's** model entitlement. It is *not* the
  same thing as the model catalog, which comes from the workspace server
  (`/api/model`). The catalog says what exists; the entitlement says what this
  tenant may spend on.
- `multiplier` is how many credits one unit of that model's provider cost
  costs. A Flash model at ×1 and a frontier model at ×8 is why a
  request-denominated allowance would lose money.

## Sandboxes

The app never names a sandbox. `POST /v1/sandboxes` takes **no tenant and no
sandbox parameter**; the service resolves the tenant from the access token.

| Endpoint | Request | Response |
|---|---|---|
| `POST /v1/sandboxes` | `{}` (optional `Idempotency-Key` header) | `201`/`200` `{ "sandbox": { … } }` |
| `GET /v1/sandboxes` | — | `200 { "items": [ … ] }` |
| `POST /v1/sandboxes/{id}/rotate` | — | `200 { "sandbox": { … } }` |
| `DELETE /v1/sandboxes/{id}` | — | `204` |
| `POST /v1/sandboxes/{id}/workspace` | `{ "repoFullName": "owner/repo", "branch": "main" }` | `200 { "workspace": { … } }` |
| `DELETE /v1/sandboxes/{id}/workspace` | — | `204` |

```jsonc
// 201 POST /v1/sandboxes
{
  "sandbox": {
    "id": "sbx_01J…",                                  // opaque, service-side id
    "ref": "k3f9d2a7c1e04b8fa6d5c0e39b7a2c18",          // 128-bit public, in the URL
    "serverURL": "https://ws.opencodex.cloud/s/k3f9d2a7c1e04b8fa6d5c0e39b7a2c18",
    "username": "opencode",
    "token": "<256-bit secret, shown once>",
    "apiGeneration": "v2",
    "state": "starting",                                // "starting" | "ready" | "failed"
    "createdAt": "2026-10-27T14:02:03.412Z",
    "workspace": null                                   // or a workspace object
  }
}
```

- **Idempotent**: calling `POST /v1/sandboxes` twice for one tenant returns
  the **same** sandbox (same `ref`, same `token`, `200` instead of `201`).
  The app may retry after a timeout and must not end up with two sandboxes.
  An `Idempotency-Key` header is honoured for the same reason.
- `token` is returned **only** here and on `rotate`. It is stored hashed by
  the service; the service can never show it again. **A repeat provisioning
  does not hand the token out again** — a client that lost it recovers with
  `POST /v1/sandboxes/{id}/rotate`, which issues a new one and kills the old
  one at the same time.
- `ref` is public but unguessable, and it is *not* the secret. The URL
  carries `ref`; the credential travels in the `Authorization` header. A
  leaked URL without the token is worthless.
- `state: "starting"` means the sandbox exists but is not serving yet. The
  app should treat it as a normal host that is not yet reachable, and retry
  the connection — **not** as an error.
- `rotate` issues a new token for the same sandbox and invalidates the
  previous one immediately. Both are never valid at the same time.
- `DELETE` is a **hard** teardown: it revokes the gateway credential, denies
  the proxy, destroys the sandbox and its volume, and deletes the workspace
  and token rows. The sandbox row is kept with `destroyed_at` set, because
  the audit trail outlives the machine. Workspace data is gone. Deleting the
  *account* is a different, softer operation (§Account lifecycle).

### Workspace

```jsonc
// 200 POST /v1/sandboxes/{id}/workspace
{
  "workspace": {
    "repoFullName": "owner/repo",
    "branch": "main",
    "path": "/workspace/repo",
    "clonedAt": "2026-10-27T14:03:11.004Z"
  }
}
```

- `POST` attaches a repo. It is idempotent on `(sandbox, repoFullName)`.
- `DELETE` detaches it. The clone is removed from the sandbox; the GitHub
  repository itself is never touched.
- The service never accepts a URL, a clone instruction or a branch name it
  did not receive from GitHub. A repo the tenant cannot see is
  `repo_not_installed`.

## Repos (GitHub)

| Endpoint | Response |
|---|---|
| `GET /v1/repos` | `200 { "items": [ { "fullName", "private", "defaultBranch", "installable" } ] }` |
| `POST /v1/git/install/exchange` | `200 { "installation": { "id", "accountLogin" } }` |

- `installable` is false when the GitHub App is not installed on that repo.
  `GET /v1/repos` lists the tenant's repos; the app shows the ones it can
  use.
- The OAuth exchange happens **server-side**: the app sends an authorization
  code, the service exchanges it with GitHub and stores the installation
  token encrypted. **A GitHub token never reaches the device.**

## Billing status and usage

| Endpoint | Response |
|---|---|
| `GET /v1/billing/status` | `200 { "plan", "source", "renewsAt", "cancelsAt" }` |
| `POST /v1/billing/apple/verify` | `204` |
| `GET /v1/usage?window=month` | `200 { "window", "credits", "byModel", "byDay" }` |

- `POST /v1/billing/apple/verify` takes the App Store's signed transaction
  info and validates it **server-side** (App Store Server API). The device
  never asserts its own entitlement; it presents a signed object and the
  service decides.
- `source` is `"apple"`, `"web"` or `"internal"`. Both paid sources produce
  the same entitlement — a plan bought on the web unlocks the app
  (guideline 3.1.3(b)).

## Errors

Problem+json, with a **stable machine code**. The client switches on `code`,
never on `detail` and never on the HTTP status alone.

```jsonc
{
  "type": "https://opencodex.dev/problems/allowance_exhausted",
  "title": "Allowance exhausted",
  "status": 402,
  "code": "allowance_exhausted",
  "detail": "This month's 600 credits are used up.",
  "traceId": "01J2…"
}
```

| `code` | HTTP | Meaning | Client behaviour |
|---|---|---|---|
| `unauthorized` | 401 | No or malformed access token | Sign in again; keep the free tier usable |
| `session_expired` | 401 | Access token expired | Refresh silently; retry once |
| `session_revoked` | 401 | Refresh family reused, or device revoked | Clear the session, sign in again |
| `invalid_request` | 400 | Malformed body or unknown field | Show a generic failure; log the body |
| `rate_limited` | 429 | Too many control-API calls | Back off; the sandbox path is unaffected |
| `entitlement_missing` | 402 | No paid plan | Offer the upgrade; the free tier stays usable |
| `allowance_exhausted` | 402 | Credit balance is zero | **Do not retry.** Offer upgrade / top-up |
| `model_not_allowed` | 403 | Model not in the plan's entitlement | Hide or disable the model in the picker |
| `plan_limit_reached` | 403 | e.g. more repos than `maxRepos` | Show the limit and how to raise it |
| `sandbox_not_found` | 404 | Unknown or already deleted sandbox | Re-provision; treat as a fresh host |
| `sandbox_unavailable` | 503 | Sandbox crashed and could not resume | Offer to restart; keep the conversation history locally |
| `repo_not_installed` | 409 | GitHub App not installed on that repo | Send the user to install the app |
| `repo_access_revoked` | 403 | Installation token revoked | Re-prompt the GitHub install |
| `clone_failed` | 502 | Git clone failed | Offer a retry; surface the reason |
| `provider_unavailable` | 503 | The model provider is down or rate-limited | Retry with backoff; consider a cheaper model |
| `tenant_suspended` | 403 | Plan lapsed and the grace period ended | Show the renewal prompt; free tier still usable |

Two rules the client must honour:

1. **`allowance_exhausted` is terminal for that turn.** The app must not
   retry it — a retry loop on a 402 burns battery and produces duplicate
   user-visible errors.
2. **A control-API failure never breaks the free tier.** If the service is
   down, a user with their own server keeps working.

## Account lifecycle

| Operation | Effect |
|---|---|
| `DELETE /v1/account` | Revokes all sessions and devices, cancels the subscription, **deletes the workspace data**, keeps billing records (tax law) |
| `POST /v1/account/export` | Queues an export; the app polls `GET /v1/account/export` for a signed URL |

- Deletion is asynchronous and completes in **≤ 30 days** (backup rotation).
  The app shows the state, not a claim.
- A **lapsed subscription** is not a deleted account: the workspace is kept
  for a **grace period of 14 days**, during which the tenant can export and
  renew. A failed card must never delete someone's repo work.
- Revocation order on teardown: gateway credential → proxy denies → sandbox
  and volume destroyed → rows deleted. Revoking last leaves a window where a
  dead subscription can still spend.

## Security properties

| Property | Requirement |
|---|---|
| Tenant scoping | Every row that can reference tenant data carries `tenant_id`; every query is scoped by it in the repository layer, not at call sites |
| Tenant id on the wire | Never sent by the client, never accepted from the client |
| Sandbox `ref` | 128 bits of randomness, public, unguessable, **not a secret** |
| Sandbox token | 256 bits of randomness, stored hashed (HMAC-SHA256 + server pepper), shown once, rotatable, never logged |
| Provider keys | Exist only in the metering gateway. Never in a sandbox, never on a device |
| Sandbox credentials | Capped, scoped, revocable; a leak yields a bounded credential, not money |
| Isolation | One sandbox per tenant; separate volume; no shared writable filesystem; CI proves cross-tenant reads fail |
| Audit | Every state-changing endpoint writes an audit event (actor, tenant, action, target, outcome, timestamp) |
| Rotation | Access tokens 15 min; refresh tokens 30 days and rotated on every use; the app refreshes on 401 once |

## Client integration map

Where each piece of this contract lands in **this** repository:

| Contract piece | Client file |
|---|---|
| Access + refresh tokens | new `Services/CloudAccountClient.swift`; Keychain namespace `opencodex.account.session` |
| Account state | new `AppState+CloudAccount.swift` |
| `POST /v1/sandboxes` → a host | `AppState+HostProfiles.swift` (`saveHostProfile`) |
| `serverURL` / `username` / `token` → a host | `Views/HostProfilesView.swift` (`applyPairing(url:token:)` shape) |
| Managed cloud host UI | `Views/HostProfilesView.swift` (new managed badge, no URL editing) |
| Entitlement + allowance display | `Models/ComposerQuota.swift:197-205` — the single adapter; upstream hosts keep `allowance: nil` |
| Sign-in entry point | `Views/Setup/SetupPlanSheet.swift` (new `.cloud` tile; also fix the unread `Handoff`) |
| Strings | `Support/L10n.swift` — one `Key` case + `en` + `zh` per string |

## Known traps

- **Do not send a tenant id.** There is no field for it. A request that
  carries one must be rejected by the service, not silently honoured.
- **Do not put the token in the URL.** The URL carries the public `ref`; the
  token is the basic-auth password. A token in a URL leaks through logs,
  referrers and screenshots.
- **Do not confuse the two quota surfaces.** `AppState+AIUsageQuota.swift`
  reads the *user's own* third-party dashboard (unauthenticated, a URL the
  user typed) and has a hardcoded provider→quota mapping
  (`Models/AIUsageQuota.swift:147-157`). Plan credits are a different thing
  and come from `GET /v1/entitlement`. They must not be merged.
- **Do not derive the plan balance from the session cost.** The OpenCode
  server reports what a conversation cost; that is not the allowance.
- **Do not treat `state: "starting"` as an error**, and do not re-provision
  in a loop — provisioning is idempotent and the sandbox may take a few
  seconds to serve.
- **Do not expect a token from a repeat provisioning.** It is returned once.
  If the app lost it, rotate; do not assume the service can re-show it.
- **Do not retry `allowance_exhausted`.**
- **Do not hardcode the model list.** The catalog comes from the workspace
  server; the entitlement says what may be *spent* on. Both are needed and
  they are not the same list.
- **Do not let a control-API outage break a user's own server.** The free
  tier is not a function of our service being up.

## Change log

| Date | Change |
|---|---|
| 2026-10-27 | Initial contract |
