# Linear Backlog — Superpolished App Experience

> **Purpose:** a creation manifest. Each block below becomes one Linear issue in the
> project `opencode-app-for-ios` (workspace `prysmsh`). Derived from
> [`plan.md`](plan.md), which carries the reasoning, the measured evidence, and the
> exit criteria for each phase.
>
> **Status:** **CREATED — all 36 issues live in Linear** (project `OpenCode App for
> Ios`, team `PRY`, identifiers `PRY-5` … `PRY-40`). The OAuth MCP path was abandoned
> in favour of a personal API key against `api.linear.app/graphql`, because Linear's
> consent screen requires an interactive login that could not be automated.
>
> **After creation:** this file is the record of what was created and can be deleted
> once Linear is the source of truth.

## Created issues

| Plan issue | Linear | Title | State | Pri |
|---|---|---|---|---|
| P0-1 | PRY-5 | Number the Quiet Tech spec clauses | Todo | High |
| P0-2 | PRY-6 | Write the polish rubric | Todo | High |
| P0-3 | PRY-7 | Produce the measured audit table | Todo | High |
| P0-4 | PRY-8 | Rank the polish backlog | Todo | Medium |
| P0-5 | PRY-9 | Write per-screen acceptance criteria | Todo | Medium |
| P1-1 | PRY-10 | Build the polish lint engine | Backlog | High |
| P1-2 | PRY-11 | Seed the ratcheting baseline and its negative self-test | Backlog | High |
| P1-3 | PRY-12 | Wire the lint into the unit-test runner | Backlog | Medium |
| P1-4 | PRY-13 | Assert the token values in XCTest | Backlog | Medium |
| P2-1 | PRY-14 | Scope the Semantic colour namespace and add the missing Opacity tokens | Backlog | Medium |
| P2-2 | PRY-15 | Migrate the raw colour literals to tokens | Backlog | Medium |
| P2-3 | PRY-16 | Migrate ad-hoc opacities to DesignColors.Opacity | Backlog | Medium |
| P2-4 | PRY-17 | Migrate hardcoded spacings to DesignSpacing | Backlog | Medium |
| P2-5 | PRY-18 | Extract the accessibility-probe hack | Backlog | Medium |
| P3-1 | PRY-19 | Extend DesignTypography with the missing roles | Backlog | Medium |
| P3-2 | PRY-20 | Migrate the 101 raw system-font call sites | Backlog | Medium |
| P3-3 | PRY-21 | Prove the migration is pixel-neutral | Backlog | Medium |
| P3-4 | PRY-22 | Dynamic Type device spike at accessibility3 (entry condition) | Backlog | High |
| P3-5 | PRY-23 | Implement the 22/16/13/12 scale in a single commit | Backlog | High |
| P4-1 | PRY-24 | Define the motion presets and the motion budget | Backlog | Medium |
| P4-2 | PRY-25 | Implement the motion the spec requires but the code lacks | Backlog | Medium |
| P4-3 | PRY-26 | Define the haptic matrix | In Review | Medium |
| P4-4 | PRY-27 | Implement the haptic matrix | In Review | High |
| P5-1 | PRY-28 | Chat slice: geometry conformance | Backlog | Medium |
| P5-2 | PRY-29 | Chat slice: error surface conformance | Backlog | Medium |
| P5-3 | PRY-30 | Chat slice: user-message entrance transition | Backlog | Medium |
| P5-4 | PRY-31 | Chat slice: custom tool-card disclosure | Backlog | Medium |
| P5-5 | PRY-32 | Chat slice: 44 pt hit targets on permission and question actions | Backlog | Medium |
| P6-1 | PRY-33 | Add SwiftUI previews for every screen view | Backlog | Medium |
| P7-1 | PRY-34 | Rollout: Settings | Backlog | Low |
| P7-2 | PRY-35 | Rollout: Session list | Backlog | Low |
| P7-3 | PRY-36 | Rollout: Host profiles | Backlog | Low |
| P7-4 | PRY-37 | Rollout: Files and preview surfaces | Backlog | Low |
| P7-5 | PRY-38 | Rollout: Composer and voice rail (last) | Backlog | Low |
| P7-6 | PRY-39 | Rollout: Car and Ambient surfaces | Backlog | Low |
| P8-1 | PRY-40 | Close out the initiative and update the docs | Backlog | Low |
| — | PRY-41 | Rebase #215/#216 for the haptics capture-state hunk | Backlog | High |
| — | PRY-42 | UI: the question-recovery fixture's questions are wiped by the pending-questions poll | Backlog | High |
| — | PRY-43 | UI: the preview-migration layout toggle does not reach the three-column workspace layout | Backlog | High |

The planned 36 carry the `Improvement` label. PRY-41 also carries it (a rebase
consequence of the same change); PRY-42 and PRY-43 carry `Bug` — they are defects the UI
suite caught, not polish work. Phase 0 sits in **Todo** (it is the only
immediately actionable work — everything else is blocked on it); Phases 1–8 sit in
**Backlog**.

## Implementation status

| Issue | State | Outcome |
|---|---|---|
| PRY-5 … PRY-9 (Phase 0) | **Done** | The rubric (102 rows), the measured audit (1:1), the ranked backlog, the per-surface acceptance list, and the `QT-*` clause IDs in `docs/design.md`. Zero `.swift` changed. |
| PRY-26, PRY-27 (haptics) | **In Review** | Implemented 2026-10-25. `Utils/DesignHaptics.swift` + 11 firing sites covering all 8 events + 13 tests. `docs/design.md` §QT-HAPTIC added. **The review gate has run four rounds** — round 1 FAIL from both reviewers, round 2 FAIL from the code review and PASS WITH NITS from the privacy review, round 3 FAIL on documentation-contract findings only, round 4 FAIL because the merge had invalidated the audit's evidence (the haptic code itself was confirmed clean). Every finding from every round was addressed, including a **BLOCKER** (the file did not compile for visionOS), two **MAJORs** (the microphone guard was bypassed at 6 of 10 call sites, and a capture-flag leak that silently disabled every haptic), and a second **MAJOR** the round-1 fix had introduced (an unscoped capture-pending flag). A final confirmation round is outstanding; no on-device check is possible for haptics. |
| PRY-41 (rebase follow-up) | **Backlog** | Opened because the haptic change edits `ChatTabView+VoiceInput.swift`, which PRs #215/#216 own. They need a rebase with hand-merged hunks. |
| PRY-42, PRY-43 (UI-suite defects) | **Backlog** | Opened while verifying the haptic work: two **pre-existing** UI-test failures that the change did **not** cause — confirmed by a clean-tree run. PRY-42 — the question-recovery fixture's injected questions are wiped by the pending-questions poll, because `refreshPendingQuestions()` replaces the list wholesale and the fixture's mock returns `[]`. PRY-43 — the preview-migration layout toggle does not reach the three-column workspace layout (`ContentView.swift:164`). |
| PRY-44 (visionOS build) | **Backlog** | Opened while verifying the haptic work: the merged tree's visionOS target does not compile, because `Utils/GlassSurface.swift` (from `7a8847d chore: v2`) uses SwiftUI's `Glass` behind `if #available(iOS 26.0, *)` — true on visionOS 26, but `Glass` is `API_UNAVAILABLE(visionos)`. Not caused by the haptic work; the **iOS** build succeeds. |
| — | **Baseline evidence** | The pre-haptic tree at `08402c6` fails **both** tests at the **same lines** (`PreviewMigrationUITests.swift:56`, `QuestionWebPreviewRecoveryUITests.swift:20`) on the same iOS 18.4 runtime, so neither failure is attributable to the haptic work. `CarModeUITests.testExperimentalCarModeToggleControlsTab` failed in the full suite but passed in isolation — flaky, not a regression. |

The full review-round table is in [`plan.md`](plan.md) → "The review gate — three rounds".

## Conventions

- Titles are prefixed with the phase, e.g. `P0-1 · Number the Quiet Tech spec clauses`.
- Every issue carries the phase number, the plan phase it belongs to, its dependencies
  by issue title, and a verifiable acceptance block.
- Issues are ordered so that the dependency graph is acyclic and every issue is
  independently landable.

## Dependency graph

```
P0-1 clause IDs ─┬─> P0-2 rubric ─┬─> P0-3 audit
                  │                ├─> P0-4 rank backlog
                  │                └─> P0-5 per-screen acceptance
                  └─> P0-4
P0-3 audit ──> P1-2 baseline
P0-2 rubric ──> P1-1 lint engine ──> P1-3 runner wiring ──> P1-4 token tests
P1-1 ──> P2-* (all) ──> P3-1 ──> P3-2 ──> P3-4 ──> P3-5
P1-1 ──> P4-1 motion ──> P4-2 motion impl
P1-1 ──> P4-3 haptics matrix ──> P4-4 haptics impl
P2-* + P3-2 + P4-2 + P4-4 ──> P5-1..P5-5
P1-3 ──> P6-1 previews
P5-5 ──> P7-1..P7-6 ──> P8-1 closure
```

---

## Phase 0 — Definition of done (documentation only, no `.swift` changes)

### P0-1 · Number the Quiet Tech spec clauses

**Plan phase:** 0, Step 1
**Depends on:** —
**Description:**
`docs/design.md` currently has 19 `##` sections with no stable identifiers. The
rubric, the lint rules, and the audit rows all need to point at one authority, and
"the spec says X" is not referenceable without an ID. Add a stable clause ID to each
`##` section — for example `QT-TYPE-1`, `QT-MOTION-3`, `QT-CARD-2` — plus a short
pointer section that links to `docs/features/polish/rubric.md`.
**No prose changes.** This issue adds identifiers only; rewriting the spec's wording
is out of scope.
**Acceptance:**
```bash
grep -c "^## QT-" docs/design.md          # → ≥ 19
grep -n "features/polish/rubric.md" docs/design.md   # pointer section present
git diff --name-only | grep -c "\.swift$"   # → 0
```

### P0-2 · Write the polish rubric

**Plan phase:** 0, Step 3
**Depends on:** P0-1
**Description:**
Create `docs/features/polish/rubric.md`: the checkable definition of "polished". One
row per condition, each with a stable ID, the `docs/design.md` clause it enforces, the
screen(s) it applies to, the predicate, and the enforcement mechanism (lint rule /
XCTest / screenshot review / human).
Suggested ID families: `POL-TYPE-*`, `POL-COLOR-*`, `POL-MOTION-*`, `POL-HAPTIC-*`,
`POL-STATE-*`, `POL-A11Y-*`, `POL-PREVIEW-*`, `POL-ERROR-*`.
Include both a *conformance* family (does it match the spec) and a *felt-quality*
family (motion rhythm, empty-state tone, error-message tone) — a rubric that only
measures spec conformance may measure nothing a user perceives.
**Acceptance:**
```bash
test -f docs/features/polish/rubric.md
grep -c "^| POL-" docs/features/polish/rubric.md   # → ≥ 40
grep -c "POL-" docs/features/polish/rubric.md        # every row cites a QT- clause or is marked ios-only
```

### P0-3 · Produce the measured audit table

**Plan phase:** 0, Step 4
**Depends on:** P0-1, P0-2
**Description:**
Create `docs/features/polish/audit.md`: for every rubric ID, the current pass/fail
state with `file:line` evidence, measured with the grep commands in `plan.md`.
**This is a snapshot, not a gate** — it is labeled non-gating on purpose, because a
static table cannot prevent regressions. It exists so Phase 2–7 know their starting
point and so later phases can show the delta.
**Acceptance:**
```bash
test -f docs/features/polish/audit.md
grep -c "^| POL-" docs/features/polish/audit.md   # → ≥ 40, one per rubric ID
grep -c "file:line\|:[0-9]" docs/features/polish/audit.md   # evidence present
```

### P0-4 · Rank the polish backlog

**Plan phase:** 0, Step 5
**Depends on:** P0-1, P0-3
**Description:**
Rank every remaining backlog item by *user-visible impact ÷ review cost* and record
the ranking in `docs/features/polish/plan.md`. This ranking drives Phase 5–7
sequencing. The felt-quality items need real budget — they are easy to outrank
mechanically, and they are the ones a user actually feels.
**Acceptance:**
```bash
grep -n "Backlog ranking" docs/features/polish/plan.md   # section present
grep -c "^| " docs/features/polish/plan.md                # ranked table present
```

### P0-5 · Write per-screen acceptance criteria

**Plan phase:** 0, Step 6
**Depends on:** P0-2
**Description:**
Write the per-surface acceptance list that later phases check off: chat message
stream, composer, session list, settings, host profiles, files, car/ambient,
preview/web, watch. Each surface's list must include Dynamic Type at `accessibility3`,
`zh-Hans` localization, and long-locale layout — the scale and spacing changes can
overflow where a fixed width is used (e.g. `SessionListView.swift:29`, `width: 88`).
**Acceptance:**
```bash
grep -q "Chat message stream" docs/features/polish/rubric.md
grep -q "accessibility3" docs/features/polish/rubric.md
grep -q "zh-Hans" docs/features/polish/rubric.md
```

---

## Phase 1 — Executable enforcement harness (no pixels change)

### P1-1 · Build the polish lint engine

**Plan phase:** 1, Step 1
**Depends on:** P0-2
**Description:**
Create `scripts/polish_lint.sh` — a bash 3.2 source scanner matching the conventions
of `scripts/lib_simulator.sh` and `scripts/lib_test_observability.sh` (BSD grep
compatible, not GNU-only flags). Rules are selected by flag
(`--rules=type,color,spacing,opacity,motion,haptics,preview`). Exit 0 when clean, 1 on
violation. Output is `file:line: rule: message`, and **every message cites the rubric
ID it enforces** so a failure is traceable to `docs/features/polish/rubric.md`.
This must be a script and not an XCTest: the test bundle runs inside the simulator
sandbox and cannot read the repository source tree.
**Acceptance:**
```bash
./scripts/polish_lint.sh                # exit 0 on the current tree
./scripts/polish_lint.sh --rules=type   # exit 0
./scripts/polish_lint.sh --help         # documents every rule and its rubric ID
```

### P1-2 · Seed the ratcheting baseline and its negative self-test

**Plan phase:** 1, Steps 2–3
**Depends on:** P0-3, P1-1
**Description:**
Create `scripts/polish_lint_baseline.txt` seeded from the Phase 0 audit — every
current violation, one per line, with its `file:line`. The lint is green on day 1 but
**blocks any new violation**; the baseline only ever shrinks. Add the negative test:
the lint must *fail* on a deliberately offending fixture (a temp copy of a View with a
raw color and an out-of-scale font).
This ratchet is what stops the lint becoming ritual — a lint that fires on the team's
own work gets disabled or allowlisted into meaninglessness.
**Acceptance:**
```bash
./scripts/polish_lint.sh                              # exit 0
./scripts/polish_lint.sh --rules=type --self-test     # non-zero exit on a seeded violation
wc -l scripts/polish_lint_baseline.txt                # line count is a tracked, decreasing metric
```

### P1-3 · Wire the lint into the unit-test runner

**Plan phase:** 1, Step 4
**Depends on:** P1-1
**Description:**
Insert a `lint` phase into `scripts/test_unit.sh` **before** the build phase, using
the existing `oc_phase` helper in `scripts/lib_test_observability.sh` — no new
infrastructure. The lint must fail fast and be recorded in the run's `events.tsv` /
`state.tsv` under the existing observability contract (exit codes 0/65/73/74 keep
their meanings). Document the phase and its exit code in `docs/tests.md`.
**Acceptance:**
```bash
./scripts/test_unit.sh
grep -c "lint" .occlient/test-runs/unit-*/events.tsv   # lint phase recorded
grep -n "lint" docs/tests.md                            # documented
```

### P1-4 · Assert the token values in XCTest

**Plan phase:** 1, Steps 5–6
**Depends on:** P0-2, P1-1
**Description:**
Add `OpenCodeClientTests/DesignTokenTests.swift` asserting the token layer directly:
`Brand.primary == #3B82F6`, `Brand.gold == #D9A621`, `DesignCorners == {small 6,
medium 12, large 16}`, `DesignSpacing.cardPadding` per the governing clause, and —
under Branch A1 — the four type sizes are exactly {22, 16, 13, 12}. Also assert the
motion budget: no preset may exceed the spec's 0.35s response / 300ms duration
ceiling. Use the repo's `import Testing` convention.
This is the half that *is* reachable in-process — where regressions are most likely
and most damaging.
**Acceptance:**
```bash
./scripts/test_unit.sh
grep -n "22\|16\|13\|12" OpenCodeClient/OpenCodeClientTests/DesignTokenTests.swift
```

---

## Phase 2 — Seam cleanup (pixel-neutral by construction)

### P2-1 · Scope the Semantic color namespace and add the missing Opacity tokens

**Plan phase:** 2, Step 1
**Depends on:** P1-1
**Description:**
In `Utils/DesignTokens.swift`: scope `Semantic` so `error` is destructive-only, and
retire `success` / `warning` / `info` per `docs/design.md:210` ("cleaning up ...
redundant Semantic color definitions"). Add the missing `Opacity` entries needed to
absorb the 39 ad-hoc `.opacity(` call sites.
**Every rendering value must stay identical** — this phase is a pure refactor, and the
diff must be provably pixel-neutral.
**Acceptance:**
```bash
grep -rn "Semantic.info\|Semantic.success\|Semantic.warning" OpenCodeClient/OpenCodeClient --include="*.swift" | wc -l   # → 0
./scripts/test_unit.sh
```

### P2-2 · Migrate the raw color literals to tokens

**Plan phase:** 2, Step 2
**Depends on:** P2-1
**Description:**
Migrate the 7 raw color literals, in this order: `QuestionCardView.swift:21,125,235`
(`Semantic.info` is a *second* blue, different from `Brand.primary` —
`design.md:12` "single brand color"), `MessageRowView.swift:648,651` (the red error
block `design.md:63` explicitly forbids — becomes accent + explicit text),
`ChatTabView.swift:834,839` (recording mic red — sanctioned exception, allowlist it
explicitly), `HostProfilesView.swift:305`, `CarLiveView.swift:442,734`,
`ModelShortlistView.swift:252`, `QRScannerView.swift:27` (camera backdrop black —
allowlist as full-bleed).
**Do not touch `HostProfilesView.swift` in this issue** — it overlaps the in-flight
host-profile diff (`Models/HostProfile.swift`, `Support/L10n.swift`). Defer it to P7-3.
**Acceptance:**
```bash
grep -rEn "Color\.(red|blue|green|orange|purple|pink|yellow)" OpenCodeClient/OpenCodeClient/Views --include="*.swift" | wc -l   # → 0 (excluding allowlisted)
grep -rn "Semantic.info" OpenCodeClient/OpenCodeClient --include="*.swift" | wc -l   # → 0
./scripts/polish_lint.sh --rules=color   # exit 0
```

### P2-3 · Migrate ad-hoc opacities to DesignColors.Opacity

**Plan phase:** 2, Step 3
**Depends on:** P2-1
**Description:**
Migrate the 39 ad-hoc `.opacity(` call sites in Views to `DesignColors.Opacity`.
The spec forbids ad-hoc opacity in favor of the token set.
**Acceptance:**
```bash
grep -rEn "\.opacity\(" OpenCodeClient/OpenCodeClient/Views --include="*.swift" | grep -v "DesignColors.Opacity" | wc -l   # → 0
./scripts/polish_lint.sh --rules=opacity   # exit 0
```

### P2-4 · Migrate hardcoded spacings to DesignSpacing

**Plan phase:** 2, Step 4
**Depends on:** P2-1
**Description:**
Migrate the 66 hardcoded numeric spacing values in Views to `DesignSpacing.*`.
**Acceptance:**
```bash
grep -rEn "\.(padding|spacing)\([^)]*[0-9]" OpenCodeClient/OpenCodeClient/Views --include="*.swift" | grep -v DesignSpacing | wc -l   # → 0
./scripts/polish_lint.sh --rules=spacing   # exit 0
```

### P2-5 · Extract the accessibility-probe hack

**Plan phase:** 2, Step 5
**Depends on:** P1-1
**Description:**
Create `Utils/AccessibilityProbe.swift` and migrate the 5 `.font(.system(size: 1))`
probe hacks to it: `MessageRowView.swift:664`, `ChatTabView.swift:964`,
`ContentView.swift:232,305`, `FileContentReuseFixture.swift:110`,
`FileSearchFixture.swift:239,245`. One named, documented helper instead of five
inline magic numbers. This also removes 5 out-of-scale `.system(size:)` literals from
the type count in P3-2.
**Acceptance:**
```bash
grep -rn "font(.system(size: 1)" OpenCodeClient/OpenCodeClient --include="*.swift" | wc -l   # → 0
test -f OpenCodeClient/OpenCodeClient/Utils/AccessibilityProbe.swift
./scripts/test_unit.sh
```

---

## Phase 3 — Type-scale migration

### P3-1 · Extend DesignTypography with the missing roles

**Plan phase:** 3, Step 1
**Depends on:** P2-1, P2-4
**Description:**
Extend `DesignTypography` with the roles the spec's four steps imply — `display`,
`body`, `bodyProminent`, `meta`, `micro`, `microMono` — plus a `probe` role for the
accessibility probe from P2-5.
**Keep every value byte-identical to today's rendering.** The token *definitions* are
non-conformant (`:121` display=20pt, `:127` body=17pt, `:133` meta=12pt, `:136`
micro=11pt, plus a fifth step at `:124`) but that is fixed in P3-4, in one commit.
**Acceptance:**
```bash
git diff OpenCodeClient/OpenCodeClient/Utils/DesignTokens.swift | grep -E "^[-+].*static let" | wc -l   # → 0 value changes
./scripts/test_unit.sh
```

### P3-2 · Migrate the 101 raw system-font call sites

**Plan phase:** 3, Step 2
**Depends on:** P1-1, P3-1
**Description:**
Sweep all 101 raw system-font call sites to `DesignTypography.*`. Covers
`Views/Chat/*` (`MessageRowView.swift:553,752`,
`ChatToolbarView.swift:102,118,157,258,263,317,344`,
`QuestionCardView.swift:81,84,90,119,157,168,179,226,228`,
`PermissionCardView.swift:46,56,67`, `AIUsageQuotaView.swift:71,155,179`),
`SessionListView.swift:35,48`, `ChatTabView.swift:1771,1794`,
`CarLiveView.swift:722`, `SettingsTabView.swift:243`,
`ClientCapabilityPermissionView.swift:15`, `FileContentView.swift`,
`FileTreeView.swift`, `ModelShortlistView.swift`, `HostProfilesView.swift:309,338,994`,
`MarkdownWebPreviewView.swift`.
Land the chat/files surfaces first; defer the session-list and host-profile call sites
to P7-2 / P7-3 to avoid colliding with the in-flight host-profile diff.
**Zero visual delta is the point — prove it, do not assert it.**
**Acceptance:**
```bash
grep -rEn "\.font\(\.(caption2?|body|subheadline|callout|footnote|headline|title2?|largeTitle)" OpenCodeClient/OpenCodeClient/Views --include="*.swift" | wc -l   # → 0
./scripts/test_unit.sh
```

### P3-3 · Prove the migration is pixel-neutral

**Plan phase:** 3, Step 3
**Depends on:** P3-2
**Description:**
Freeze and take the screenshot evidence: generate the fixture screenshots before and
after P3-2 and compare hashes. The claim "zero visual delta" must be backed by
evidence, not by assertion.
Note that screenshots may never be committed (`docs/tests.md:216,224`) — the baselines
live in the gitignored `.occlient/` tree, and the *rubric* records the expected
rendering textually.
**Acceptance:**
```bash
shasum tmp/visual_qa/*.png > /tmp/after.sha
diff /tmp/before.sha /tmp/after.sha    # → no differences
```

### P3-4 · Dynamic Type device spike at accessibility3 (entry condition)

**Plan phase:** 3b entry condition (risk H2)
**Depends on:** P1-4
**Description:**
**This is an entry condition for P3-5, not a follow-up.** Under decision D1, the
22/16/13/12 scale is implemented with `Font.custom(..., size:, relativeTo:)`. That
approach must be validated on a physical device before it is adopted:
implement a spike of the four sizes via `Font.custom`, set Dynamic Type to
`accessibility3`, and confirm (a) the nominal size is exact at the default text size,
(b) the type still scales, and (c) CJK fallback quality is preserved
(`design.md:76` requires CJK fallback quality, and the project ships en/zh-Hans).
A literal `.system(size:)` implementation would freeze Dynamic Type scaling in an app
that makes 274 accessibility API calls — that is the accessibility regression this
spike exists to prevent.
**Acceptance:**
```bash
grep -n "Dynamic Type spike" docs/features/polish/plan.md   # recorded in the decision log
grep -n "accessibility3" docs/features/polish/audit.md       # spike result recorded with file:line evidence
```

### P3-5 · Implement the 22/16/13/12 scale in a single commit

**Plan phase:** 3, Step 4
**Depends on:** P1-4, P3-3, P3-4
**Description:**
In **one commit**, set the token values to 22/16/13/12 using the D1 formulation
(`Font.custom(..., size:, relativeTo:)`). This commit is *the* app-wide visual diff and
gets its own screenshot review.
A zero-visual-diff foundation pass was the original goal, but it is impossible with
non-conformant tokens — this single isolated diff is how the "later diffs stay
reviewable" requirement is met instead.
Update `DesignTokenTests.swift` to assert the final scale, and record the before/after
delta in `docs/features/polish/audit.md`.
**Acceptance:**
```bash
./scripts/test_unit.sh    # green; DesignTokenTests asserts 22/16/13/12
grep -n "22\|16\|13\|12" OpenCodeClient/OpenCodeClientTests/DesignTokenTests.swift
```

---

## Phase 4 — Motion & haptics (sensory work, after the seams)

### P4-1 · Define the motion presets and the motion budget

**Plan phase:** 4, Step 1
**Depends on:** P1-1, P0-2
**Description:**
Create `Utils/DesignMotion.swift` (or extend `DesignAnimation` in
`Utils/DesignTokens.swift`) with named presets only — `DesignMotion.toolExpand`,
`.messageEnter`, `.cardEnter`, `.listCrossfade` — each with a duration/response
ceiling. Add a lint rule that no View may call `withAnimation` with a raw duration.
Keep the existing public token names so the current call sites do not churn.
**Acceptance:**
```bash
test -f OpenCodeClient/OpenCodeClient/Utils/DesignMotion.swift
./scripts/polish_lint.sh --rules=motion   # exit 0
```

### P4-2 · Implement the motion the spec requires but the code lacks

**Plan phase:** 4, Step 2
**Depends on:** P3-2, P4-1
**Description:**
Implement the entries from the spec's motion table that are currently missing:
user-message entrance (offset y 16→0 + opacity 0→1, 0.28s ease-out,
`design.md:114`), permission/question slide-in (24→0 + fade, `design.md:117`),
session-switch 0.2s crossfade (`design.md:118`), and the custom tool-card expansion
spring (response 0.32, damping 0.82, `design.md:115`).
**Restrict edits in `ChatTabView.swift` to the message-list region** — do not touch
`voiceRail`, `voiceRailTransportButton`, `voiceRailTrailingAction`, or
`ChatTabView+VoiceInput.swift`; PRs #215/#216 are awaiting on-device acceptance on
exactly that surface.
**Acceptance:**
```bash
grep -rEn "withAnimation\(\.[a-z]|withAnimation\([0-9]" OpenCodeClient/OpenCodeClient/Views --include="*.swift" | wc -l   # → 0
grep -rn "DisclosureGroup" OpenCodeClient/OpenCodeClient/Views --include="*.swift" | wc -l   # → 0 (tool card uses the custom spring)
./scripts/test_unit.sh && ./scripts/test_ui.sh
```

### P4-3 · Define the haptic matrix

**Plan phase:** 4, Step 3
**Depends on:** P0-2
**Description:**
Create `Utils/DesignHaptics.swift` with named haptic events, one per interaction
class, each with an explicit Reduce-Motion / silent-mode policy. Write the matrix into
the rubric: send, permission-arrival, question-arrival, failed-send, destructive
confirm, selection change, recording start/stop.
`POL-HAPTIC-*` rows are tagged `ios-only` — haptics do not exist on Android in the
same form, and an untagged rubric row will let the sibling client drift.
**Acceptance:**
```bash
test -f OpenCodeClient/OpenCodeClient/Utils/DesignHaptics.swift
grep -c "POL-HAPTIC-" docs/features/polish/rubric.md   # → ≥ 7
grep -c "ios-only" docs/features/polish/rubric.md       # parity split recorded
```

### P4-4 · Implement the haptic matrix

**Plan phase:** 4, Step 4
**Depends on:** P3-2, P4-3
**Description:**
Implement the matrix. The app currently has **zero** haptic feedback anywhere — this
is the single largest sensory gap, and the most visible consequence of the app
feeling inert. Map each event to `sensoryFeedback` (the iOS 17.0 deployment target
supports it).
**Acceptance:**
```bash
grep -rn "FeedbackGenerator\|sensoryFeedback" OpenCodeClient/OpenCodeClient --include="*.swift" | wc -l   # → ≥ 7 distinct events
./scripts/polish_lint.sh --rules=haptics   # exit 0
./scripts/test_unit.sh && ./scripts/test_ui.sh
```

---

## Phase 5 — First vertical slice: the chat message stream

> Five separately landable PRs, one concern each. No PR mixes a conformance fix with a
> refactor. The composer, the voice rail, and `ChatTabView+VoiceInput.swift` are
> excluded — PRs #215/#216 are still awaiting on-device acceptance there.

### P5-1 · Chat slice: geometry conformance

**Plan phase:** 5, Step 1
**Depends on:** P2-2, P2-4, P3-2
**Description:**
Two geometry fixes in `MessageRowView.swift`: the user-message accent stripe is
`width: 4` but `design.md:99` specifies 3pt (add `DesignSpacing.accentStripe`), and
the bubble uses `DesignCorners.large` (16pt) where `design.md:95` specifies 12pt for
information/action cards (16pt is for sheets).
**Acceptance:**
```bash
grep -n "accentStripe" OpenCodeClient/OpenCodeClient/Views/Chat/MessageRowView.swift
grep -n "DesignCorners.medium" OpenCodeClient/OpenCodeClient/Views/Chat/MessageRowView.swift
./scripts/test_ui.sh   # ToolCardsUITests green
```

### P5-2 · Chat slice: error surface conformance

**Plan phase:** 5, Step 1
**Depends on:** P2-2
**Description:**
`MessageRowView.swift:648,651` renders a red error block. `design.md:63` forbids it:
"Error — uses `accent` (blue) to carry the warning together with explicit text, no red
background block (red is reserved for destructive operations such as the
delete-session confirmation button)". Red is reserved for destructive operations.
**Acceptance:**
```bash
grep -rn "Semantic.error" OpenCodeClient/OpenCodeClient/Views --include="*.swift" | wc -l   # → 0
./scripts/test_unit.sh
```

### P5-3 · Chat slice: user-message entrance transition

**Plan phase:** 5, Step 2
**Depends on:** P4-2
**Description:**
Implement the user-message entrance the spec requires (`design.md:114`: offset y
16→0 with opacity 0→1, 0.28s ease-out) via `DesignMotion.messageEnter`. It does not
exist today. Gate it on `accessibilityReduceMotion` — the repo already handles Reduce
Motion in 14 places, so this follows the existing pattern.
**Acceptance:**
```bash
grep -n "messageEnter" OpenCodeClient/OpenCodeClient/Views/Chat/MessageRowView.swift
grep -n "accessibilityReduceMotion" OpenCodeClient/OpenCodeClient/Views/Chat/MessageRowView.swift
./scripts/test_unit.sh
```

### P5-4 · Chat slice: custom tool-card disclosure

**Plan phase:** 5, Step 3
**Depends on:** P4-2
**Description:**
Replace the system `DisclosureGroup` at `ToolPartView.swift:90` with the spec's custom
spring (response 0.32, damping 0.82, `design.md:115`).
**Do not change the accessibility identifier or the expansion value** — `docs/tests.md:235`
and `ToolCardsUITests` depend on `toolcard.toolcalls` and the `已展开/已收起` value.
**Acceptance:**
```bash
grep -rn "toolcard.toolcalls" OpenCodeClient/OpenCodeClient/Views --include="*.swift"   # unchanged count
grep -rn "DisclosureGroup" OpenCodeClient/OpenCodeClient/Views --include="*.swift" | wc -l   # → 0
./scripts/test_ui.sh   # ToolCardsUITests green
```

### P5-5 · Chat slice: 44pt hit targets on permission and question actions

**Plan phase:** 5, Step 4
**Depends on:** P3-2, P5-1
**Description:**
`PermissionCardView.swift:42-69` and `QuestionCardView.swift` use
`.buttonStyle(.plain)` text buttons with no 44pt minimum target. Bring them to WCAG
2.2 target size, following the existing `ComposerHitTarget.minimum = 44` precedent at
`Utils/EffectiveLayout.swift:229`. Verify with Dynamic Type at `accessibility3`.
**Acceptance:**
```bash
grep -rn "ComposerHitTarget.minimum\|hitTarget\|minimumScaleFactor" OpenCodeClient/OpenCodeClient/Views/Chat/PermissionCardView.swift
./scripts/test_ui.sh
```

---

## Phase 6 — Preview coverage

### P6-1 · Add SwiftUI previews for every screen view

**Plan phase:** 6
**Depends on:** P1-3, P2-2
**Description:**
Today exactly **one** file has a `#Preview` (`ContentView.swift:921`) while 16+ screens
exist. Add previews for each screen-level view: `ContentView`, `ChatTabView`,
`SessionListView`, `SettingsTabView`, `HostProfilesView`, `FileTreeView`,
`FileContentView`, `ModelShortlistView`, `MarkdownWebPreviewView`, `CarLiveView`,
`CarModeView`, `ClientCapabilityPermissionView`, `QuestionCardView`,
`PermissionCardView`, `FileCardView`, `ToolPartView`.
Reuse the existing fixtures in `Views/Support/` rather than inventing sample data. Build
each preview on an **isolated `UserDefaults` suite** — `.standard` leaks between
previews and suites. Cover light and dark, and the `.compact` / `.regular` layout
branches. Add a lint rule: every screen-level View file must contain a `#Preview`.
Land the chat/files surfaces first; `HostProfilesView` and `ContentView` overlap
in-flight work.
**Acceptance:**
```bash
grep -rl "#Preview" OpenCodeClient/OpenCodeClient/Views --include="*.swift" | wc -l   # → ≥ the screen count
grep -rL "#Preview" <screen view files>                                               # → empty list
xcodebuild build -project OpenCodeClient/OpenCodeClient.xcodeproj -scheme OpenCodeClient -destination 'generic/platform=iOS Simulator'
```

---

## Phase 7 — Rollout to the remaining surfaces

> Ordered lowest collision → highest. Each surface is its own PR.

### P7-1 · Rollout: Settings

**Plan phase:** 7, step 1
**Depends on:** P5-5
**Description:**
`SettingsTabView.swift` (540 lines) — a grouped Form that exercises the
accent-in-a-picker rule at `:122`. This is also the "does the grammar generalize?"
surface: a Form's polish is dominated by system chrome, so it tests whether our
decisions hold outside the chat stream.
**Acceptance:**
```bash
./scripts/polish_lint.sh   # exit 0
./scripts/test_unit.sh && ./scripts/test_ui.sh
```

### P7-2 · Rollout: Session list

**Plan phase:** 7, step 2
**Depends on:** P5-5, P3-2
**Description:**
`SessionListView.swift` (645 lines). **Must land after the in-flight host-profile diff
is committed** — it overlaps that work. Also fixes the fixed `width: 88` close button
that can overflow in long locales (`SessionListView.swift:29`).
**Acceptance:**
```bash
grep -n "width: 88" OpenCodeClient/OpenCodeClient/Views/SessionListView.swift   # resolved
./scripts/test_unit.sh && ./scripts/test_ui.sh
```

### P7-3 · Rollout: Host profiles

**Plan phase:** 7, step 3
**Depends on:** P5-5, P2-2
**Description:**
`HostProfilesView.swift` (1054 lines). **Must land after the host-profile PR merges.**
Two specific spec obligations apply here: `design.md:238` (Dynamic Type on
`LabeledContent` — the `Assigned Remote Port` label and value must not squeeze and
occlude each other) and `design.md:242` (an unprocessed raw Swift error must never be
exposed directly in the UI).
**Acceptance:**
```bash
grep -rn "Color\.(red|blue)" OpenCodeClient/OpenCodeClient/Views/HostProfilesView.swift | wc -l   # → 0
./scripts/test_unit.sh && ./scripts/test_ui.sh
```

### P7-4 · Rollout: Files and preview surfaces

**Plan phase:** 7, step 4
**Depends on:** P5-5
**Description:**
`FileTreeView.swift`, `FileContentView.swift`, `ModelShortlistView.swift`,
`MarkdownWebPreviewView.swift`.
**Acceptance:**
```bash
./scripts/polish_lint.sh   # exit 0
./scripts/test_unit.sh && ./scripts/test_ui.sh
```

### P7-5 · Rollout: Composer and voice rail (last)

**Plan phase:** 7, step 5
**Depends on:** P5-5
**Description:**
`ChatToolbarView.swift`, `ChatComposerTextView.swift`, `ChatTabView+VoiceInput.swift`.
**Last deliberately.** This is the surface PRs #215/#216 are awaiting on-device
acceptance for. Any whitespace or motion change here re-opens that acceptance loop, so
it must land after those PRs are accepted and merged.
**Acceptance:**
```bash
./scripts/polish_lint.sh   # exit 0
./scripts/test_unit.sh && ./scripts/test_ui.sh
```

### P7-6 · Rollout: Car and Ambient surfaces

**Plan phase:** 7, step 6
**Depends on:** P5-5
**Description:**
`CarLiveView.swift`, `CarModeView.swift` — the experimental ambient surface.
**Acceptance:**
```bash
./scripts/polish_lint.sh   # exit 0
./scripts/test_unit.sh
```

---

## Phase 8 — Closure

### P8-1 · Close out the initiative and update the docs

**Plan phase:** 8
**Depends on:** P7-6, P6-1
**Description:**
Record every decision and its evidence in `docs/WORKING.md`: the TENSION A branch
(A1), the D1 choice, the first-slice choice, and each phase's exit evidence. Mark
every rubric row `PASS` / `WAIVED (reason)` / `DEFERRED (surface)`. Update
`docs/README.md` so `features/polish/` is discoverable, matching the per-feature
convention. Update `PROJECT-CONTEXT.md` with the new phase, the current test baseline,
and a pointer to the rubric.
The watch target gets a visible `DEFERRED` row — out of v1, with its reason recorded,
not silently omitted.
**Acceptance:**
```bash
grep -n "features/polish/" docs/README.md
grep -n "polish" docs/WORKING.md
grep -c "| PASS |" docs/features/polish/rubric.md   # every non-deferred row resolved
./scripts/test_unit.sh && ./scripts/test_ui.sh
```

---

## Issue count

| Phase | Issues |
|---|---|
| 0 — Definition of done | 5 |
| 1 — Enforcement harness | 4 |
| 2 — Seam cleanup | 5 |
| 3 — Type scale | 5 |
| 4 — Motion & haptics | 4 |
| 5 — Chat vertical slice | 5 |
| 6 — Preview coverage | 1 |
| 7 — Rollout | 6 |
| 8 — Closure | 1 |
| **Subtotal (the planned 36)** | **36** |
| Follow-ups raised during implementation | 3 |
| **Total in the project** | **39** |
