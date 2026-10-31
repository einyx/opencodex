# OpenCode iOS Client — Docs Index

> Last updated: 2026-10-18 (Watch Ambient is marked Experimental; voice and tool return on a physical device work, but multi-turn conversations still drop and the root cause is unconfirmed). Always start from this index when reading or searching any document.

## Top-level living documents

| File | Role | Status |
|---|---|---|
| `OpenCode_iOS_Client_PRD.md` | Product requirements (the client's full feature set) | living |
| `OpenCode_iOS_Client_RFC.md` | Technical architecture design (the client's full path) | living |
| `WORKING.md` | Progress, troubleshooting and decision log (changelog) | living |
| `tests.md` | Test system design spec (Tier 1–4) | living |
| `design.md` | Visual design spec (Quiet Tech style). Sections carry stable `QT-*` clause IDs; the machine-checkable form is `features/polish/rubric.md` | living |
| `OpenCode_Web_API.md` | OpenCode server HTTP API reference (upstream snapshot; the official docs and the live `/doc` are authoritative) | living reference |
| `lessons.md` | Engineering retrospectives and reusable lessons | living |

## features/ — one directory per feature

| Directory | Feature | Files | Status |
|---|---|---|---|
| `client_capabilities/` | Device capability extensions (V0: Health export) | `prd.md` / `rfc.md` / `protocol.md` | V0 shipped; `protocol.md` is the source of truth for the wire contract |
| `context_compaction/` | Manual Context Compaction | `design.md` | proposal only, not implemented |
| `session_finder/` | Session Finder smart session search | `design.md` | design draft |
| `background_task_notification/` | Background subagent task notification rendering (TaskNotificationCard + the generic synthetic rule) | `design.md` | implemented |
| `push_notifications/` | Background push notification approach | `research.md` | research |
| `localization/` | en/zh-Hans bilingual localization | `research.md` | Settings already ships en/zh; the research doc is somewhat dated |
| `focus_voice_input/` | Large-screen focus layout, voice-first input, system paste | `design.md` | implemented and accepted on simulator; device-local settings |
| `agent_catalog_validation/` | Agent catalog validation and visible delete failures | `notes.md` | shipped; the selected agent is checked against the current server `/agent`, and a non-2xx delete carries the status code and body |
| `watch_ambient/` | Watch voice — the watch's microphone goes to the phone, which recognises it and runs the turn; the watch speaks the answer | `prd.md` / `rfc.md` | **Experimental**; superseded for voice by `device_voice/` (the hosted Live connection is gone) |
| `v2_support/` | OpenCode V2 server support + `opencode pair` QR onboarding | `plan.md` | implemented; see `../v2_server_compatibility.md` for the wire contract |
| `file_changes_surface/` | Session changes & diff surface — a "N files changed" card in chat, a diff viewer (iPhone sheet / iPad preview column), a Files-tab Changes section, and automatic tree refresh when the agent writes | `design.md` / `plan.md` | **implemented** (2026-10-26); palette follows Warm Editorial (`design.md` §QT-PALETTE) |
| `device_voice/` | Device-only voice — Ambient Mode, dictation and the Apple Watch with no hosted speech service, no token and no audio leaving the device | `design.md` / `plan.md` | **implemented** (2026-10-26); the hosted "AI Builder" realtime path is gone — on-device recognition, the user's own OpenCode server as the brain, on-device synthesis, and no credential anywhere |
| `polish/` | Superpolished app experience — the "Quiet Tech" conformance initiative | `plan.md` / `rubric.md` / `audit.md` / `linear-backlog.md` | **Phase 0 complete** (rubric + measured audit + ranked backlog); **R1 (haptics) implemented, awaiting the privacy review**. 102 rubric rows: 45 PASS, 36 FAIL, 7 PARTIAL, 14 REVIEW. Tracked in Linear as `PRY-5`…`PRY-40`; `features/polish/rubric.md` is the machine-checkable form of `../design.md`, and `features/polish/audit.md` is the measured baseline it is enforced against |

The approved OpenCodex Settings refresh is described in
[`features/polish/settings-design.md`](features/polish/settings-design.md), with its
implementation and verification checklist in
[`features/polish/settings-plan.md`](features/polish/settings-plan.md).

## archive/ — one-off work records and frozen decisions (append only, never edited)

| File | Content |
|---|---|
| `2026-06_markdown_web_preview_prd.md` / `_rfc.md` | Markdown Web Preview subproject design; the decisions were folded into main PRD §4.3.5 / main RFC §7.5. The files are kept locally in `docs/archive/`, are untracked + gitignored, and **are not distributed with the repo** |
| `2026-06_visual_writing_weapon_system.md` | Visual and writing style discussion draft |
| `2026-07_yage_fix_work.md` | opencode-official fork fix record |
| `2026-08_qwen38_rendering_fix.md` | qwen38 rendering fix record (PR #145) |

## skills/ (repo root, agent-facing operational skills)

| File | Role |
|---|---|
| `skills/client_capabilities.md` | Canonical agent entry point for adding a new client capability |
| `skills/operate_ios_simulator.md` | iOS simulator automation layer |
| `skills/ui_test_tasks.md` | Tier 4 UI test task workflow |
| `skills/ui_test_prompts/` | Tier 4 test prompt collection |

## Other

- `design_images/` — mockup illustrations for `design.md` (generated with gpt-image-2, not a pixel-accurate final implementation)
- `logo_light.png` — app logo icon

## Conventions

- The top level only holds living documents; per-feature documents live under `features/<name>/`; one-off work records are archived under `archive/` (file name prefixes follow the `YYYY-MM_` convention).
- `tmp_*` files are design drafts that are not tracked in git, do not belong in archive, and are not an authoritative source of truth; key conclusions must be distilled into the formal documents in time.
- When adding a client capability, update the matching documents strictly following the rules in the "output location" section of `skills/client_capabilities.md`.
