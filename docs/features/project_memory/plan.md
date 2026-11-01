# Project Memory — implementation plan

> Spec: `design.md`. Feature: the `AGENTS.md` surface — read the file the OpenCode server injects
> into every provider turn, ask the agent to improve it, review the diff.
>
> Status: **implemented** (2026-10-27).

## Scope

One feature, nine touched files, one new surface. No new endpoint, no new protocol requirement, no
client-side write.

## Steps

### 1. The model — `Models/ProjectMemory.swift` (new)

- `ProjectMemoryFile.instructionFileName` — `"AGENTS.md"`.
- `ProjectMemoryFailure` — `.binary` / `.transport(String)`.
- `ProjectMemoryModel` — one value holding the content state, the accepted baseline, the in-flight
  flag, the search root, the loaded directory, the noted write ids and the read generation, so a
  read and a baseline can never be observed half-updated.
- `ProjectMemoryModel.Content` — `.notLoaded` / `.loading` / `.absent` / `.text` / `.unreadable`.
- `ProjectMemoryModel.settledSnapshot` — the only answer the change logic may use. A read in
  flight and a failed read are neither a change, a deletion nor a creation.
- `ProjectMemorySnapshot` — the accepted version. `text == nil` means "there was no instruction
  file", which is different from "never captured" (`baseline == nil`).
- `ProjectMemoryPrompt.improve` / `.restore(previous:)` — the two prompts, as constants, so they are
  reviewable and testable.
- `ProjectMemoryChangeScanner.instructionFileWrites(in:)` — the ids of the parts that wrote the
  instruction file, matching on the path's last component.

The wire mapping lives in one nonisolated static on `AppState`:
`projectMemoryContent(for: ProjectMemoryReadOutcome)`. It is pure, so the rules are unit-testable
without a server.

### 2. The wire — none

The read is `state.loadFileContent(path: "AGENTS.md", workspaceDirectory:)`:

| | V1 | V2 |
|---|---|---|
| Request | `GET /file/content?path=AGENTS.md&directory=<directory>` | `GET /api/fs/read/AGENTS.md?location[directory]=<directory>` |
| Missing file | `APIError.httpError(statusCode: 404, …)` | the same |
| Non-text | `FileContent(type: "binary", content: nil)` | the same |

`makeRequest` throws on any non-2xx, so a missing file is a 404 on both generations. `FileContent`
is `{type, content}`; `.text` is the convenience accessor.

### 3. State — `Stores/FileStore.swift` (edit)

Add `var projectMemory: ProjectMemoryModel = ProjectMemoryModel()`. `FileStore` is in-memory and
`@Observable`; the baseline lives here so it survives a tab switch between Files and Chat.

### 4. The logic — `AppState+ProjectMemory.swift` (new)

- `projectMemorySearchPaths` — the session's directory first, then its parents up to the project
  root, bounded by the user's project selection, the server's current project, or the known project
  that contains the session's directory, and capped at 8 levels. This is the same walk the server
  does, so the panel shows the file the agent actually gets.
- `projectMemorySearchBound` — where the walk stops.
- `loadProjectMemory()` — searches, maps the outcome onto the content state, and captures the
  baseline on the first settled read of a directory. Guarded by the host snapshot, a generation
  counter and the search root, so a stale response cannot win. A cancelled read claims nothing.
- `loadProjectMemoryIfNeeded()` — reads once per directory.
- `acceptProjectMemoryChange()` — advances the baseline to what the user accepted.
- `improveProjectMemory()` — sends `ProjectMemoryPrompt.improve` through `sendMessage`, which is
  the ordinary prompt path into the current session. Refuses while a turn is running.
- `restoreProjectMemory()` — sends `ProjectMemoryPrompt.restore(previous:)` with the baseline.
- `refreshProjectMemoryIfChanged()` — re-reads when the agent wrote the file, once per write part,
  and notes the write only after the read landed.
- `projectMemoryAgentIsWorking` — the dispatch flag plus the session's busy status.

### 5. Freshness — `AppState+FileChanges.swift` (edit)

`refreshFileChangeState()` gains one call: `await refreshProjectMemoryIfChanged()`. It runs after
the existing 400 ms debounce, so the panel never reads a file the agent is still writing, and it
reuses the write-signal machinery that already keeps the tree honest.

The refresh is gated on `projectMemory.hasLoaded`: a panel nobody looked at does not earn a read.

The panel re-reads once more when the session stops being busy, because the write signal only fires
for tools the classifier recognises.

### 6. The surface — `Views/ProjectMemoryView.swift` (new) + `Views/FilesTabView.swift` (edit)

- `FilesTabView` gains `FilesProjectMemorySection`, a sibling of `FilesChangesSection` inside the
  same `safeAreaInset(edge: .top)`, above the tree.
- The section states the file's presence and its size, and opens the panel. Its summary keeps its
  last known value while a read is in flight, so the section does not flicker.
- `ProjectMemoryView` is the panel: the state banner, the path the file was read from, the
  rendered content, the actions and the review diff. It is pushed with a direct
  `NavigationLink(destination:)`, which does not collide with the `String` route `FileTreeView`
  already claims.
- The three action labels do not fit on one phone row, so the action bar uses `ViewThatFits`: a
  row when it fits, a stack when it does not.

The panel is one implementation for iPhone, iPad and visionOS: `FilesTabView` is used by both
layouts in `ContentView`.

### 7. The strings — `Support/L10n.swift` (edit)

New `Key` cases plus both the `en` and the `zh` entry. `LocalizationTests.localizationKeyCoverage`
fails the suite when either table is missing a key, so both are required.

### 8. The tests — `OpenCodeClientTests/ProjectMemoryTests.swift` (new) + `TestDoubles.swift` (edit)

`MockAPIClient` gains a configurable `fileContentResult` / `fileContentError` (typed `Error?`, so a
`DecodingError` can be injected), a per-directory result and a per-directory 404, defaulting to the
current behaviour so no existing test changes.

`OpenCodeClientUITests/ProjectMemoryUITests.swift` drives the fixture on the simulator.
`Views/Support/ProjectMemoryFixture.swift` answers the one request the panel makes, in three modes:
present, absent, and changed.

### 9. Verification

```
./scripts/test_unit.sh
```

`ProjectMemoryTests`: 43 tests, green. Full unit suite: 1086 tests in 110 suites, green, with the
6 pre-existing known issues in `DesignTokenTests`.

```
xcodebuild test-without-building ... -only-testing:OpenCodeClientUITests/ProjectMemoryUITests
```

4 UI tests, green, with screenshots of the panel and the review diff.

## Decisions

| Decision | Why |
|---|---|
| The current session receives the improve prompt | The agent's reasoning stays visible; instruction mutation is privileged and should be auditable. `sendMessage` has no other session, and the panel must not hijack the user's selection. |
| The client never writes the file | There is no endpoint that lets a client write a workspace file. The agent owns file writes. |
| Restore is agent-mediated | Same reason. It is fallible, and the panel says so. |
| The baseline is the **accepted** version, not the last-seen one | It is captured on the first settled read and only advances when the user accepts. That is what keeps a rewrite the agent did while the user was elsewhere visible as a diff instead of being silently adopted. |
| The baseline lives in `FileStore`, not the view | The user leaves the Files tab to watch the agent work; the diff must still be there when they come back. |
| Only `AGENTS.md` | V1 also reads `CLAUDE.md` and configured `instructions`; V2 reads only `AGENTS.md`. Supporting more would make the panel lie on some servers. The panel states which file it read. |
| The search walks up from the session's directory | The server loads the nearest `AGENTS.md` walking up to the project root. A client that only looked in the session's directory would report "no project memory" for a project that has one, and the improve action would make the agent write a second, shadowing file. |
| No client-side embedding index | The PRD reserves recall for the agent and the workspace's semantic search. |
