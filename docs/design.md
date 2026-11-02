# OpenCode iOS Client Design Spec — Quiet Tech

This document is the implementation spec for the visual overhaul of the OpenCode iOS Client, not a review record. It supersedes the earlier "diagnosis + multi-direction recommendations" draft (the diagnostic conclusions remain valid and are appended at the end under "Diagnostic Retrospective"). The core goal is to converge the visual direction into a single design language named **Quiet Tech** and to break it down into concrete specifications that can directly guide SwiftUI implementation.

Design direction definition: look to modern developer tools such as Raycast, Vercel and Arc — a dark-first base tone with low saturation, relying on precise spacing and hairline strokes rather than elaborate decoration to convey a premium feel. The overall style stays restrained and understated; the quality comes from the consistency of the specification and a just-right whitespace rhythm.

This spec follows the same design methodology as the sister project VoiceFlow's `docs/design.md` (warm amber / deep ink): a single recognition color, colors do not carry hierarchy, borderless first, and ultra-light motion. The two apps share a family-style design language, while OpenCode leans colder in tone and puts more emphasis on its tooling nature.

## QT-INDEX · Clause Index

Every section of this spec carries a stable clause ID so that rubric items, lint rules,
and audit rows can reference one authority. The IDs are on the section headings; the
short form is what the rest of the initiative cites.

| Clause | Section | Governs |
|---|---|---|
| `QT-PRINCIPLE` | Design Principles | Dark-first, single accent, shape-over-colour, borderless-first, whitespace hierarchy, motion restraint, button stability |
| `QT-PALETTE` | Dual-Mode Palette | Dark/light token values, the terracotta accent, status semantics, the one-coloured-element rule |
| `QT-TYPE` | Typography | The four-step type scale, SF fonts, the type hierarchy |
| `QT-CARD` | Card Design Language | Information / action / status card shapes, corner radii |
| `QT-MESSAGE` | Message Area | User-message bubble, container-free AI replies, spacing |
| `QT-CHATSCREEN` | Chat Screen | Floating glass header and composer, transient turn state, one row per tool call |
| `QT-COMPOSER` | Composer | Input field, send, mic, stop, voice states, scroll behaviour |
| `QT-MOTION` | Motion | Entrance transitions, springs, crossfades, and what must not animate |
| `QT-HAPTIC` | Haptic Feedback | Named haptic events, the microphone guard, Reduce Motion and silent-mode policy, announce-once, haptics never replace a visual signal |
| `QT-LAYOUT` | Two Layout Strategies | iPhone single-column vs iPad/visionOS three-column, margins, content width cap |
| `QT-EMPTY` | Empty States and Guidance | Empty list and empty chat copy, logo breathing |
| `QT-NONGOAL` | Non-Goals | No gradients, no third-party fonts, no splash animation, no IA rework |
| `QT-BOUNDARY` | Feature Boundaries | What exists today, the baseline, what is explicitly excluded |
| `QT-LANDING` | Implementation Landing Points | `DesignTokens.swift` as the single token entry point; the ban on ad-hoc colours |
| `QT-MOCKUP` | Mockups | Session list, Settings, Host Profiles layout, swipe actions, error copy |
| `QT-RETRO` | Diagnostic Retrospective | The four original defects this spec exists to fix |
| `QT-SPEAKER` | Distinguishing Who Is Speaking | The OpenCode reply title, no avatar, retained model caption |
| `QT-FILECARD` | File Cards (2-Column Grid) | File-operation tools render as file cards |
| `QT-TOOLTILE` | One Row Per Tool Call | Every non-file tool renders its own row, expanded in place |
| `QT-TILEGRID` | File Cards Keep the Grid, Everything Else Is Full Width | The shared 2/3-column file-card grid, full-width rows and text after it |
| `QT-TOOLBOUND` | Non-Goals / Boundaries (tool cards) | No pixel style, no extra grouping, no category headings |

**Rubric pointer.** The machine-checkable form of this spec is
[`docs/features/polish/rubric.md`](features/polish/rubric.md) — one `POL-*` row per
checkable condition, each citing the clause it enforces. The measured baseline of the
current implementation against those rows is
[`docs/features/polish/audit.md`](features/polish/audit.md). The phase plan and
decision log is [`docs/features/polish/plan.md`](features/polish/plan.md).


## QT-PRINCIPLE · Design Principles

1. **Dark is the main stage, light is the understudy.** OpenCode's target users are developers, so dark mode is the default aesthetic baseline. The design prioritizes polishing dark mode; light mode is mapped from the same token set rather than the other way around.
2. **Single brand color: terracotta `#C96442`.** Sending, selection, and links use the brand terracotta on the warm ivory / warm near-black pages; everything else renders on the warm neutral scale. No blue accent anywhere. The Session single-indicator light is an explicit semantic exception: the list and the composer share yellow (pending), red (unacknowledged failure), green (execution not finished), and blue (unread updates after stop). Green uses a dedicated running token and does not reuse success; see the triage rules below.
3. **Semantics come from shape and position, not from piling on colors.** The core pain point today is "the same shape wearing multiple colors on one screen" (tool, patch, and permission cards are all rounded rectangles with a light fill and a stroke, distinguished only by color). The new scheme distinguishes functional categories through **card shape** and uses color only as an accent in a very few key places.
4. **Colors do not build hierarchy; font size and whitespace do.** Under unified text color, the primary/secondary relationship is expressed through size, weight, and spacing. Secondary grays are used only for genuinely secondary information (timestamps, file paths, and placeholders).
5. **Borderless first.** Informational containers drop strokes and keep only a very light fill or rely purely on whitespace for visual grouping; only cards that require a user response get an accent stripe on the leading edge as an action cue. Strokes in iOS usually imply form input fields, so they should be avoided in the chat message stream.
6. **Ultra-light, ultra-fast motion.** State transitions use a spring (response 0.3–0.35, damping 0.8) or a 250–300ms ease-out, preferring opacity crossfade over large positional moves. Motion is a lightweight means of raising quality; bouncing springs and show-off splash animations are firmly ruled out.
7. **Small screens keep functionality, large screens get whitespace.** See "Two Layout Strategies" below. Under the same token set and brand language, iPhone uses a compact single-column layout to preserve operational efficiency, while iPad and visionOS use a relaxed three-column layout that expresses spatial quality at different sizes.
8. **Stable buttons never change position.** Users have strong muscle memory for the send and mic buttons in the composer. The send and mic buttons must always stay fixed in their respective bottom slots of the vertical stack; transient action buttons such as stop or retry may only appear above them, and must never squeeze out or displace the permanent primary buttons.

## QT-PALETTE · Dual-Mode Palette

Both modes share the same set of semantic token definitions and only switch the mapping between base and text colors. In code, `DesignTokens` wraps dual values with `Color(light:dark:)`, and the View layer consistently references semantic names, avoiding ad-hoc `.opacity()` calls or direct use of system grays.

> **2026-10-26 — Warm Editorial adoption.** The palette below is Warm Editorial: the single accent is **terracotta `#C96442`**, pages are warm ivory / warm near-black, and there is **no blue accent anywhere** (it replaces the 2025-era electric-blue values and supersedes the 2026-10-25 "A1: design.md as-is is the authority" decision — `design.md` is still the authority; its palette section is what changed). The approved Settings refresh values (`#FAF9F5` / `#242422`, warm ink) became the shared page tokens rather than a settings-local palette. Session triage lights keep their own dedicated spec (exception below). Small accent text uses the darkened/lifted step `#B4573A` (light) / `#D2704C` (dark) because terracotta-on-ivory is ≈3.3:1.

### Dark Mode (Main Stage)

| Token | Hex | Usage |
|---|---|---|
| `bg.primary` | `#242422` | Main background, warm near-black |
| `bg.secondary` | `#191816` | Secondary background: composer input, sidebar, sheet, and settings groups |
| `surface` | `#1E1D1B` | Information card background (tool/patch output areas) |
| `text.primary` | `#EFEEE8` | Primary text, AI reply body (warm ink) |
| `text.secondary` | `#AAA79E` | Secondary information: timestamps, status, tool names |
| `text.tertiary` | `#6E6B62` | Placeholder, disabled state, code paths |
| `divider` | `rgba(239,238,232,.12)` | Hairline divider (1px, between sidebar/settings rows) |
| `accent` | `#D2704C` | The only brand recognition color: sending, selection, links, user message indicator bar (lifted terracotta for the dark base) |
| `accent.muted` | `#C9644214` | accent at 8% alpha, user message background and selected row background |
| `gold` | `#D9A621` | In the Session single indicator, a pending permission/issue; other historical components follow their own dedicated specs |

### Light Mode (Understudy)

| Token | Hex | Usage |
|---|---|---|
| `bg.primary` | `#FAF9F5` | Main background — warm ivory (Claude ivory) |
| `bg.secondary` | `#F1EDE6` | Secondary background |
| `surface` | `#F4F1EC` | Information card background (warm stone) |
| `text.primary` | `#292823` | Primary text (warm ink, not pure black) |
| `text.secondary` | `#73716A` | Secondary text |
| `text.tertiary` | `#9B958B` | Placeholder, disabled state |
| `divider` | `rgba(41,40,35,.10)` | Hairline divider |
| `accent` | `#B4573A` | Terracotta darkened one step on the ivory base for small-text contrast; icons, borders and semibold labels may use `#C96442` |
| `accent.muted` | `#C964420F` | accent at 6% alpha |
| `gold` | `#D9A621` | Pending / needs-you (unchanged) |
| `sage` | `#43745A` | Connected / ok (was the settings-local green; now shared) |

### Status Color Semantics (Replacing "Red/Green/Orange Dots")

Today red/green/orange express error/success/warning, which violates the single-recognition-color principle. The new scheme weakens the role of color and instead states each status explicitly through shape, structure, and text:

| Status | Expression |
|---|---|
| AI idle / ready | No color treatment, plain text |
| Session execution not finished | The dedicated green dot for the list and composer: light `#167C45` / dark `#4CBF82`, 6→9pt, 2.6s opacity 0.40–1.0; stays solid under Reduce Motion |
| Success / completion | A checkmark styled with `text.secondary` plus a text explanation, no green |
| Error | Uses `accent` (terracotta) to carry the warning together with explicit text, no red background block (red is reserved for destructive operations such as the delete-session confirmation button) |
| Warning | Uses `gold` text with an explanation, no orange background block |

At any moment, the entire screen may contain at most one colored element (accent or gold); everything else stays on the gray scale. This is a hard constraint that enforces the "calm" style.

**Exception: single-indicator triage semantics for the Session list and the composer.** Each row shows at most one light, with the priority: archived = no light, needs you = gold, unacknowledged failure = red, self or a known descendant execution not finished = green, known subtree stopped with unread = blue, otherwise no light. The current session is exempt from blue only. Red and blue are confirmed against the source session's own viewed time and then aggregated upward to ancestors; viewing a parent does not substitute for viewing a child. When the status is unreachable or unacknowledged, green/blue are not lit; gold/red are retained and the neutral small caption `状态待同步` ("Status awaiting sync") is shown. The sub-caption is always neutral, execution counts go only in the list, and the composer does not repeat the execution text. The dot column keeps 12→18pt, gold/red 8→12pt, green/blue 6→9pt; the collapsed touch area and the hierarchy are unchanged. See the full contract in the [Session single-indicator mini PRD / RFC](features/session_row_indicator/design.md).

The light column sits outside the complete VStack formed by the title and the sub-caption, vertically centered against the whole text block, with no absolute y offset. Platform optical sizes may differ (iOS default 6/8pt, Android default 5/6dp), while the semantics, block centering, and the 2.6s 0.40–1.0 breathing remain identical. The green low point may fall below 3:1, so the status text and the screen-reader output must not be omitted; Reduce Motion keeps it at 100% solid.

Normal self-execution no longer repeats "Execution active" / "Running". The branch icon with a number appears only in the session list and is kept even when yellow/red overrides green; the number is the count of known active descendants, 0 is not shown, and screen readers use a fully localized description. The composer adds no descendant count; it keeps the unified light, the retry/pending-sync/necessary voice text, and the existing background task navigation. In light mode the green is unified to `#167C45` according to the user's physical-device preference.

## QT-TYPE · Typography

Use the system SF font throughout and explicitly specify the design variant. No third-party fonts, to guarantee better CJK fallback rendering, a smaller install size, and seamless integration with the system UI.

Every size below is one of Apple's own semantic text styles (SF Pro), so Dynamic Type scales all of them. Nothing is a bespoke point size.

| Role | Apple style | Size |
|---|---|---|
| Display — session titles, empty-state hero | Title 3, semibold | 20pt |
| Headline — section headers, card titles | Headline | 17pt |
| Body — AI reply body (90% of reading time) | Callout | 16pt |
| Body prominent — user messages | Callout, medium | 16pt |
| Meta — timestamps, status labels, tool names | Footnote | 13pt |
| Micro — code, paths, tool input/output | Caption 1 | 12pt |
| Micro mono — code, file paths | Caption 1, monospaced | 12pt |

- **Body** — 16pt, not Apple's 17pt Body: a transcript is dense text, and 16pt is the size Apple's own chat-style content uses. Line height 1.45, `text.primary`.
- **Body Prominent** — User messages: SF Pro Text Medium 16pt. Distinguished from AI replies by weight difference rather than by color.
- **Meta** — Timestamps, status information, tool names, and agent/model labels: SF Pro Text Regular 13pt, `text.secondary`.
- **Micro Mono** — Code snippets, file paths, and tool input/output: SF Mono Regular 12pt, `text.tertiary`. Shown only in expanded detail areas.

The type scale is the primary carrier of visual hierarchy: converged to five clearly separated steps of 20 / 17 / 16 / 13 / 12, each one an Apple semantic text style, with no bespoke point sizes introduced.

## QT-CARD · Card Design Language

Divided into three shape families by function — this is the core of fixing the previous color chaos:

1. **Information cards** (tool input/output, patch, diff): **no stroke**, using only the `surface` fill. The information hierarchy is established through internal typography (a monospace mono font with whitespace). The expanded detail area uses 14pt padding. Multiple information cards on the same screen keep a unified, understated container quality that never upstages the content.
   - **Clickable affordance**: although tool/patch cards use a neutral `surface` fill overall, they are **interactive by nature** (tappable to view input/output or to jump to the file preview). Therefore, the key actionable elements **inside** the card — the tool icon, the tool name, the jumpable file path, and the expand chevron — are all highlighted with the `accent` terracotta, conveying a clear clickable cue; the card body itself keeps the neutral fill. Graying out the entire card would easily make users mistake it for a disabled control (this was verified during actual iteration). Focusing accent on local interaction hotspots instead of flooding the whole card provides ample affordance while avoiding a regression to the messy colorful-card style. For purely descriptive, non-interactive text (such as the tool reason description), `text.secondary` gray is still used.
2. **Action cards** (permission, question, and other components that require a user response): use a borderless design, with a 3pt `accent` stripe on the leading edge and a `surface` fill. That stripe acts as a functional signal prompting the user to act and is clearly recognizable in the iOS interface. This is also one of the few key areas on screen where accent is allowed.
3. **Status rows** (turn activity, "2:30 elapsed", etc.): **not presented in card form**. The fill and the rounded container are dropped and the row is rendered directly as a single line of `text.secondary` meta text, with optional monospace timing display.

Corner radius specs are globally unified: 12pt for information/action cards, 16pt for sheets, 6pt for inline tags — strictly specified, mixing is forbidden.

## QT-MESSAGE · Message Area

- User messages: **a right-aligned bubble**, capped at 320pt, one tucked corner (20 / 20 / 6 / 20), filled with a neutral surface tint. This is Claude's treatment: a bubble reads as "the person said this", while a full-width accent stripe read as a system event. The Body Prominent weight stays.
- AI replies: **no container wrapper at all**; plain `text.primary` body text is laid out directly on the `bg.primary` background, separated from user messages only by 20pt of vertical spacing. Streaming text renders smoothly word by word, with no extra entrance animation.
- Message spacing is set to 20pt (the original 12pt was too cramped). Treat every message as an independent unit of thought, with generous whitespace providing breathing room.

## QT-CHATSCREEN · Chat Screen (Claude interaction model + Liquid Glass)

The chat screen follows the Claude iOS app's interaction model: minimal chrome, content scrolling under floating surfaces, and nothing on screen that is not either conversation or a control for it.

- **One header band.** The session title is the navigation bar's principal item; the session entry sits in the leading group and the quota badge and the context ring in the trailing group. The toolbar used to be a *second* row under the navigation bar, which made the top of the screen read as two unrelated headers. The bar stays visible: hiding it cost the deep-link, push-navigation and fixture flows their navigation bars, and the docked file preview needs its own close button there anyway.
- **One glass composer.** A 26pt-radius glass surface docked above the tab bar. It is *not* a floating overlay: an overlay has to pad the transcript by the composer's height, and that height changes with the input, so the transcript jumped every time you typed. The safe area already reserves the floating tab bar, so the docked composer clears it.
- **Chips above the composer.** One row, not three: the model picker and the todo list are chips, the live turn state (indicator, activity text, abort menu) and the session counters fill the rest of the row and truncate. The counters stay plain text — a second glass chip next to the first one just made the row heavier. The counters keep ticking (they carry the turn stopwatch).
- **Turn state is transient.** The indicator, the activity text and the abort menu appear only while there is something to say; they are not a permanent block above the input.
- **One row per tool call.** There is no merged "N tool calls" group: every call renders the same compact row (icon, name, subject line, chevron) and expands in place. A group disclosure stacked on top of each card's own disclosure was a double disclosure.
- **User message = bubble.** Right-aligned, capped at 320pt, one tucked corner — Claude's treatment. The full-width accent stripe read as a system event rather than as something the person said.
- **One scene per surface, from one line language.** The app icon is the ink-line eye of the artwork set — it was an eight-spoke asterisk, and a pixel-art robot before that — and every empty state carries one hand-drawn scene from the same set. The empty chat greets with the clock of a session's empty history over “How can I help you?”. The map of scene to surface is `design/artwork-placement.md`.
- **Glass everywhere it is a surface.** Every floating surface goes through one `glassSurface` modifier: `glassEffect(.regular.interactive())` on iOS 26, a translucent material with a hairline edge on iOS 17–25, so the fallback never drifts from the design.

## QT-COMPOSER · Composer

- Input field: drop the stroke, use only a `bg.secondary` fill with a 16pt corner radius. Strokes often imply form fields; a free-text input area should feel borderless.
- The composer is **one card**: the input sits on top and a single bottom row inside the same surface carries the model/todo chips, the live turn state, the photo button and send. Chips and status must not float as a second band above the field — a detached band reads as a control panel and misaligns the composer against the tab bar.
- The field **hugs its content**: one line by default, growing up to about four lines as the text grows. A scrollable text view reports no intrinsic height, so the composer publishes the measured content height — otherwise the empty composer reserves four lines and the input area looks half-empty.
- The photo button shares the card's **bottom row** with send, side by side, to the left of send. Only transient actions (stop, retry) may stack above send; a permanent control in that column made the column taller than the field, so the photo button floated mid-height while send dropped below the input baseline.
- text review field: during voice transcription or retry, the partial transcript that is continuously appended or replaced must drive the text field to auto-scroll to the end, presenting the latest text output in a typewriter-like fashion; in manual editing and draft restoration scenarios it keeps the system default scrolling behavior to avoid disturbing the user's cursor.
- Send: a solid `accent` **circle** with a white icon, hugging the trailing edge of the card's bottom row and acting visually as "an organic part of the input area".
- mic: moved to the **inner left side of the input field**, presented as an in-field functional icon (`text.secondary`).
- While the AI is running: the send button is **always kept** (consistent with established product logic — new messages can still be appended directly while a task runs, with no need to manually terminate the preceding task), and it stays fixed in the **bottom slot** of the right-side vertical stack. stop is shown as an **additional** action button **above** send (same-size solid rounded square, arranged vertically in a VStack with stop on top and send below), and it hides automatically when the AI task ends. Note that stop does not replace send; the two coexist in a stacked relationship. In color terms, send uses `accent` terracotta while stop uses red (carrying interrupt/destructive-operation semantics).
- Voice input: the mic is always fixed in the **bottom slot** of the left-side vertical stack. While recording, only a red mic is shown, and tapping it ends recording normally and proceeds to transcription; during transcription the mic shows a loading state and the right side simultaneously shows `Stop transcription wait` for forcing an interrupt; after an explicit interrupt, the bottom slot on the left switches to a retry icon button while the right shows `Discard audio`. retry is the single primary recovery action and discard is the lightweight action for leaving the recovery state; the two responsibilities are distinct and must not be defined as two separate retry entry points. No transient voice state may change the fixed position of the send button.

## QT-MOTION · Motion (Highest Return on Investment)

- User message entrance: an offset y transition from 16→0 with opacity from 0→1, over an ease-out of 0.28s. AI streaming text gets no entrance animation at all.
- Tool card expansion: a custom spring (response 0.32, damping 0.82), giving a more compact and lively expansion than the system default DisclosureGroup.
- The thinking row's expansion: **no animation**; the custom-drawn header toggles directly on tap, and the row grows in place.
- Permission/Question card entrance: slides in from below (offset y from 24→0) together with a fade-in, which guides the user's visual focus more effectively than a pure fade.
- Session switching: the message list uses a 0.2s opacity crossfade transition, removing the abrupt pause caused by a hard cut.
- Explicitly out of scope: splash launch animations, bouncing spring motion, and gradient backgrounds (avoiding the visual cheapness that over-decoration brings).

## QT-HAPTIC · Haptic Feedback

Haptics are the second sensory channel. They are optional feedback — never the only
signal for something the user must act on.

- **Every haptic is a named event, and the set is closed.** The events live in
  `Utils/DesignHaptics.swift` (`DesignHapticEvent`), and each one maps to a distinct
  signature, so two different events are never felt as the same thing.
- **Alerting events survive Reduce Motion.** A failed send, an arriving permission, an
  arriving question, and a committed destructive action carry information the user
  cannot otherwise see, so they are kept. Confirming events — a sent message, a
  selection change, recording starting and recording stopping — are dropped when motion
  is reduced.
- **Nothing fires while the microphone is open.** A haptic is a mechanical event that an
  open capture can pick up. There is no blanket exception: the recording start and stop
  events pass the capture state as it is *before* their own capture opens and *after* it
  closes, so they are unaffected by their own capture and still suppressed by any other
  one.
- **Silent mode does not suppress haptics.** The ringer switch is not consulted: a
  haptic is a physical sensation rather than sound. This is a policy, not a platform
  guarantee — the feedback generators are documented as haptics, but no stronger claim
  is made here. Only Reduce Motion and the microphone guard suppress an event.
- **A request is announced once.** "Already announced" is tracked in a ledger that is
  separate from the live pending-request lists, because answering a request removes it
  from that list and the server can briefly keep listing it.
- **Haptics never replace a visual signal.** The session indicator, the composer status
  text, and the permission and question cards remain the primary channels; a haptic
  only reinforces them.

## QT-LAYOUT · Two Layout Strategies (Small Screen vs Large Screen)

While keeping brand, tokens, colors, typography, and the card design language **completely identical**, differentiated layout and whitespace strategies are defined per device form factor. This is the core completion of this design specification: avoiding the loss of operational space on iPhone caused by excessive whitespace, while making sure that on large-screen devices such as iPad and visionOS the generous whitespace releases the advantage of the bigger screen.

### Small Screen (iPhone, single column, function first)

- Single-column architecture: bottom tab navigation (Chat / Files / Settings). The Session list is triggered from a Chat top entry that pushes in (or slides down) and does not permanently occupy the screen.
- Restrained whitespace: message spacing is 20pt, card padding is 14pt, and screen horizontal margins are 16pt. Breathing room is guaranteed while the vertical display space is fully used.
- The header is **one band**: the session entry button and the session title sit in the leading group (the title is left-aligned, so it never fights the trailing controls), and the trailing group carries the model chip, the quota badge, the todo panel (only when there are todos), the context ring (18pt) and settings. Rename and new-session moved to the session sheet, where the other session-level actions live.
- Compact Composer: the input hugs its content — one line by default, growing to about four lines — and the photo button shares the bottom row with send, so neither button floats away from the field.

```
 iPhone — Chat (dark)
 ┌──────────────────────────────┐
 │ ≡  my-session           ◌  ⚙    │  ← one header band, ◌=context ring
 ├──────────────────────────────┤
 │        Refactor the auth module   │  ← user message: right-aligned bubble
 │                               │
 │ I'll start by reading the     │  ← AI reply: no container, plain body
 │ current implementation.       │
 │                               │
 │ ┌ read  src/auth/login.ts ──┐ │  ← info card: no stroke, surface fill
 │ │ 42 lines                  │ │
 │ └───────────────────────────┘ │
 │ ▎ Allow edit to login.ts?     │  ← action card: left accent stripe
 │   Allow      Deny             │
 ├──────────────────────────────┤
 │ 🎤 Message…              [ ▷ ]│  ← mic inside the field on the left, solid send on the right
 │ ├──────────────────────────────┤
 │  Chat      Files     Settings │
 └──────────────────────────────┘
```

### Large Screen (iPad / visionOS, three columns, relaxed whitespace)

The original design uses a `NavigationSplitView` three-column architecture (file tree at the top of the left sidebar, Session list below / file preview in the middle / Chat on the right). This revision **targeted-optimizes** on top of that:

- **Three-column role split**: left column = Session list (tree structure, supporting parent/child indentation, leaf dot markers, and the selected state; list rows show only title, time, and status, with **no summary preview**); middle column = the Chat interaction core (the main stage); right column = the file preview area (carrying the single-file preview triggered by tapping a tool/patch in Chat, with collapse support).
- **The file tree is collapsed by default** (an explicit product decision): on iPad the file tree no longer permanently occupies screen width, and is demoted to a default-collapsed, manually expandable "Files" disclosure at the top of the left column. The capability is still kept as a separate tab on iPhone, freeing precious horizontal space for Chat and the preview view.
- Relaxed whitespace: screen horizontal margins are 32pt, message spacing is 28pt, and card padding is 18pt. Generous whitespace creates a refined quality.
- Content width cap: the Chat body content is centered and its maximum width is limited to about 720pt, instead of filling the entire middle column — overly long text lines hurt readability, and a capped width presents a more editorial layout style.
- Right-column file preview: **plain text code rendered in a monospace font with line numbers, with no syntax highlighting** (keeping the current logic, see the future note below), and no colored tokens are drawn; Markdown provides a formatted preview, and images support gesture zoom.
- visionOS adaptation: reuse the existing large-size composer branch in `DesignControls` (48/56pt buttons for a good gaze-interaction experience), the material uses the system-level glass feel, and the color tokens stay completely identical.

```
 iPad — three columns (dark)
 ┌───────────────┬───────────────────────────┬────────────────────┐
 │ ▸ Files       │  my-session        ◌  ⚙    │  login.ts          │
 │ Sessions   +  │                             │  ──────────        │
 │ ───────────── │   ▎Refactor the auth module │  1  import…        │
 │ ▎my-session   │                             │  2  export…        │
 │  └ sub-task   │   I'll start by reading the │  3  …              │
 │ chat-2        │   current implementation.   │                    │
 │               │   ┌ read login.ts ────────┐ │  plain text        │
 │               │   │ 42 lines              │ │  no syntax hl      │
 │               │   └───────────────────────┘ │                    │
 │               │   🎤 Message…         [ ▷ ] │                    │
 └───────────────┴───────────────────────────┴────────────────────┘
   ↑ ▸Files collapsed    ↑ body max 720pt     ↑ single-file preview
   Session tree (no summary preview)
```

## QT-EMPTY · Empty States and Guidance

- Empty session list: show the dark-version logo (asset still to be added; currently only `logo_light.png` exists) with brand-character copy such as "Start a conversation with your code", avoiding the stiff "No sessions". The logo gets an extremely subtle breathing motion (scale 1.0→1.02→1.0, 3s cycle).
- Empty chat interface: a concise guidance text centered, with no icon.

## QT-NONGOAL · Non-Goals

- No gradient backgrounds: use solid base colors with deliberate whitespace and micro-motion for a more premium visual quality.
- No third-party fonts: the system-level SF Pro and SF Mono fully meet the need and deliver the best system consistency and lightness.
- No splash launch animation.
- No information architecture rework: keep the validated bottom tab and three-column layout system.
- Regular content stays on the warm neutral scale and the brand terracotta; the single-indicator triage in the Session list/composer follows the explicit exception described above.

## QT-BOUNDARY · Feature Boundaries (This Is the Implementation Draft — Three Categories Strictly Separated)

As an implementation spec meant to directly guide delivery, every visual element in this spec must strictly correspond to a real capability and is clearly divided into three boundary categories:

**Capabilities that exist today (this design only adjusts the visual presentation and does not change existing functionality)**: 3 tab navigation items (Chat/Files/Settings); the Session list sheet on iPhone; the iPad three-column layout; 10 kinds of message rendering in the Chat area (user message, AI text, tool card, patch card, permission card, question card, todo, turn activity, streaming reasoning, where step is not rendered); Markdown and zoomable image preview; file tree (supporting expand/collapse and git status coloring); composer (including mic/send/stop and the on-device voice input); toolbar interactions (session/rename/create/model-agent picker/context ring/settings); Settings options (Server/Project/SSH Tunnel/Appearance/About); the Session tree nesting hierarchy and swipe-to-delete; light/dark dual-mode theme switching.

**The regular visual baseline of this specification**: content such as cards, patches, and tools is organized with the brand terracotta and warm neutral colors; three card shapes distinguish content types; user messages keep the leading stripe. The Session triage light follows the explicit exception on this page and must not reuse the legacy golden working light.

**Explicitly excluded from this design (deferred to future planning and not reflected in the mockup)**:
- **Code syntax highlighting**: the current implementation is a monochrome plain-text rendering with line numbers (`Text(line)`) and **does not include** syntax highlighting. The mockup images are uniformly drawn as plain text. Syntax highlighting is planned as a future enhancement — given that it involves tokenizer / highlighting-parser library selection and must account for large-file performance and rendering overhead, this iteration does not implement it, and the design is not pre-packaged with it either.
- Session list item summary previews, diff sidebar comparison, message search and editing, and file upload were classified as "not shipped" in the historical audit, so none of them are in scope for this design.

## QT-LANDING · Implementation Landing Points

`OpenCodeClient/OpenCodeClient/Utils/DesignTokens.swift` already has a basic framework for Brand/Semantic/Neutral/Opacity/Typography/Spacing/Controls/Corners. The focus of this rework is **specification purification**: fully landing the hex color values and semantic mappings from the palette above, cleaning up ad-hoc system grays and redundant Semantic color definitions, strictly converging the Typography size scale to the four steps 22/16/13/12, and aligning the spacing separately against the small-screen and large-screen specifications. View layer code is strictly forbidden from continuing to use arbitrary colors such as `Color.blue/.red/.gray.opacity(…)`.

## QT-MOCKUP · Mockups

The mockups under `docs/design_images/` were generated by the GPT image generation tool (gpt-image-2) to anchor the visual baseline of the "quiet tech" feel; they are not pixel-level deliverables.

### Small Screen (iPhone, single column)

The Chat view occupies 90% of the user's interaction time. The core design concerns include: the accent leading bar on user messages, the container-free design of AI replies, information cards with no stroke and only a dark fill, action cards with a leading stripe paired with text action buttons, the mic icon built into the left of the composer, the solid blue send button hugging the bottom-right corner, and at most one blue accent color on the entire screen.

![iPhone — Chat](design_images/iphone_chat_v.png)

Session list: divided into two major groups, Active and Archived. Active is the default workspace, while Archived is a collapsed panel on the same screen with no need to navigate to a separate page. Search is explicitly labeled **Search loaded sessions**: it filters loaded titles for the current host/project, retains ancestors of matching children, and reveals matches in both groups. It does not imply a cloud-side history search; its scope explanation and Load More action remain visible while filtering.

The Active and Archived headers use a lightweight 44pt-tall control bar: Title Case naming, 13pt medium weight with a lightweight chevron icon on the right, no count labels, no decorative dividers, and no uppercase tracking, to avoid wrapping in the narrow sidebar. Each list row shows a title, a gray summary preview, and a timestamp; the selected item is marked only with a very light accent fill plus an accent leading stripe, without an extra checkmark. Selection and expansion are separate accessible buttons. Child sessions express the parent-child hierarchy through indentation. Entries in Archived remain tappable, but their titles and times use a lighter gray and no blue indicator bar.

Delete sits at the trailing edge and is red; Archive and Restore sit at the leading edge in a restrained blue-gray tone. Full-swipe quick triggers stay disabled. **Irreversible server deletion requires a confirmation naming the session and explaining that it cannot be undone.** This HIG remediation supersedes the earlier no-confirmation rule; there is no server-side trash/undo capability to promise.

![iPhone — Sessions](design_images/iphone_sessions.png)

Settings: uses a standard grouped list, where the Theme segmented selector is one of the few areas allowed to use accent emphasis, while everything else stays on a neutral gray scale.

![iPhone — Settings](design_images/iphone_settings.png)

Host Profiles (management of multiple OpenCode environments) follow native Form and sheet interaction specs and do not build a custom card system. The core of this design is not visual distinctiveness but minimizing the cognitive burden of network connection configuration as much as possible: the user selects a concrete OpenCode host, while the underlying transport is only an access channel.

![iPhone — Host Profiles](design_images/host_profiles_list_v1.png)

Add Host provides a two-stage entry: the `Import Host Config` quick import takes priority at the top, with the full manual configuration form below. Direct and SSH Tunnel modes are switched through a segmented control. In SSH mode, users cannot directly edit `127.0.0.1:4096`; it is shown only as a `Managed by SSH tunnel` hint. The core parameters distributed by the administrator are consolidated into the `SSH Gateway` group; the device public key is presented as an independent group and must provide a clickable `Copy This Device Public Key` action, rather than merely being placed in static explanatory text.

![iPhone — Add SSH Host](design_images/host_profiles_add_v2.png)

Design review conclusion: the first prototype presented "copy public key" only as explanatory text with no interactive action, which broke the SSH onboarding flow; in addition, the `SSH Username` label was missing from the `opencode` configuration row. The revision moves Import to the top level, clearly labels the source channel of each SSH parameter, and changes the local OpenCode URL from an editable input field to a system-managed field. The follow-up implementation must accommodate the Dynamic Type feature: ensure `LabeledContent` supports value wrapping or vertical stacking under large accessibility text sizes, avoiding the `Assigned Remote Port` label and its value squeezing and occluding each other.

The follow-up design review of Host Profiles shifts its focus from onboarding to long-term operations: an imported profile must support convenient inspection, correction, and connectivity diagnosis. The verification material produced by the screenshot automation harness is stored in `/tmp/opencode-host-profiles-screenshots/`, fully covering Settings Current Host, the Hosts list, Host Detail, Import prefill, and the post-SSH-import form state. The UI spec established after the review is: both Settings and Host Detail must provide an executable diagnostic function; tapping a Hosts list item should enter the detail page rather than directly triggering a switch; `Never connected` is shown uniformly when there is no valid connection history; and SSH Host Detail must fully present Gateway Host, SSH Port, SSH Username, Assigned Remote Port, the local URL, `Use This Host`, `Copy Host Config JSON`, and `Copy This Device Public Key`.

This round of screenshot testing also surfaced two design details. First, an unprocessed raw Swift error must never be exposed directly in the UI; for example, a Basic Auth failure should present text with clear troubleshooting guidance such as `OpenCode rejected Basic Auth. Check username and password.`. Second, on narrow-screen devices the summary text of SSH list items risks truncation, so the list summary is only used for basic identification and for jumping to details, and all complete configuration fields remain authoritative on the Host Detail page.

Key technical decisions: a Host entity represents a single OpenCode runtime environment rather than a standalone SSH host; transport is explicitly divided into `direct` and `sshTunnel` types, with Tailscale, VPN, LAN, and HTTPS all belonging to direct; the top of Settings shifts from a global connection form to the Current Host status; the Add Host flow prioritizes an Import Config quick import that excludes sensitive credentials, while retaining the manual configuration entry; SSH private keys are generated and managed per device (device-level) by default, with multiple SSH hosts on the same device sharing one public key; Basic Auth passwords are stored per profile in the Keychain, with only a reference marker kept in the profile configuration; TOFU trusted hosts are bound to the SSH gateway's `host:port`; `127.0.0.1:4096` in SSH mode is an app-managed runtime URL that the UI does not let the user edit; switching hosts must simultaneously stop the SSE listener, tear down the original SSH tunnel, load the new profile, clear the currently selected session, and re-fetch the health, projects, and sessions data; the first implementation uses the profile as the persisted source of truth, then destructures it back into the existing `serverURL`, Basic Auth, and `SSHTunnelManager.config` runtime fields, avoiding a disruptive one-shot rewrite of the APIClient, SSE, and SSH tunnel architecture.

### Large Screen (iPad / visionOS, three columns)

Sharing the same token set and brand spec, the large-screen layout is more relaxed: the Session list on the left, the main Chat interaction area in the middle (body width capped and centered, presenting an editorial layout with whitespace), and the file/code preview area on the right. Syntax highlighting in the code preview is converged to a restrained neutral gray scale to avoid color chaos. The Files module in the iPad sidebar stays collapsed by default; the Session area directly shows its own separate Active and Archived sections, with no search field preset. The swipe gesture directions for Archive, Restore, and Delete are exactly the same as on iPhone.

![iPad — three columns](design_images/ipad_threecol.png)

## QT-RETRO · Diagnostic Retrospective (From the Previous Version — the Conclusions Still Hold)

The early UI exhibited typical engineer thinking: flat information hierarchy (font size and spacing lacked a differentiated gradient), insufficient whitespace (12pt message spacing and 8pt card padding were too cramped), weak brand recognition (over-reliance on the system-native SF Symbols and the system default colors, giving a visual quality closer to a basic demo project), and missing micro-interactions (lacking the necessary transition animations). Every principle established in this specification precisely addresses and solves the pain points above.

---

# Tool Card Rendering Rework (Implemented; Latest Evolution: One Row Per Tool Call, File Cards Keep the Grid)

**Pixel style is explicitly out of scope.** This chapter's design is entirely grounded in the Quiet Tech design language described above and introduces no extra visual texture — it strictly maintains the existing minimal modern icons, hairline dividers, and neutral card fills. This refactor focuses on optimizing the **information organization structure** rather than swapping the visual skin: the main goals are to separate the speaking roles and to present tool call results efficiently.

The current pain points concentrate on two aspects: (a) AI replies and user messages have insufficient visual difference, making it hard to quickly identify the speaker; (b) all tool calls uniformly use a "generic expandable DisclosureGroup + wrench icon", while patch is separately handled as a full accent navigation card — the tool cards lack semantic differentiation from each other, and the overall visual presents a large amount of homogeneous gray cards.

This design contains three concrete adjustments: (1) clearly distinguish the speaking roles of the user and of OpenCode; (2) uniformly render file-type operations as file cards (using a 2-column grid layout); (3) converge all remaining generic tool calls into an expandable "N tool calls".

## QT-SPEAKER · One, Distinguishing Who Is Speaking (No Avatar, but a Title)

The visual distinction between AI replies and user messages is currently too weak to locate the speaker quickly. The optimized design spec is as follows:

- **User messages**: continue to use the **right-aligned bubble** — capped at 320pt, one tucked corner (20 / 20 / 6 / 20), filled with a neutral surface tint. (This supersedes the earlier 3pt accent leading stripe; see §QT-MESSAGE.)
- **OpenCode replies**: **use no avatar and no round icon**, and instead add a **"OpenCode" text title** at the top of the reply (using a micro-differentiated style that clearly marks the AI speaking identity); at the same time, **fully retain the existing "model info caption"** — that is, the secondary gray text that notes the model information at the bottom of each reply (such as `claude-opus-4 · 12:04`), with its position and existing logic unchanged. The reply body area has no background container and no leading stripe.

The core idea of the design is to clearly delineate the two roles through a **differentiated visual style** (top text title + bottom model caption versus the right-aligned bubble), rather than relying on a conventional user avatar.

## QT-FILECARD · Two, File Cards (2-Column Grid)

**File-operation tools (covering the four types patch / edit / write / read)** are uniformly rendered as **file cards**: a clean, modern **file icon** on the left of the card, the filename or path in monospace in the middle, and a chevron icon on the right that triggers navigation or expansion. Each tool call corresponds to one card, **arranged in a 2-column grid** (two cards side by side per row, aligned with the iPhone's existing 2-column grid spec; it can extend to 3 columns on iPad). The logical decision rule is `part.tool ∈ {apply_patch, edit_file, write_file, read_file}` (including historical compatibility aliases).

## QT-TOOLTILE · Three, One Row Per Tool Call

**All remaining tools besides file operations (including bash / test / grep / glob / list / webfetch / task, etc.) each render as their own row**: icon, tool name, the call's subject line (the command or the reason), the status, and a chevron. The row is collapsed by default and expands in place to show the input and the output.

The merged "N tool calls" group is gone. A group disclosure stacked on top of each card's own disclosure was a double disclosure, and the group header hid which tool was actually running.

Each row's header is a single line: the tool name keeps its natural width and the subject line is truncated, so neither can wrap mid-word. The status is a trailing pill and is dropped when the row already carries a subject line, so the row never repeats itself.

The row is a **compact tag that hugs its content**, not a full-width slab: six tool calls stacked as full-width cards turned the transcript into a wall of grey rectangles. The expanded detail drops below the tag, indented, with no container of its own — the mono type carries the hierarchy.

## QT-TILEGRID · Arrangement: File Cards Keep the Grid, Everything Else Is Full Width

file cards **enter a two-column (iPhone) / three-column (iPad) grid**, with the tiles laid out in the original part order: file operations each produce a half-width file card tile, and every other tool call produces a full-width row of its own. The thinking card **takes a full-width row** — its content is prose, not thumbnails. A file card row that has fewer tiles than columns keeps its grid positions (the empty cell stays empty), so a lone file card still occupies half the width.

text and attachment blocks do not enter the grid and are **rendered full width after the grid** (reading order: the grid first, the full-width text after; users accept this). There is no extra grouping overall, and no category headings like "Files updated" or "Actions" are added.

File cards follow the Warm Editorial neutral card spec (neutral `surface` fill, no border stroke, 12pt corner radius); the thinking / tool rows keep the lightweight process row form (no heavy card surface), with color accents restricted to the file icon, the header, and the chevron area — ensuring at most one accent emphasis remains on screen.

![Tool cards: speaker differentiation + 2-column file cards + N tool calls](design_images/tool_cards_chronological.png)

> This mockup clarifies the final evolution direction: user messages use a right-aligned bubble; OpenCode replies carry an "OpenCode" text title and a bottom model caption (`claude-opus-4 · 12:04`), with no avatar; file operations aggregate into a 2-column file card grid (`client.ts` / `types.ts` / `README.md` / `utils.ts`, etc.); the remaining tool calls converge into `▸ 3 tool calls`. A purely crisp sans-serif font is used throughout, with no pixel-art texture.

## QT-TOOLBOUND · Non-Goals / Boundaries

- **Never introduce a pixel style**: the core value lies in the **information organization structure** built by "role differentiation / file cards / N tool calls", not in a pixel visual texture. The overall design strictly maintains the minimal, restrained Quiet Tech spec.
- **No extra grouping and no added category headings.**
- **File cards keep the file icon and the 2-column grid**; AI replies **use no avatar** but **must show the "OpenCode" text title**; **the bottom model caption stays as-is with no changes**.
- **The model picker keeps its existing interaction, and no user avatar is added in the top-right corner.**
- **Session execution not finished** uses a dedicated light green breathing effect, with no pixelation, scaling, or glow; gold, red, and blue stay solid.
- **This chapter is an exploratory design spec**; the underlying code refactor involving `ToolPartView`, `PatchPartView`, and `MessageRowView` is handed over to a follow-up implementation PR.
