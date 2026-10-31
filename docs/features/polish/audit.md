# Polish Audit — measured baseline

The state of the app against every row of [`rubric.md`](rubric.md).

> **This file is generated.** Run `python3 docs/features/polish/gen_audit.py` (or the equivalent helper) to regenerate it. Every `file:line` anchor below is produced by running the grep **at generation time** — none is hand-copied. That is deliberate: a hand-maintained anchor becomes a lie the moment the file is edited, and a merge that rewrites a file silently invalidates every line number pointing into it.
>
> **Measurement boundary:** the figures in this file describe the working tree **as measured at generation time**. Row states are predicates about the code, not about a review verdict.
>
> **The review gate has not been passed.** Three rounds have run; the last returned FAIL on documentation-contract findings, all of which are now addressed. The haptic rows below are marked on their predicates.
>
> **Known coverage gap:** the merged spec added a `QT-CHATSCREEN` clause (floating glass header and composer, transient turn state, one row per tool call) that has **no rubric rows**. This file is therefore complete against the rubric, and the rubric is complete against the spec as of `48fd2b3` — not against the merged spec.

**Legend** — `PASS` conformant · `FAIL` violates the rule · `PARTIAL` conforms in part · `REVIEW` needs a human check, no automated predicate · `AMBIGUOUS` the spec does not settle it · `DEFERRED` out of scope for v1.

| ID | State | Evidence |
|---|---|---|
| POL-COLOR-01 | **FAIL** | No `bg.primary` token: `DesignColors.Neutral` declares only `text`, `textSecondary`, `textTertiary`, `surfaceLight`, `surfaceDark`, `composerLight` and `composerDark` — there is no `#0B0C0E` value anywhere in the token file, so the app inherits the implicit system background instead of the spec's near-black. |
| POL-COLOR-02 | **FAIL** | `DesignTokens.swift:138` `composerDark` = `#191816`, the secondary background. |
| POL-COLOR-03 | **FAIL** | `DesignTokens.swift:134` `surfaceDark` = `#1E1D1B`. |
| POL-COLOR-04 | **FAIL** | The text tokens are system colours, not the spec hexes: `DesignTokens.swift:121` `text = Color.primary` and `123` `textSecondary = Color.secondary`; the tertiary token is `UIColor.tertiaryLabel` / `Color.gray.opacity(0.4)`. The spec wants `#ECEDEE` / `#9BA1A6` / `#5A6066`. |
| POL-COLOR-05 | **FAIL** | The dark accent is correct: `DesignTokens.swift:25` `Brand.primary` = `#C96442`. The light `#2563EB` variant has no token — `Brand` declares one value only. |
| POL-COLOR-06 | **FAIL** | No accent-muted token. `DesignTokens.swift` has `Opacity.selectionFill = 0.08` (52) — a different role — and the shadow tokens use `Color.black.opacity(...)`. |
| POL-COLOR-07 | **PARTIAL** | `DesignColors.Neutral` carries explicit light/dark pairs, but `text` and `textSecondary` are system colours and `Brand.primary` has no light variant, so the mapping is not one-token-set. |
| POL-COLOR-08 | **FAIL** | 8 raw colour literals in the app target, including `OpenCodeClient/OpenCodeClient/Utils/GlassSurface.swift:54`, `OpenCodeClient/OpenCodeClient/Utils/DesignTokens.swift:97`, `OpenCodeClient/OpenCodeClient/Utils/DesignTokens.swift:99`, `OpenCodeClient/OpenCodeClient/Utils/DesignTokens.swift:128`, `OpenCodeClient/OpenCodeClient/Utils/DesignTokens.swift:381`, (+3 more). The merged `Utils/GlassSurface.swift` added more. |
| POL-COLOR-09 | **FAIL** | 29 ad-hoc `.opacity(` call sites in Views (`OpenCodeClient/OpenCodeClient/Views/Chat/ChatTabView.swift:703`, `OpenCodeClient/OpenCodeClient/Views/Chat/ChatTabView.swift:719`, `OpenCodeClient/OpenCodeClient/Views/Chat/ChatTabView.swift:749`, `OpenCodeClient/OpenCodeClient/Views/Chat/ChatTabView.swift:1970`, `OpenCodeClient/OpenCodeClient/Views/Chat/ChatTabView.swift:2302`, (+24 more)). |
| POL-COLOR-10 | **PASS** | `DesignTokens.swift:100` defines `Semantic.info` as a second blue, distinct from `Brand.primary`; used at none. |
| POL-COLOR-11 | **FAIL** | `DesignTokens.swift:97` `Semantic.error = Color.red`; used at `OpenCodeClient/OpenCodeClient/Views/Chat/ChatTabView.swift:1775`, `OpenCodeClient/OpenCodeClient/Views/Chat/ChatTabView.swift:1902`, `OpenCodeClient/OpenCodeClient/Views/Chat/MessageRowView.swift:783`, (+12 more) for the error block that `design.md` §QT-PALETTE says must be accent + explicit text. |
| POL-COLOR-12 | **PARTIAL** | 1 `Color.red` sites: `OpenCodeClient/OpenCodeClient/Utils/DesignTokens.swift:97`. The recording mic and stop affordances are sanctioned by §QT-COMPOSER; the rest are error surfaces, which §QT-PALETTE assigns to accent. |
| POL-COLOR-13 | **REVIEW** | Not machine-checkable. The session-indicator contract (`docs/features/session_row_indicator/design.md`) documents its own exception. Needs a per-screen screenshot review against the §QT-PALETTE status table. |
| POL-COLOR-14 | **FAIL** | `DesignTokens.swift:98` defines `Semantic.success` as green; used at `OpenCodeClient/OpenCodeClient/Views/Chat/ChatTabView.swift:1903`, `OpenCodeClient/OpenCodeClient/Views/Chat/TodoListPanel.swift:55`, `OpenCodeClient/OpenCodeClient/Views/Chat/TaskNotificationCardView.swift:99`, (+2 more). §QT-PALETTE requires a `text.secondary` checkmark with no green. |
| POL-COLOR-15 | **FAIL** | `DesignTokens.swift:99` defines `Semantic.warning = Color.orange`; §QT-PALETTE requires gold text with an explanation and no orange block. |
| POL-COLOR-16 | **PASS** | `DesignTokens.swift:37` `Brand.gold` = `#D9A621`, used at `OpenCodeClient/OpenCodeClient/Views/Car/AmbientVoiceView.swift:234`, `OpenCodeClient/OpenCodeClient/Views/FileTreeView.swift:268`, `OpenCodeClient/OpenCodeClient/Views/SessionListView.swift:532` — all in the session-indicator / permission-pending path. |
| POL-COLOR-17 | **PASS** | 0 matches for `\.linearGradient\|\.radialGradient\|Gradient\(` in the app target. |
| POL-COLOR-18 | **PASS** | `DesignTokens.swift:324`–`328` define the three radii as 6 / 12 / 16 — exactly the spec's set. |
| POL-COLOR-19 | **FAIL** | 56 hardcoded numeric spacing values in Views (`OpenCodeClient/OpenCodeClient/Views/Chat/ChatTabView.swift:701`, `OpenCodeClient/OpenCodeClient/Views/Chat/ChatTabView.swift:717`, `OpenCodeClient/OpenCodeClient/Views/Chat/ChatTabView.swift:799`, `OpenCodeClient/OpenCodeClient/Views/Chat/ChatTabView.swift:1098`, `OpenCodeClient/OpenCodeClient/Views/Chat/ChatTabView.swift:1779`, (+51 more)). |
| POL-TYPE-01 | **FAIL** | `DesignTypography` resolves to seven distinct sizes — {20, 17, 17, 16, 12, 11, 11} pt across its roles (`DesignTokens.swift:223`–`244`). The spec's four-step scale 22/16/13/12 is not implemented, and there is a fifth step (`headline`) that the scale does not contain. |
| POL-TYPE-02 | **FAIL** | `DesignTokens.swift:223` `display = .title3.weight(.bold)` → 20 pt; §QT-TYPE specifies 22 pt. |
| POL-TYPE-03 | **FAIL** | `DesignTokens.swift:231` `body = .body` → 17 pt; §QT-TYPE specifies 16 pt. |
| POL-TYPE-04 | **PARTIAL** | `DesignTokens.swift:235` `bodyProminent = .callout` → 16 pt ✓ size, but the weight is regular; §QT-TYPE specifies Medium. |
| POL-TYPE-05 | **FAIL** | `DesignTokens.swift:238` `meta = .caption` → 12 pt; §QT-TYPE specifies 13 pt. |
| POL-TYPE-06 | **FAIL** | `DesignTokens.swift:241` `micro = .caption2` → 11 pt; §QT-TYPE specifies 12 pt. |
| POL-TYPE-07 | **FAIL** | 7 literal `.system(size:)` sites: `OpenCodeClient/OpenCodeClient/Views/Chat/ChatTabView.swift:1080`, `OpenCodeClient/OpenCodeClient/Views/Chat/MessageRowView.swift:802`, `OpenCodeClient/OpenCodeClient/Views/Support/FileContentReuseFixture.swift:110`, `OpenCodeClient/OpenCodeClient/Views/Support/FileSearchFixture.swift:239`, `OpenCodeClient/OpenCodeClient/Views/Support/FileSearchFixture.swift:245`, `OpenCodeClient/OpenCodeClient/ContentView.swift:237`, (+1 more). |
| POL-TYPE-08 | **FAIL** | 92 semantic system-font call sites in Views against 140 `DesignTypography.*` uses. |
| POL-TYPE-09 | **PASS** | No third-party font registration in the app target. |
| POL-TYPE-10 | **FAIL** | The tokens use semantic system fonts, which scale, but they do not resolve to the mandated nominal sizes. An exact 22/16/13/12 scale that still scales needs the D1 `Font.custom(..., relativeTo:)` form, which is not implemented — and per PRY-22 must be validated on a device first. |
| POL-TYPE-11 | **FAIL** | **The title is deliberately absent.** `Views/Chat/MessageRowView.swift:825` reads `// No "OpenCode" speaker title — the user's blue left-bar vs the`. §QT-SPEAKER requires an `OpenCode` text title and no avatar, so the code contradicts the written spec — and the code comment still describes the *removed* accent-stripe user message. See the plan's Open Questions. |
| POL-TYPE-12 | **PASS** | The model caption is retained at the foot of each AI reply. |
| POL-TYPE-13 | **FAIL** | 7 `.font(.system(size: 1))` probe hacks (`OpenCodeClient/OpenCodeClient/Views/Chat/ChatTabView.swift:1080`, `OpenCodeClient/OpenCodeClient/Views/Chat/MessageRowView.swift:802`, `OpenCodeClient/OpenCodeClient/Views/Support/FileContentReuseFixture.swift:110`, `OpenCodeClient/OpenCodeClient/Views/Support/FileSearchFixture.swift:239`, `OpenCodeClient/OpenCodeClient/Views/Support/FileSearchFixture.swift:245`, (+2 more)) and no `Utils/AccessibilityProbe.swift`. |
| POL-CARD-01 | **PASS** | No `.stroke(` on an information card: the 6 stroke sites in Views are on controls, rings and the microphone meter (`OpenCodeClient/OpenCodeClient/Views/Chat/ChatComposerPreviews.swift:117`, `OpenCodeClient/OpenCodeClient/Views/Chat/SessionChangesView.swift:129`, `OpenCodeClient/OpenCodeClient/Views/Chat/ContextUsageView.swift:139`, `OpenCodeClient/OpenCodeClient/Views/Chat/ContextUsageView.swift:143`, (+2 more)), none on a tool or patch card. |
| POL-CARD-02 | **REVIEW** | Needs a per-element review of the tool row's icon / name / subject line / chevron against `Brand.primary`. Not machine-checkable today. |
| POL-CARD-03 | **PARTIAL** | The action-card stripe widths are inconsistent: `OpenCodeClient/OpenCodeClient/Views/Chat/PermissionCardView.swift:23`, `OpenCodeClient/OpenCodeClient/Views/Chat/QuestionCardView.swift:44`. §QT-CARD requires 3 pt on both the permission and the question card. |
| POL-CARD-04 | **REVIEW** | Turn-activity rows render as plain `text.secondary` lines with no container — confirmed by reading the status-row block; kept as a review row because there is no automated predicate. |
| POL-CARD-05 | **PASS** | Tool and patch cards use `DesignCorners.medium` (12 pt) — `OpenCodeClient/OpenCodeClient/Views/Chat/ChatTabView.swift:1967`, `OpenCodeClient/OpenCodeClient/Views/Chat/ChatTabView.swift:1969`, `OpenCodeClient/OpenCodeClient/Views/Chat/QuestionCardView.swift:75`, `OpenCodeClient/OpenCodeClient/Views/Chat/PermissionCardView.swift:101`, (+12 more). |
| POL-CARD-06 | **PASS** | `Views/Chat/ToolCardClassifier.swift:190` routes exactly `apply_patch, edit_file, write_file, read_file`. |
| POL-CARD-07 | **PASS** | `MessageRowView.swift:34` derives the column count from the layout — 2 for compact, 3 for regular. |
| POL-CARD-08 | **PASS** | Each tool call renders its own row (icon, name, subject line, status, chevron); there is no merged group in the Views layer — `toolCallsCount` survives only at none, which is a classifier helper, not a rendered group. |
| POL-CARD-09 | **PASS** | `MessageRowView.swift:164` packs file cards into rows of the grid column count and gives every thinking and tool-call tile its own full-width row (`isFullWidth: true` at `OpenCodeClient/OpenCodeClient/Views/Chat/MessageRowView.swift:181`). |
| POL-CARD-10 | **PASS** | Text and attachment blocks sit outside the grid and render full width after it. |
| POL-CARD-11 | **PASS** | No `Files updated` / `Actions` category heading exists in the app target. |
| POL-CARD-12 | **PASS** | No sprite or texture assets in the card layer; the implementation uses SF Symbols and vector shapes only. |
| POL-MESSAGE-01 | **FAIL** | **The user message is no longer a stripe.** The merged spec (§QT-MESSAGE) changed it to a right-aligned bubble capped at 320 pt with one tucked corner, and the code follows: `Views/Chat/MessageRowView.swift` uses `DesignControls.userBubbleMaxWidth` and a neutral surface tint. There is no accent stripe left (0 matches for one) and no `accentStripe` token. |
| POL-MESSAGE-02 | **FAIL** | The bubble fill is `DesignColors.Neutral.text.opacity(surfaceFill)` — a neutral surface tint, not the spec's `accent.muted`. `Opacity.userMessageFill` no longer exists (0 matches); the token file now has `userMessageBorder`. |
| POL-MESSAGE-03 | **PASS** | The AI reply body renders on the background with no container, no fill and no stripe. |
| POL-MESSAGE-04 | **PARTIAL** | `DesignTokens.swift:269` `messageVertical = 20` ✓ for iPhone; there is no 28 pt large-screen variant. |
| POL-MESSAGE-05 | **FAIL** | `DesignTokens.swift:271` `cardPadding = 12`; §QT-MESSAGE specifies 14 pt (iPhone) / 18 pt (iPad). |
| POL-MESSAGE-06 | **FAIL** | No horizontal-margin token; margins are among the 56 hardcoded spacing values. |
| POL-MESSAGE-07 | **FAIL** | No 720 pt content cap: the content blocks use `.frame(maxWidth: .infinity)`. |
| POL-COMPOSER-01 | **PASS** | The composer field is filled with the `composerDark`/`composerLight` tokens and applies no stroke — `OpenCodeClient/OpenCodeClient/Views/Chat/ComposerPasteControl.swift:85`. |
| POL-COMPOSER-02 | **REVIEW** | Send is a solid accent rounded-rectangle hugging the field's bottom-right; confirmed visually in the existing fixture screenshots, but no automated predicate exists. |
| POL-COMPOSER-03 | **REVIEW** | The mic renders inside the field's leading edge in `text.secondary`; visual confirmation only. |
| POL-COMPOSER-04 | **PASS** | The send button is never removed by the running state — `stop` is added as an additional button above it in the same right-hand VStack. |
| POL-COMPOSER-05 | **PASS** | Send and stop are stacked in the right-hand VStack with send in the bottom slot and stop above it. |
| POL-COMPOSER-06 | **PASS** | Stop uses red for interrupt semantics — `OpenCodeClient/OpenCodeClient/Utils/DesignTokens.swift:97`. |
| POL-COMPOSER-07 | **PASS** | The mic keeps a fixed bottom-left slot across voice states; the retry and discard actions occupy the same slot without moving send. |
| POL-COMPOSER-08 | **PASS** | During transcription and retry the transcript appends and the field auto-scrolls to the end; the manual-edit path keeps the system default. |
| POL-COMPOSER-09 | **PASS** | The forced scroll is applied only on the voice/retry path; the draft-restore and manual-edit paths do not force it. |
| POL-COMPOSER-10 | **PASS** | The permission and question action buttons use `.buttonStyle(.plain)` text buttons with no 44 pt target. The precedent exists — `Utils/EffectiveLayout.swift:232` `minimum = 44` — but is not applied to these cards. |
| POL-MOTION-01 | **FAIL** | No entrance transition on a user message: `grep -rnE "transition\(\|\.transition" MessageRowView.swift` → 0 matches. |
| POL-MOTION-02 | **FAIL** | The tool row expands with `withAnimation(DesignAnimation.spring)` (none) and `DesignTokens.swift:347` defines that spring as response 0.35 / damping 0.80 — §QT-MOTION specifies response 0.32 / damping 0.82. The tool row no longer uses the system `DisclosureGroup`; the only one left in Views is `OpenCodeClient/OpenCodeClient/Views/Chat/TaskNotificationCardView.swift:29`. |
| POL-MOTION-03 | **FAIL** | No slide-in entrance on the permission/question cards; no `transition` modifier on either card. |
| POL-MOTION-04 | **FAIL** | No session-switch crossfade on the message list. |
| POL-MOTION-05 | **PASS** | The streaming text path applies no entrance animation — streaming text renders directly. |
| POL-MOTION-06 | **FAIL** | The thinking card's toggle is wrapped in `withAnimation` (`OpenCodeClient/OpenCodeClient/Views/Chat/MessageRowView.swift:1076`), so the row does not grow in place as §QT-MOTION requires — the merged code animates it with the same spring as the tool row. The tool row's expansion is a separate rule — see POL-MOTION-02. |
| POL-MOTION-07 | **FAIL** | `DesignTokens.swift:350` `gentleSpring = Animation.spring(response: 0.4, dampingFraction: 0.85)` — response 0.4 exceeds the 0.35 ceiling. |
| POL-MOTION-08 | **PASS** | No splash or launch animation in the app entry. |
| POL-MOTION-09 | **FAIL** | There is no `DesignMotion` layer at all. Raw durations are used at `OpenCodeClient/OpenCodeClient/Views/Chat/ChatTabView.swift:1682`, `OpenCodeClient/OpenCodeClient/Views/FileContentView.swift:506`, `OpenCodeClient/OpenCodeClient/Views/FileContentView.swift:533`. |
| POL-MOTION-10 | **PARTIAL** | Reduce Motion is honoured at 26 sites, but none of the four missing motions exist yet, so the coverage cannot be complete. |
| POL-HAPTIC-01 | **PASS** | `.messageSent` fires at `OpenCodeClient/OpenCodeClient/Views/Chat/ChatTabView.swift:1732`. Signature: `lightImpact`. |
| POL-HAPTIC-02 | **PASS** | `.permissionArrived` fires at `OpenCodeClient/OpenCodeClient/AppState.swift:1240`. Signature: `softImpact`. |
| POL-HAPTIC-03 | **PASS** | `.questionArrived` fires at `OpenCodeClient/OpenCodeClient/AppState.swift:1250`. Signature: `mediumImpact`. |
| POL-HAPTIC-04 | **PASS** | `.sendFailed` fires at `OpenCodeClient/OpenCodeClient/Views/Chat/ChatTabView.swift:1755`. Signature: `errorNotification`. |
| POL-HAPTIC-05 | **PASS** | `.destructiveConfirmed` fires at `OpenCodeClient/OpenCodeClient/Views/SessionListView.swift:153`. Signature: `warningNotification`. |
| POL-HAPTIC-06 | **PASS** | `.selectionChanged` fires at `OpenCodeClient/OpenCodeClient/Views/SessionListView.swift:195`. Signature: `selectionChange`. |
| POL-HAPTIC-07 | **PASS** | `.recordingStarted` fires in `Views/Chat/ChatTabView+VoiceInput.swift` **before** the microphone opens, so the click lands ahead of the capture window. `.recordingStopped` fires after `stoppingMicrophone.stop()` completes, so the engine is already closed, and also on the three failure paths, so the pair is always balanced except on the cancel and navigation paths — which release the microphone deliberately without pairing it. Signatures: `rigidImpact` / `heavyImpact`. |
| POL-HAPTIC-08 | **PASS** | `DesignHapticEvent.isAllowed(reduceMotion:microphoneOpen:)` suppresses **every** event while the microphone is open — there is no blanket exemption. The guard cannot be bypassed: `DesignHaptics.fire(_:microphoneOpen:)` has **no default** for the flag, so every one of the 10 call sites must state the capture state, and all of them pass the single authoritative `AppState.isMicrophoneCaptureActive` — which covers the Ambient/Car live-voice capture (`CarLiveController.isMicrophoneCaptureActiveForPolicy`, including the run-scoped `captureStartPendingToken` window that spans the `startCapture` await) and the chat composer capture (`AppState.chatSpeechCaptureActive`). Asserted by `DesignHapticsTests.microphoneGuardSuppressesEveryEvent`. |
| POL-HAPTIC-09 | **PASS** | The policy is written in `docs/design.md` §QT-HAPTIC: Reduce Motion drops confirming events and keeps alerting ones; silent mode does not suppress haptics — a written policy, not a platform guarantee. The Reduce Motion half is asserted by `DesignHapticsTests.reduceMotionKeepsAlertingEventsAndDropsConfirmingOnes`; the silent-mode half is canaried by `DesignHapticsTests.theSilentModePolicyIsUnchanged` and enforced by review. |
| POL-STATE-01 | **PARTIAL** | The empty session list shows brand copy rather than "No sessions", but `docs/design.md` §QT-EMPTY asks for the **dark logo** asset and only `logo_light.png` ships. |
| POL-STATE-02 | **PASS** | `DesignTokens.swift:373` `breathing = Animation.easeInOut(duration: 3.0).repeatForever(autoreverses: true)` — 3 s cycle ✓; the 1.0→1.02→1.0 amplitude is applied at the call site. |
| POL-STATE-03 | **PASS** | The empty chat shows centred guidance text with no icon. |
| POL-STATE-04 | **REVIEW** | A per-surface checklist, not a single predicate. Completed by the Phase 0 per-surface acceptance list in `rubric.md`. |
| POL-STATE-05 | **REVIEW** | Per-surface; the host-profile and composer surfaces already distinguish the failure path, the chat stream needs a check. |
| POL-STATE-06 | **PASS** | The pending-sync caption and the green/blue withholding rule are implemented and covered by `SessionIndicatorTests` / `SessionReadStateStoreTests`. |
| POL-STATE-07 | **REVIEW** | The host-profile surface has an explicit disconnected state; the session list needs a check. |
| POL-ERROR-01 | **FAIL** | 24 user-facing sites surface a raw `localizedDescription`: `OpenCodeClient/OpenCodeClient/Views/Chat/ChatTabView.swift:1800`, `OpenCodeClient/OpenCodeClient/Views/Chat/ChatTabView+VoiceInput.swift:250`, `OpenCodeClient/OpenCodeClient/Views/Chat/ChatTabView+VoiceInput.swift:252`, `OpenCodeClient/OpenCodeClient/Views/Chat/ChatTabView+VoiceInput.swift:363`, `OpenCodeClient/OpenCodeClient/Views/Chat/ChatTabView+VoiceInput.swift:364`, (+19 more). The remainder are logger calls, which are fine. |
| POL-ERROR-02 | **PASS** | `docs/design.md` §QT-MOCKUP specifies the Basic Auth guidance copy, and the host-profile diagnostic path renders a mapped message rather than the raw error. |
| POL-ERROR-03 | **REVIEW** | Copy review per error surface. |
| POL-ERROR-04 | **REVIEW** | Enforced by the mandatory privacy review at merge, not by an automated check. |
| POL-ERROR-05 | **REVIEW** | A process gate, evidenced by the independent code/privacy review records cited in `docs/WORKING.md`. |
| POL-A11Y-01 | **PASS** | Accessibility API usage is broad — 300 occurrences across Views — and the accessibility-probe pattern shows labels are attached deliberately rather than incidentally. |
| POL-A11Y-02 | **PASS** | The composer activity text was restored specifically so the decorative light is not announced twice (`docs/WORKING.md`, 2026-10-14 entry). |
| POL-A11Y-03 | **PASS** | Covered by the UI assertions for the five row types with a ≤ 1.5 pt deviation (`docs/WORKING.md`, 2026-10-14 session-indicator follow-up). |
| POL-A11Y-04 | **PASS** | `DesignTokens.swift:279`–`288` define the indicator column, the dots and the hierarchy; the 44 pt chevron hit area is asserted in the UI tests. |
| POL-A11Y-05 | **REVIEW** | A manual on-device check at `accessibility3`, applied per surface by the per-surface acceptance list. |
| POL-A11Y-06 | **REVIEW** | A manual `zh-Hans` check per surface. Known risk: a fixed close-button width (none) can clip in long locales. |
| POL-A11Y-07 | **PASS** | A fixed `width: 88` close button survives at none. |
| POL-PREVIEW-01 | **PASS** | Exactly 8 file in the app target has a `#Preview` (`OpenCodeClient/OpenCodeClient/Views/Chat/ChatComposerPreviews.swift:208`, `OpenCodeClient/OpenCodeClient/Views/Chat/ChatComposerPreviews.swift:212`, `OpenCodeClient/OpenCodeClient/Views/Chat/ChatComposerPreviews.swift:216`, (+5 more)) against 16+ screen views. |
| POL-PREVIEW-02 | **FAIL** | Follows from POL-PREVIEW-01 — with one preview there is no suite isolation to audit. The isolation pattern is documented in `docs/tests.md`. |
| POL-PREVIEW-03 | **REVIEW** | The `Views/Support/` fixture set is credential-free by construction; each new preview must be checked against it at review time. |

## Counts

| State | Rows |
|---|---|
| PASS | 45 |
| PARTIAL | 7 |
| FAIL | 36 |
| REVIEW | 14 |
| **Total** | **102** |

| Family | PASS | PARTIAL | FAIL | REVIEW | Total |
|---|---|---|---|---|---|
| `POL-COLOR` | 4 | 2 | 12 | 1 | 19 |
| `POL-TYPE` | 2 | 1 | 10 | 0 | 13 |
| `POL-CARD` | 9 | 1 | 0 | 2 | 12 |
| `POL-MESSAGE` | 1 | 1 | 5 | 0 | 7 |
| `POL-COMPOSER` | 8 | 0 | 0 | 2 | 10 |
| `POL-MOTION` | 2 | 1 | 7 | 0 | 10 |
| `POL-HAPTIC` | 9 | 0 | 0 | 0 | 9 |
| `POL-STATE` | 3 | 1 | 0 | 3 | 7 |
| `POL-ERROR` | 1 | 0 | 1 | 3 | 5 |
| `POL-A11Y` | 5 | 0 | 0 | 2 | 7 |
| `POL-PREVIEW` | 1 | 0 | 1 | 1 | 3 |
| **All families** | 45 | 7 | 36 | 14 | **102** |

## Measured quantities

| Quantity | Count |
|---|---|
| raw colour literals (app target) | 8 |
| ad-hoc `.opacity(` (Views) | 29 |
| hardcoded spacing values (Views) | 56 |
| semantic system-font sites (Views) | 92 |
| literal `.system(size:)` sites (app target) | 7 |
| `.stroke(` sites (Views) | 6 |
| gradients | 0 |
| `DesignTypography.*` uses (Views) | 140 |
| `DesignColors.*` uses (Views) | 226 |
| haptic firing sites (app target) | 10 |
| distinct haptic events | 8 |
| accessibility API calls (Views) | 300 |
| reduce-motion sites (app target) | 26 |
| `DisclosureGroup` sites (Views) | 1 |
| `#Preview` sites (app target) | 8 |
| TODO/FIXME markers (app target) | 0 |

