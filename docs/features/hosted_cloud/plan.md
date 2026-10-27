# OpenCodeX Cloud — operating plan

> Status: **proposal (2026-10-27)** — nothing implemented. Design:
> [`design.md`](design.md). This plan is anchored on **M0**; M1 and M2 are
> outlines, because the M0 result is what decides them.

## Scope

A hosted OpenCode agent sold by subscription, with the user's GitHub repo as
the workspace, reachable from the app. In scope: multi-tenant isolation,
ledger-based billing, metering, the GitHub workspace, and the iOS account /
plan / cloud-host surface. Out of scope for M0: real money, App Store IAP,
PR creation, team seats, multi-region, self-hosted enterprise.

## The bar

What separates this from a prototype — the invariants M0 must already
satisfy, not in M1:

1. **Tenant isolation is a CI gate**, not a claim: tenant A cannot read or
   spend tenant B's resources through any public API.
2. **Money is a ledger**: double-entry, idempotent, replay-safe, reconciled
   daily against the provider's own numbers.
3. **Allowance is enforced before the spend**, at the gateway.
4. **Provider keys exist only in the gateway**; devices hold only a host
   token; sandboxes hold only capped, scoped credentials.
5. **Deploys are IaC + canary**, sandboxes run pinned image digests, and every
   product surface has a kill switch.
6. **Every tenant action is audited**; support can answer "what happened to
   tenant X at 14:02" without SSH.
7. **No manual production SSH** in any runbook (break-glass only, audited).

## Milestone map

| Milestone | Weeks | Exit headline |
|---|---|---|
| **M0 — Platform alpha** | 6 (4 build + 14-day burn-in) | 5 design partners run the real loop daily; isolation + ledger proven; measured cost model within ±15% |
| M1 — Private beta | 8 | Real billing (Stripe + Apple IAP), PR flow, 100 tenants, App Store approved |
| M2 — GA | 8 | GA checklist green, 100 paying tenants, D30 ≥ 55%, gross margin ≥ 60%, zero P1 for 30 days |

---

# M0 — Platform alpha

## Goal

A design partner signs in on the phone, taps one button, and within a minute
is talking to an agent that has their GitHub repo cloned and is editing files
— with the edits visible in the app's file tree and diff surfaces. No
hand-billing, no manual provisioning, no production SSH.

The deliverable is not a demo. It is **the first honest measurement of the
business**: cost per active tenant per day, isolation that holds under test,
and a ledger that balances.

## In scope

- Email-link sign-in (no password), session rotation, device list.
- One edge ingress (Workers) that authenticates the tenant and proxies to
  that tenant's sandbox. One regional core (a single deployable that hosts
  identity, entitlements, the ledger, the orchestrator and the gateway as
  modules — deliberately **two** deployables in M0, not eight services).
- Per-tenant sandbox: provision, snapshot, resume, destroy; pinned image
  digest; egress allowlist; no published ports.
- GitHub App install (per-repo) → clone into the sandbox.
- Metering gateway: one provider to start, two models (one Flash-class, one
  mid-tier), per-tenant spend caps, token accounting.
- Double-entry ledger, daily reconciliation against the provider dashboard,
  credit grants by an internal admin tool (no customer money in M0).
- iOS: sign-in, cloud-host provisioning, allowance display, feature-flagged.
- Observability: metrics, logs, tenant-scoped audit trail, alerts, 3 runbooks.

## Out of scope (deliberately)

Real payments, App Store IAP, PR creation, team seats, in-app upgrade flow,
multi-region, self-serve signup marketing, SOC 2.

## Architecture in M0

```
iPhone ──TLS+basic-auth──▶ edge (Workers) ──private net──▶ sandbox (opencode serve)
                              │                                    │
                              └──▶ core (regional) ──▶ gateway ───┘   (LLM calls)
                                       │             │
                                       └──▶ Postgres (ledger, entitlements, audits)
```

One region. One Postgres. One provider. The point of M0 is to prove the
shape cheaply, not to be the final topology — but everything built must
survive being split later (module boundaries, no global state in the core,
tenant id on every row).

## Workstreams and tasks

### 1. Platform skeleton

- New repository `opencodex-cloud` (**separate from this client repo** — this
  repo is the shipped app tree; server-side work does not belong here).
- IaC: one cloud account, one region, Postgres, object storage, KV, secrets
  manager, image registry, observability. Everything created through code.
- CI: build, unit, integration, IaC plan/drift check, image build + digest
  pin, deploy to a preview environment on every PR.
- Deploy: canary 5% → 25% → 100% with automatic rollback on error-rate
  breach. No `ssh prod` anywhere in the runbooks.

### 2. Identity and entitlements

- Email-link sign-in, session tokens with refresh rotation, device list and
  revocation, 2FA (TOTP) enabled for staff accounts from day one.
- Entitlements: one tenant per account in M0; plan as a record; credits
  granted by an admin tool as a ledger entry.
- Tenant id is minted server-side and travels to the edge as a signed claim.
  The client cannot set or influence it.

### 3. Sandbox orchestration

- Image: upstream `opencode` pinned by digest, built by our pipeline (SBOM,
  vulnerability scan, signed). Patch cadence: upstream release → rebuild →
  canary to 5% of tenants → 100%.
- Lifecycle: provision (target cold start < 5 s), snapshot on idle, resume
  (< 2 s), destroy on revoke. One live sandbox per tenant; provisioning is
  idempotent.
- Isolation: microVM or container hardened per `design.md` §"Sandbox
  controls" — no host mounts, read-only rootfs, tmpfs scratch, dropped
  capabilities, `no-new-privileges`, cgroup caps, no docker socket, no
  host network, no inbound.
- Egress allowlist enforced at the network layer: gateway, the git remote,
  package registries. Deny `169.254.0.0/16` and RFC1918 except our gateway.
- Workspace volume per tenant, encrypted at rest, never shared.

### 4. Metering gateway and ledger

- Gateway holds provider keys (secret manager, no env in git, rotation
  procedure written down). Per-sandbox scoped credential with a hard spend
  cap and per-minute rate limit. Model entitlement per plan enforced here.
- Every LLM call → one usage record → two ledger entries (debit tenant usage
  bucket, credit provider-cost bucket), keyed by an idempotency key derived
  from the provider request id.
- Daily reconciliation job: ledger vs. provider dashboard, by model and by
  tenant; drift < 0.1% of spend. A breach stops new tenant provisioning until
  explained.
- Enforcement: balance ≤ 0 → gateway refuses the next call; the app is told
  "allowance exhausted" (not a raw error).
- Cost instrumentation from day one: cost per tenant per day is a first-class
  metric, not a report someone builds later.

### 5. Workspace and Git

- GitHub App: install per repo, token encrypted at rest, token scope limited
  to the selected repos, revoked on uninstall.
- Clone into the sandbox on first use; incremental fetch afterwards; clone
  failure and size limits handled with a clear message.
- M0 stops at "the agent edited files in the cloned repo". PR creation is
  M1 — it needs a permission model we have not designed yet.

### 6. iOS client (this repo)

- New `Services/CloudAccountClient.swift` + `AppState+CloudAccount.swift`;
  session token in a new Keychain namespace (`opencodex.account.session`).
- `POST /v1/sandboxes` → write a `HostProfile` exactly like
  `applyPairing` (`Views/HostProfilesView.swift:674-686`): `transport:
  .direct`, `serverURL: https://…/s/<opaque>`, `basicAuth`, `apiGeneration:
  .v2`.
- Managed cloud host in `Views/HostProfilesView.swift` — no URL/credential
  editing, a "managed" badge, and a "disconnect" that revokes server-side.
- Allowance display through the reserved seam
  (`Models/ComposerQuota.swift:197-205` — `allowance: nil` today).
- `Views/Setup/SetupPlanSheet.swift`: add a `.cloud` tile, and **fix the
  unread `Handoff`** (written at L26/194-208, never read) so the panel
  actually creates a host.
- Account surface: sign in/out, session revocation, allowance, delete
  account (deletion is a server call + local cleanup).
- All strings in `Support/L10n.swift` (one `Key` + `en` + `zh` per string).
- Feature-flagged: the free tier is untouched; the cloud tile is visible only
  when the flag is on.
- Tests: account lifecycle, provisioning → profile, host behaves like any
  other host (connect, probe, session list, message send, SSE), allowance
  exhaustion, account deletion, and a **free-tier regression guard**.

### 7. Operability

- SLO dashboards (§SLOs below), tenant-scoped audit trail, alerts with a
  routing path that reaches a human.
- Runbooks (3, written not improvised): sandbox crash + auto-resume,
  provider outage / rate limit, credit exhaustion / mis-billing.
- Kill switches: per tenant (disable agent, disable premium models), per
  provider (route around a failing provider), global (pause provisioning).
- Backups: Postgres PITR + restore drill in M0; workspace snapshots
  separately.

## Exit criteria (all must hold)

| # | Criterion | Measurement |
|---|---|---|
| 1 | The whole loop works from the phone | Design partner signs in → taps connect → chats with an agent that has their repo cloned → sees file edits in the app's tree and diff. Measured, not asserted. |
| 2 | Isolation holds | Isolation suite green for 14 consecutive days; tenant A cannot read tenant B's sessions, workspace, ledger, credits or credentials through any public API |
| 3 | The ledger balances | Every LLM call produces exactly one double-entry record; replay-safe; 14 days of daily reconciliation with < 0.1% drift |
| 4 | The cost model is real | Measured cost per active tenant per day over 14 days, extrapolated to a monthly figure with ±15% confidence, checked against the ≤ 34% COGS target at $19 (see `design.md` §Economics) |
| 5 | The sandbox holds | Standard container-escape corpus fails to escape; egress allowlist enforced under DNS tricks, IPv6 literals and redirect chains; a simulated provider-key theft yields only a capped, scoped credential |
| 6 | We can operate it at 3 a.m. | Dashboards green, alerts reach a human, the 3 runbooks are rehearsed, a kill switch is exercised, and no runbook requires production SSH |
| 7 | Design partners keep using it | ≥ 5 partners, ≥ 3 using it on ≥ 4 of the last 7 days, and a written answer from each on what they would pay for |

Criterion 7 is deliberately qualitative: it is the only signal that survives a
cost model being wrong.

## Calendar

| Week | Focus |
|---|---|
| 1 | Repo + IaC skeleton, CI, identity, Postgres schema v1, edge auth |
| 2 | Orchestrator (provision/snapshot/resume/destroy), pinned image, gateway with 1 provider + 2 models, ledger write path |
| 3 | GitHub App + clone, workspace volume, iOS sign-in/provisioning/allowance, cost instrumentation |
| 4 | Isolation suite, reconciliation job, dashboards, alerts, 3 runbooks, admin tool, pen-test booking, onboard the 5 design partners |
| 5–6 | Burn-in: 14 days of daily reconciliation, isolation runs, cost measurement, partner feedback, fixes. No new scope in these two weeks. |

## Cost and staffing

- **People**: 1 full-stack (this repo's owner) + 1 backend engineer (contract
  or hire) + fractional SRE/security review. The iOS work is by the owner.
- **Infra**: $500–1,500/month (one region, dev + alpha, microVM or container
  fleet of ~10, Postgres, object storage, observability).
- **One-off**: pen test booked for M1 ($15–30k, not paid in M0), no legal
  spend beyond a draft ToS.
- **M0 burn**: roughly $4–8k.

## Risks in M0, and the kill switches

| Risk | Mitigation / kill switch |
|---|---|
| Cost model is wrong by 3× | Measure daily from day one; if the extrapolated monthly cost exceeds 55% of price, stop and re-price (cheaper default model, tighter credit grants) before spending on M1 |
| Isolation hole | CI blocks merges; a discovered cross-tenant read is a stop-the-line event, not a backlog item |
| Sandbox vendor wrong | Keep the orchestrator behind an interface; the escape corpus and cost benchmark decide the vendor in M0, not in M1 |
| Provider refuses our usage pattern | Business API accounts plus a metered gateway from day one; no personal plans as the backend (see `design.md` §Model supply) |
| GitHub App review delay | Start the App registration in week 1; fall back to a per-repo deploy key if it slips, and accept the reduced UX |
| Scope creep into M1 features (PRs, payments) | M0's exit criteria are the only gate; new features go to M1 or later |

## What M0 deliberately does not do

Real money (credits are granted internally), App Store IAP, PR creation,
in-app upgrade, multi-region, self-serve marketing, SOC 2, team seats,
chat-only usage, overage billing. Each of those is a M1/M2 item with its own
exit criteria — not a "while we're in there".

---

## M1 — Private beta (outline, 8 weeks)

Real billing (Stripe web checkout + Apple IAP, entitlement through the
ledger), GitHub PR flow with a permission model, in-app upgrade and
allowance-exhaustion UX, reconciliation at 100% for 14 days, SLOs met four
weeks running, privacy policy / ToS / DPA / subprocessors published, App Store
review with IAP approved, 100 tenants. Exit: all M0 criteria still green,
pen-test findings triaged, D30 retention ≥ 45%.

## M2 — GA (outline, 8 weeks)

Pen-test fixes, chaos drills, status page, load test to 10×, support tooling
and macros, self-serve upgrade, pricing page and launch motion, regional
standby, GA checklist below. Exit: 100 paying tenants, D30 ≥ 55%, gross
margin ≥ 60%, zero P1 open for 30 days, zero unexplained reconciliation gaps
for 30 days.

## SLOs (measured from M0 onward)

| SLO | Target | Window | Error-budget policy |
|---|---|---|---|
| Chat API availability (proxy → sandbox) | 99.9% | monthly | under 43 min/month: freeze non-critical deploys |
| Sandbox provision → first successful turn | p50 < 8 s, p95 < 20 s | rolling 7 d | p95 over budget for 3 d → freeze image rollouts |
| Time to first token after a prompt | p50 < 2.5 s, p95 < 8 s (excl. provider queueing) | rolling 7 d | route around the slow provider automatically |
| 5xx rate | < 0.5% | rolling 24 h | auto-rollback on breach |
| Sandbox crash rate | < 0.1% of sessions, ≥ 95% auto-resumed | weekly | pause image rollout if it doubles |
| Ledger reconciliation drift | < 0.1% of spend, 0 unexplained gaps | daily | stop new provisioning on breach |
| Support first response | < 24 h (Pro), < 4 h (Pro+) | business days | — |

## GA checklist

Isolation suite green · ledger reconciled 30 days straight · pen-test
findings triaged · SLO dashboards + alerting + on-call rota + runbooks ·
App Store approved with IAP live · ToS, privacy policy, DPA, subprocessors
published · account deletion and data export working · spend caps and rate
limits tested under load · Postgres restore drill passed · status page live ·
incident drill executed · kill switches exercised · no open P1 · 100 paying
tenants · D30 ≥ 55% · gross margin ≥ 60%.

## Refused, not deferred

Per-provider passthrough billing (users pay OpenAI directly), self-hosted
enterprise control plane, in-app collaboration, a chat-with-code tier, and
per-provider plan management in the app. These are the requests that turn a
focused product into a platform, and every one of them costs the thing that
matters: a working agent on a phone.
