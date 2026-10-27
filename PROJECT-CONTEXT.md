# PROJECT-CONTEXT.md

Baseline context for agents working in this repo. Keep it factual and current; update
it when the phase or constraints change. Detailed living docs live in `docs/` — start
at `docs/README.md`.

## Project

**OpenCode iOS Client** — a native iOS client for the OpenCode coding-agent server.
It lets developers run and supervise OpenCode sessions from a phone or iPad: chat with
the agent, watch tool calls stream in, browse the session tree, read and preview
project files, connect to remote hosts over direct HTTP or an SSH tunnel, and drive
hands-free ambient voice sessions. A watchOS companion app (`OpenCodeWatch`) relays
voice and tool results to an Apple Watch.

## Tech stack

- Swift + SwiftUI, with UIKit bridges (`UIViewRepresentable` / `UIViewControllerRepresentable`)
  for the composer and paste control
- Xcode 27.x; deployment targets iOS 17.0, visionOS 26.0, watchOS 11.0
- Four targets: `OpenCodeClient`, `OpenCodeClientTests` (53 files), `OpenCodeClientUITests`
  (22 files), `OpenCodeWatch`
- SSE streaming + REST against the OpenCode server; V1 and V2 wire protocols both supported
- ~73k lines of Swift across ~203 files (the app target itself is ~43k lines across 126
  files). `scripts/` holds shell and Python helpers:
  unit/UI test runners, simulator pinning, and a V2 contract checker
- A sibling Android client shares the core but lives in a separate repo — it is not in this tree

## Current phase

Core features are shipped; the project is in a polish-and-hardening phase. OpenCode V1
and V2 server support, host profiles, QR pairing, and ambient live voice all work; the
watch companion is experimental; several PRs are open awaiting on-device acceptance.
Visual direction is set by the "Quiet Tech" spec in `docs/design.md`, whose sections
carry stable `QT-*` clause IDs. The machine-checkable form of that spec is
`docs/features/polish/rubric.md` (102 rows), with the measured baseline in
`docs/features/polish/audit.md` and the phase plan in
`docs/features/polish/plan.md`. Linear tracking: `PRY-5`…`PRY-40`.

A hosted paid tier — "OpenCodeX Cloud", a per-tenant OpenCode server with a
GitHub workspace and a metered subscription — is planned in
`docs/features/hosted_cloud/` (`design.md` / `plan.md`) but is **not built**.
It is scoped as a SaaS (isolation as a CI gate, double-entry ledger, gateway-
enforced allowance, SLOs and runbooks) with milestones M0 → M1 → M2, anchored
on M0.

## Key constraints

- **Design tokens over ad-hoc values.** `Utils/DesignTokens.swift` owns color, type,
  spacing, and radius. Views must not introduce raw system colors or literal font sizes.
- **Single accent, restrained surface.** Dark-first, one accent blue per screen, no
  gradients, borderless-first, at most one colored element visible at a time.
- **No raw Swift errors in the UI.** Errors surface as human-readable guidance.
- **Privacy review is mandatory** for anything touching tokens, credentials, audio, or
  network transport.
- **Tests must be isolated.** Build `AppState` with a per-test `UserDefaults` suite; the
  default `.standard` leaks state across suites and between runs.
- **Never disturb a live server.** Do not kill or restart the user's running process,
  especially anything bound to port `4096`.
- **This repo is the only app tree.** No sibling app targets or duplicate client trees at
  the root; upstream server patches belong in `opencode-official/`.
- **No credentials in the tree or in URLs.** Keep tokens in a credential helper, never in
  committed files or remote URLs.

## What "done" looks like

- `./scripts/test_unit.sh` passes green (1070 tests at last count, 2026-10-24; 1082
  executions because 3 suites run with dynamic parameters) and
  `./scripts/test_ui.sh` completes without a hang
- A signed device build succeeds, and device-dependent behavior is verified on a
  physical device rather than inferred from the simulator
- The change conforms to `docs/design.md` and introduces no token violations
- The change does not regress any `POL-*` row in `docs/features/polish/rubric.md`; new
  violations are caught by `scripts/polish_lint.sh` (Phase 1 of the polish initiative)
- Feature behavior is documented in the matching `docs/features/<name>/` doc, and
  `docs/WORKING.md` records the decision and its evidence
