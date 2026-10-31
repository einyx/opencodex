# Polish Rubric

The machine-checkable form of the **Quiet Tech** spec. One row per checkable condition.
This is the *definition of done* for the "superpolished app experience" initiative — a
PR cannot be reviewed against taste, only against these rows.

> **Status:** draft v1 — awaiting a rubric owner (see [Open Questions](plan.md#open-questions-for-the-team)).
> **Authority:** the `QT-*` clause IDs live in [`docs/design.md`](../../design.md).
> **Measured baseline:** [`audit.md`](audit.md) records where the app stands against
> each row today.
> **Plan:** [`plan.md`](plan.md).

## How to read a row

| Column | Meaning |
|---|---|
| **ID** | Stable identifier. Never renumbered; retired rows are kept with their final state so the audit history stays readable. |
| **Rule** | What must be true, stated so that it can be true or false. |
| **Source** | `QT-*` = a clause in `docs/design.md` · `REPO` = a repo constraint (`AGENTS.md` / `PROJECT-CONTEXT.md`) · `INIT` = introduced by this initiative (`plan.md`) |
| **Check** | The machine-checkable predicate. Where a check is a grep, the exact pattern is given. |
| **Enforcement** | `lint` → a rule in `scripts/polish_lint.sh` · `test` → an assertion in XCTest · `screenshot` → a fixture screenshot reviewed against a *textual* description (PNGs are never committed, `docs/tests.md:216`) · `review` → human code review · `manual` → on-device check |
| **Scope** | `all` · a screen name · `ios-only` · `android-shared` (the sibling Android client must match) · `deferred` |

`ios-only` and `android-shared` are the parity split required by
`docs/design.md` §QT-PRINCIPLE §7 and §QT-PALETTE (session-indicator optical sizes).
A rubric row with no parity tag is treated as `ios-only` for the shared-core surfaces
until the Android client is checked.

---

## Colour and token discipline

| ID | Rule | Source | Check | Enforcement | Scope |
|---|---|---|---|---|---|
| POL-COLOR-01 | Dark-mode `bg.primary` is `#0B0C0E` | `QT-PALETTE` | `DesignTokens.swift` `Brand`/`Neutral` token equals `#0B0C0E` | test | all |
| POL-COLOR-02 | Dark-mode `bg.secondary` is `#141619` | `QT-PALETTE` | token equals `#141619` | test | all |
| POL-COLOR-03 | Dark-mode `surface` is `#1A1D21` | `QT-PALETTE` | token equals `#1A1D21` | test | all |
| POL-COLOR-04 | Text tokens are `#ECEDEE` / `#9BA1A6` / `#5A6066` | `QT-PALETTE` | three tokens equal those hexes | test | all |
| POL-COLOR-05 | The brand accent is exactly one blue: `#3B82F6` dark, `#2563EB` light | `QT-PALETTE` | `Brand.primary` equals `#3B82F6` and its light variant `#2563EB` | test | all |
| POL-COLOR-06 | `accent.muted` is the accent at 8% alpha | `QT-PALETTE` | opacity token == 0.08 | test | all |
| POL-COLOR-07 | Light mode maps the *same* token set, it is not a separate palette | `QT-PALETTE` | no light-only token names outside `DesignColors` | test | all |
| POL-COLOR-08 | No raw system colour literal in any View | `QT-LANDING` | `grep -rEn "Color\.(red\|blue\|green\|orange\|purple\|pink\|yellow\|black\|white\|gray\|grey)" OpenCodeClient/OpenCodeClient --include="*.swift"` → 0 outside the allowlist | lint | all |
| POL-COLOR-09 | No ad-hoc `.opacity(` — opacity comes from `DesignColors.Opacity` | `QT-LANDING` | `grep -rEn "\.opacity\(" Views --include="*.swift" \| grep -v DesignColors.Opacity` → 0 | lint | all |
| POL-COLOR-10 | There is no second blue: `DesignColors.Semantic.info` must not exist | `QT-PALETTE` | `grep -rn "Semantic.info" OpenCodeClient/OpenCodeClient --include="*.swift"` → 0 | lint | all |
| POL-COLOR-11 | Error surfaces use `accent` + explicit text, never a red background block | `QT-PALETTE` | `grep -rn "Semantic.error" Views --include="*.swift"` → 0 | lint | chat |
| POL-COLOR-12 | Red is reserved for destructive operations | `QT-PALETTE` | each `Color.red` site is a destructive or recording affordance and is allowlisted | review | all |
| POL-COLOR-13 | At most one coloured element is visible per screen | `QT-PALETTE` | per-screen review against the spec's status table | screenshot | all |
| POL-COLOR-14 | Success is a checkmark in `text.secondary`, never green | `QT-PALETTE` | `grep -rn "Semantic.success"` → 0 | lint | all |
| POL-COLOR-15 | Warning uses gold text with an explanation, never an orange block | `QT-PALETTE` | `grep -rn "Semantic.warning"` → 0 | lint | all |
| POL-COLOR-16 | Gold is used only for the pending permission/issue indicator | `QT-PALETTE` | every gold site is a session-indicator or permission-pending light | review | sessions, chat |
| POL-COLOR-17 | No gradients anywhere | `QT-NONGOAL` | `grep -rEn "\.linearGradient\|\.radialGradient\|Gradient(" OpenCodeClient/OpenCodeClient --include="*.swift"` → 0 | lint | all |
| POL-COLOR-18 | Corner radii are unified: 12 pt cards, 16 pt sheets, 6 pt inline tags — never mixed | `QT-CARD` | `DesignCorners` == {small 6, medium 12, large 16}; no literal radius at a card site | test, lint | all |
| POL-COLOR-19 | No raw spacing literal in a View — spacing comes from `DesignSpacing` | `QT-LANDING` | `grep -rEn "\.(padding\|spacing)\([^)]*[0-9]" Views --include="*.swift" \| grep -v DesignSpacing` → 0 | lint | all |

## Typography

| ID | Rule | Source | Check | Enforcement | Scope |
|---|---|---|---|---|---|
| POL-TYPE-01 | The type scale has exactly four steps: 22 / 16 / 13 / 12 | `QT-TYPE` | `DesignTypography` exposes no size other than {22, 16, 13, 12} (+ the 16 pt `bodyProminent` weight variant) | test | all |
| POL-TYPE-02 | `display` is 22 pt semibold | `QT-TYPE` | token resolves to 22 pt | test | sessions |
| POL-TYPE-03 | `body` is 16 pt regular with 1.45 line height | `QT-TYPE` | token resolves to 16 pt | test | all |
| POL-TYPE-04 | `bodyProminent` is 16 pt medium — user messages differ by weight, not colour | `QT-TYPE` | token resolves to 16 pt medium | test | chat |
| POL-TYPE-05 | `meta` is 13 pt regular in `text.secondary` | `QT-TYPE` | token resolves to 13 pt | test | all |
| POL-TYPE-06 | `micro` is 12 pt regular in `text.tertiary`, monospaced for code and paths | `QT-TYPE` | token resolves to 12 pt | test | all |
| POL-TYPE-07 | No literal `.font(.system(size:))` in a View | `QT-LANDING` | `grep -rEn "\.system\(size:" OpenCodeClient/OpenCodeClient --include="*.swift"` → 0 outside the allowlist | lint | all |
| POL-TYPE-08 | No semantic system font (`.caption`, `.body`, `.subheadline`, …) in a View — use `DesignTypography` | `QT-LANDING` | `grep -rEn "\.font\(\.(caption2?\|body\|subheadline\|callout\|footnote\|headline\|title2?\|title3\|largeTitle)" Views --include="*.swift"` → 0 | lint | all |
| POL-TYPE-09 | Only SF system fonts — no third-party font | `QT-TYPE` | no `.custom(` font registration outside `DesignTokens` | lint | all |
| POL-TYPE-10 | Type scales with Dynamic Type (the scale is defined via `Font.custom(..., relativeTo:)`) | `INIT` (decision D1) | `DesignTypography` uses `Font.custom` with a `relativeTo:` base; verified at `accessibility3` on a device | test, manual | all |
| POL-TYPE-11 | An AI reply carries an `OpenCode` title and no avatar | `QT-SPEAKER` | every AI-reply row renders the title; no circular avatar | screenshot, review | chat |
| POL-TYPE-12 | The model caption stays at the bottom of each AI reply, unchanged | `QT-SPEAKER` | caption present and in the same position | screenshot | chat |
| POL-TYPE-13 | The accessibility probe uses one named helper, not inline `size: 1` fonts | `INIT` | `grep -rn "system(size: 1)"` → 0; `Utils/AccessibilityProbe.swift` exists | lint | all |

## Card and tile shapes

| ID | Rule | Source | Check | Enforcement | Scope |
|---|---|---|---|---|---|
| POL-CARD-01 | Information cards have no stroke — `surface` fill only | `QT-CARD` | no `.stroke(` on an info card | lint, review | chat |
| POL-CARD-02 | Interactive elements *inside* an info card are accent-coloured (icon, tool name, path, chevron) | `QT-CARD` | those four elements use `Brand.primary` | review | chat |
| POL-CARD-03 | Action cards (permission, question) use a 3 pt accent leading stripe on a `surface` fill | `QT-CARD` | stripe width == 3 | test, review | chat |
| POL-CARD-04 | Status rows are not cards — a single line of `text.secondary` | `QT-CARD` | no container on turn-activity rows | review | chat |
| POL-CARD-05 | Tool and patch cards use a 12 pt radius | `QT-CARD` | `DesignCorners.medium` at the site | test | chat |
| POL-CARD-06 | File-operation tools (`apply_patch`, `edit_file`, `write_file`, `read_file`) render as file cards | `QT-FILECARD` | classifier routes exactly that set | test | chat |
| POL-CARD-07 | File cards sit in a 2-column grid on iPhone, 3 on iPad | `QT-FILECARD` | `cardGridColumnCount` is 2 for the compact layout and 3 for the regular one | test | chat |
| POL-CARD-08 | Every non-file tool renders its **own row** — there is no merged group | `QT-TOOLTILE` | each tool call is its own row (icon, name, subject line, status, chevron); no merged `N tool calls` group is rendered | test | chat |
| POL-CARD-09 | Only file cards share the grid; thinking and tool-call rows are full width | `QT-TILEGRID` | file cards are packed into rows of the grid column count (2 on iPhone, 3 on iPad); thinking and tool-call rows are `isFullWidth: true` | test | chat |
| POL-CARD-10 | Text and attachment blocks render full-width after the grid | `QT-TILEGRID` | reading order is grid → full-width text | screenshot | chat |
| POL-CARD-11 | No category headings ("Files updated", "Actions") and no extra grouping | `QT-TOOLBOUND` | `grep -rn "Files updated"` → 0; visual review | lint, review | chat |
| POL-CARD-12 | No pixel-art or texture treatment anywhere | `QT-TOOLBOUND` | no sprite/texture assets in the card layer | review | all |

## Message area

| ID | Rule | Source | Check | Enforcement | Scope |
|---|---|---|---|---|---|
| POL-MESSAGE-01 | A user message is a **right-aligned bubble**, capped at 320 pt, with one tucked corner (20 / 20 / 6 / 20) | `QT-MESSAGE` | `DesignControls.userBubbleMaxWidth` == 320 and the bubble uses an `UnevenRoundedRectangle` with radii 20 / 20 / 6 / 20 | test | chat |
| POL-MESSAGE-02 | A user message is filled with a **neutral surface tint** | `QT-MESSAGE` | the bubble's background is `DesignColors.Neutral.text.opacity(DesignColors.surfaceFill(for:))` | test | chat |
| POL-MESSAGE-03 | An AI reply has no container — plain `text.primary` on `bg.primary` | `QT-MESSAGE` | no background or stroke on the reply body | review | chat |
| POL-MESSAGE-04 | Message spacing is 20 pt on iPhone, 28 pt on iPad | `QT-MESSAGE` | spacing token resolves per layout branch | test | chat |
| POL-MESSAGE-05 | Card padding is 14 pt on iPhone, 18 pt on iPad | `QT-MESSAGE` | padding token resolves per layout branch | test | chat |
| POL-MESSAGE-06 | Horizontal margins are 16 pt on iPhone, 32 pt on iPad | `QT-LAYOUT` | margin token resolves per layout branch | test | chat |
| POL-MESSAGE-07 | The chat body is centred and capped at ~720 pt on large screens | `QT-LAYOUT` | `.frame(maxWidth:)` ≈ 720 on the iPad branch | review | chat |

## Composer

| ID | Rule | Source | Check | Enforcement | Scope |
|---|---|---|---|---|---|
| POL-COMPOSER-01 | The composer is one card — borderless `bg.secondary` fill, 16 pt radius, chips/status/actions inside it, no second floating band | `QT-COMPOSER` | no stroke on the field; no band above the card | review | composer |
| POL-COMPOSER-02 | Send is a solid accent circular button hugging the bottom row's trailing edge | `QT-COMPOSER` | shape + fill review | screenshot | composer |
| POL-COMPOSER-03 | The mic sits *inside* the field on the left | `QT-COMPOSER` | mic is a child of the field, `text.secondary` | screenshot | composer |
| POL-COMPOSER-04 | Send stays visible while the AI is running | `QT-COMPOSER` | send is never removed by the running state | test | composer |
| POL-COMPOSER-05 | Stop appears *above* send and never displaces it | `QT-COMPOSER` | both in the right-hand VStack, send in the bottom slot | screenshot | composer |
| POL-COMPOSER-06 | Stop uses red (interrupt / destructive semantics) | `QT-COMPOSER` | stop fill is red | review | composer |
| POL-COMPOSER-07 | The mic is fixed in the bottom-left slot; no transient voice state moves send | `QT-COMPOSER` | mic and send positions invariant across voice states | screenshot | composer |
| POL-COMPOSER-08 | During voice transcription or retry, the transcript auto-scrolls to the end | `QT-COMPOSER` | transcript append scrolls to end | test | composer |
| POL-COMPOSER-09 | During manual editing and draft restore, scrolling keeps the system default | `QT-COMPOSER` | no forced scroll outside the voice/retry path | test | composer |
| POL-COMPOSER-10 | Permission and question action buttons have a ≥ 44 pt hit target | `INIT` (WCAG 2.2) | `ComposerHitTarget.minimum` == 44 and applied to both card types | test | chat |

## Motion

| ID | Rule | Source | Check | Enforcement | Scope |
|---|---|---|---|---|---|
| POL-MOTION-01 | A user message enters with y 16→0 and opacity 0→1 over a 0.28 s ease-out | `QT-MOTION` | `DesignMotion.messageEnter` applied | test | chat |
| POL-MOTION-02 | The tool row expands with a custom spring of response 0.32, damping 0.82 | `QT-MOTION` | the expansion uses a spring whose response is 0.32 and damping 0.82; the tool row no longer uses the system `DisclosureGroup` | test, lint | chat |
| POL-MOTION-03 | Permission and question cards slide in from below (y 24→0) with a fade | `QT-MOTION` | `DesignMotion.cardEnter` applied | test | chat |
| POL-MOTION-04 | Switching sessions cross-fades the message list over 0.2 s | `QT-MOTION` | `DesignMotion.listCrossfade` applied | test | chat |
| POL-MOTION-05 | Streaming text has no entrance animation | `QT-MOTION` | no animation on the streaming text path | review | chat |
| POL-MOTION-06 | The thinking row toggles without an animation — it grows in place | `QT-MOTION` | the thinking card's tap handler toggles `expanded` with no `withAnimation`; the tool row's expansion is governed by POL-MOTION-02 | review | chat |
| POL-MOTION-07 | No bouncing springs; response ≤ 0.35 and duration ≤ 300 ms everywhere | `QT-MOTION` | `DesignAnimation` presets assert the ceiling | test | all |
| POL-MOTION-08 | No splash launch animation | `QT-NONGOAL` | no launch animation in the app entry | review | all |
| POL-MOTION-09 | Every `withAnimation` uses a named `DesignMotion` preset — no raw durations | `INIT` | `grep -rEn "withAnimation\(\.[a-z]\|withAnimation\([0-9]" Views` → 0 | lint | all |
| POL-MOTION-10 | Non-essential motion respects `accessibilityReduceMotion` | `QT-PRINCIPLE` §6 | each motion site reads the reduce-motion flag or is allowlisted | review, lint | all |

## Haptics

> These rows were introduced by this initiative. `docs/design.md` §QT-HAPTIC was added
> in Phase 4 to carry the sensory layer the original spec did not cover; the rows below
> cite it.

| ID | Rule | Source | Check | Enforcement | Scope |
|---|---|---|---|---|---|
| POL-HAPTIC-01 | Sending a message produces a haptic | `QT-HAPTIC` | a `DesignHaptics.fire(.messageSent)` site exists | review, lint (Phase 1) | composer, ios-only |
| POL-HAPTIC-02 | A permission request arriving produces a distinct haptic | `QT-HAPTIC` | site exists; its signature differs from every other event | review, lint (Phase 1) | chat, ios-only |
| POL-HAPTIC-03 | A question arriving produces a distinct haptic | `QT-HAPTIC` | site exists; its signature differs from every other event | review, lint (Phase 1) | chat, ios-only |
| POL-HAPTIC-04 | A failed send produces a distinct haptic | `QT-HAPTIC` | site exists; its signature differs from every other event | review, lint (Phase 1) | composer, ios-only |
| POL-HAPTIC-05 | A destructive confirmation produces a distinct haptic | `QT-HAPTIC` | site exists; its signature differs from every other event | review, lint (Phase 1) | all, ios-only |
| POL-HAPTIC-06 | A selection change produces a distinct haptic | `QT-HAPTIC` | site exists; its signature differs from every other event | review, lint (Phase 1) | all, ios-only |
| POL-HAPTIC-07 | Recording start and stop produce a distinct haptic | `QT-HAPTIC` | site exists; its signature differs from every other event | review, lint (Phase 1) | composer, ios-only |
| POL-HAPTIC-08 | No haptic fires while the microphone is open | `QT-HAPTIC` | `isAllowed(reduceMotion:microphoneOpen:)` suppresses **every** event when the microphone is open — no blanket exemption; **every** call site passes the shared `state.isMicrophoneCaptureActive` (the flag is mandatory — there is no default) | test | all, ios-only |
| POL-HAPTIC-09 | Silent mode and Reduce Motion have an explicit, documented policy | `QT-HAPTIC` | the **Reduce Motion** half is asserted in `DesignHapticsTests` (`.reduceMotionKeepsAlertingEventsAndDropsConfirmingOnes`); the **silent-mode** half is a written policy, not a platform guarantee, so it is enforced by review and canaried by `DesignHapticsTests` | test, review | all, ios-only |

## States: empty, loading, error

| ID | Rule | Source | Check | Enforcement | Scope |
|---|---|---|---|---|---|
| POL-STATE-01 | An empty session list shows the dark logo and brand copy — never "No sessions" | `QT-EMPTY` | copy review | screenshot | sessions |
| POL-STATE-02 | The empty-list logo breathes at 1.0→1.02→1.0 over 3 s | `QT-EMPTY` | scale animation present, amplitude == 0.02 | test | sessions |
| POL-STATE-03 | An empty chat shows concise centred guidance with no icon | `QT-EMPTY` | visual review | screenshot | chat |
| POL-STATE-04 | Every screen defines all three states — content, empty, error | `INIT` | per-screen checklist complete | review | all |
| POL-STATE-05 | A screen that can fail shows guidance, never an empty state | `INIT` | failure path renders a message | review | all |
| POL-STATE-06 | Unreachable status degrades to the neutral `状态待同步` caption, not a stale colour | `REPO` | pending-sync caption present; green/blue withheld | test | sessions, chat |
| POL-STATE-07 | A disconnected host state is stated explicitly, never implied by an empty list | `REPO` | disconnect caption present | review | all |

## Errors and privacy

| ID | Rule | Source | Check | Enforcement | Scope |
|---|---|---|---|---|---|
| POL-ERROR-01 | A raw Swift error is never shown to the user | `REPO` | `grep -rn "error.localizedDescription" Views` shows no direct UI use; each site has a mapped message | lint, review | all |
| POL-ERROR-02 | A Basic Auth failure reads as guidance, not a stack trace | `QT-MOCKUP` | the message names the cause and the remedy | review | hosts |
| POL-ERROR-03 | An error banner states what happened and what to do next | `QT-PALETTE` | banner copy review | review | all |
| POL-ERROR-04 | A tool payload, file path, or credential is never newly exposed by an error surface | `REPO` (privacy) | privacy review at merge | review | all |
| POL-ERROR-05 | The privacy review gate is satisfied for any change touching tokens, credentials, audio, or transport | `REPO` | review record attached to the PR | review | all |

## Accessibility

| ID | Rule | Source | Check | Enforcement | Scope |
|---|---|---|---|---|---|
| POL-A11Y-01 | Every interactive control has a localised accessibility label | `QT-PRINCIPLE` | no `accessibilityLabel` gap on a control | lint | all |
| POL-A11Y-02 | Decorative status lights are not announced twice — the text carries the meaning | `REPO` | the indicator is excluded from the AX tree when the text states it | review | sessions, chat |
| POL-A11Y-03 | The session indicator is vertically centred against the whole text block, no absolute y offset | `REPO` | light centre deviation ≤ 1.5 pt for all five row types | test | sessions |
| POL-A11Y-04 | The indicator column keeps 12→18 pt and the 44 pt collapsed touch area | `REPO` | geometry assertion | test | sessions |
| POL-A11Y-05 | Layout survives Dynamic Type at `accessibility3` | `REPO` | per-screen acceptance list | manual | all |
| POL-A11Y-06 | Layout survives `zh-Hans` and long-locale strings | `REPO` | per-screen acceptance list; no fixed width clips a label | manual | all |
| POL-A11Y-07 | No fixed width may clip a localised label | `INIT` | `SessionListView.swift:29` fixed `width: 88` is replaced | review, test | sessions |

## Previews and fixtures

| ID | Rule | Source | Check | Enforcement | Scope |
|---|---|---|---|---|---|
| POL-PREVIEW-01 | Every screen-level View has at least one `#Preview` | `INIT` | `grep -rL "#Preview" <screen views>` → empty | lint | all |
| POL-PREVIEW-02 | Every preview runs on an isolated `UserDefaults` suite | `REPO` | `UserDefaults(suiteName:)` in every preview | review, lint | all |
| POL-PREVIEW-03 | No preview binds to a live server or embeds a real credential | `REPO` (privacy) | previews use the existing `Views/Support/` fixtures only | review | all |

---

## Per-surface acceptance criteria

Each surface is checked against the rubric rows that apply to it, plus the three
cross-cutting checks below, which apply everywhere.

**Cross-cutting, every surface**

1. Light and dark mode both reviewed.
2. Dynamic Type at `accessibility3` reviewed.
3. `zh-Hans` reviewed, including long-locale overflow.

| Surface | Rubric families that apply | Notes |
|---|---|---|
| Chat message stream | POL-MESSAGE-01…07, POL-CARD-01…12, POL-TYPE-11…12, POL-MOTION-01…06, POL-COMPOSER-10, POL-STATE-03, POL-ERROR-01…04 | The first vertical slice (Phase 5). Excludes the composer and voice rail. |
| Composer | POL-COMPOSER-01…10, POL-MOTION-01, POL-HAPTIC-01, POL-HAPTIC-04, POL-HAPTIC-07…09 | Sequenced **last** (Phase 7) — PRs #215/#216 await on-device acceptance. |
| Session list | POL-COLOR-13, POL-COLOR-16, POL-MESSAGE-06, POL-STATE-01…02, POL-STATE-06…07, POL-A11Y-02…04, POL-A11Y-07, POL-TYPE-02 | Blocked until the host-profile diff merged — **now merged** (`fe3ec83`). |
| Settings | POL-COLOR-13, POL-TYPE-01…06, POL-MOTION-10 | The "does the grammar generalise?" surface. Also exercises `design.md:238` (Dynamic Type on `LabeledContent`). |
| Host profiles | POL-COLOR-08, POL-ERROR-02…04, POL-A11Y-05…07, POL-STATE-04…05 | Also `design.md:242` (no raw Swift error). Requires the privacy review. |
| Files | POL-CARD-01…02, POL-TYPE-06, POL-STATE-04 | File preview is plain text with line numbers, no syntax highlighting (`QT-BOUNDARY`). |
| Car / Ambient | POL-COLOR-08, POL-TYPE-01, POL-MOTION-07…10, POL-HAPTIC-07…09 | Experimental surface; the mic level meter is exempt from the motion budget. |
| Preview / web | POL-TYPE-06, POL-STATE-04 | Markdown preview and image zoom. |
| Watch | POL-TYPE-01…06, POL-COLOR-08 | **`deferred`** — out of v1 by decision; `WatchAmbientApp.swift` has zero token usage and uses raw `.font(.caption)` / `.font(.system(size: 42))` / `.foregroundStyle(.orange)`. Gets a `DEFERRED` row, not silent coverage. |

---

## Counts

| Family | Rows |
|---|---|
| `POL-COLOR` | 19 |
| `POL-TYPE` | 13 |
| `POL-CARD` | 12 |
| `POL-MESSAGE` | 7 |
| `POL-COMPOSER` | 10 |
| `POL-MOTION` | 10 |
| `POL-HAPTIC` | 9 |
| `POL-STATE` | 7 |
| `POL-ERROR` | 5 |
| `POL-A11Y` | 7 |
| `POL-PREVIEW` | 3 |
| **Total** | **102** |
