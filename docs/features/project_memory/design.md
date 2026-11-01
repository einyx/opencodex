# Project Memory — design

> Status: **implemented**. Plan: `plan.md`.
> Related: `docs/features/context_compaction/design.md` (working context),
> `docs/features/session_finder/design.md` (recall), `docs/OpenCode_Web_API.md` (wire).
>
> Note: the 2026-10-26 docs restructure dropped the PRD, the RFC and several feature docs
> (`context_compaction`, `session_finder`, `polish`) from the working tree while `docs/README.md`
> kept indexing them. The related documents above are on `origin/master`; the PRD quote below is
> from `origin/master:docs/OpenCode_iOS_Client_PRD.md` §4.2.7.
>
> This is **P0** of the memory work: it makes the one memory layer the OpenCode server
> already owns — the project instruction file — visible and improvable from the phone.

## Intent

The OpenCode server injects `AGENTS.md` into **every** provider turn. From a phone, that file is
invisible: you cannot see what your agent believes about the project, you cannot tell whether it is
empty or stale, and you cannot fix it without an SSH session.

Project Memory turns that file into a first-class surface: read it, understand what it does, and
ask the agent to improve it — with the change shown before you accept it.

## Why this, and not a client-side memory store

Palvia's memory system (on-device SwiftData + `NaturalLanguage` embeddings + hybrid search +
auto context injection) is a **server-side** feature. Palvia owns the LLM call, the system prompt
and the tool loop, so it can render retrieved chunks into the prompt and expose
`search_sessions` / `recall_session` as model-callable tools.

OpenCodex owns none of that. The OpenCode server owns the agent loop, the prompt assembly, the
transcript store and the compaction. A client-side copy of Palvia's memory would have to smuggle
retrieved context in as a user message part — visible in the transcript, re-billed every turn,
subordinate to the server's own instruction injection, and silently promoting stale plans, past
mistakes and prompt-injected tool output.

This is also the position the product already took. `docs/OpenCode_iOS_Client_PRD.md` (§4.2.7) states
that global session retrieval is carried by the agent and the workspace's semantic-search, and that
**the client adds no local search page, no embedding index and no archive reading**. The same rule
applies here: the client surfaces server-owned artifacts and asks the server to act on them.

So Project Memory is deliberately the **thin** half of a memory system:

| Layer | Owner | Project Memory does |
|---|---|---|
| Instruction context (what should govern behavior) | Server, via `AGENTS.md` | **Makes it visible and improvable** |
| Durable history (what happened) | Server SQLite | Nothing — out of scope |
| Working context (what the model sees now) | Server compaction | Nothing — `context_compaction` |

It is the review path for the one mutation upstream calls privileged. An autonomous memory layer
would have to answer "which statements are facts, and who may write them?" — the client cannot
answer that, so the client does not make that decision.

## Goals

- **G1** The user can read the project's instruction file on the phone, as rendered Markdown.
- **G2** The client states plainly what the file does (injected into every turn) and where it lives.
- **G3** A missing file is a first-class state ("no project memory yet"), not an error.
- **G4** The user can ask the agent to improve the file through the ordinary prompt path — no new
  endpoint, no server contract.
- **G5** When the agent rewrites the file, the user sees a real before/after diff before deciding.
- **G6** The client stays read-only against the workspace: it never writes server files.
- **G7** V1 and V2 servers both work.
- **G8** Every state is readable as text (VoiceOver, greyscale, colour-blind) — colour is decoration.

## Non-goals

- **NG1** No client-side embedding index, vector store or semantic search. See "Why this" above.
- **NG2** No automatic injection of the file's content into the user's prompts. The server already
  injects it; injecting it twice would double the cost and contradict the server's authority.
- **NG3** No client-side write to the workspace. The agent owns file writes; the client observes.
- **NG4** No `CLAUDE.md` / `CONTEXT.md` / configured `instructions` sources in V0. The legacy loader
  supports them and V2 does not, so supporting them would make the panel lie on some servers.
- **NG5** No cross-project memory. The file belongs to one project directory.
- **NG6** No auto-refresh loop. The panel refreshes on open, on the toolbar refresh, and when the
  agent signals it changed the file.

### Which file is read

The server loads the **nearest** `AGENTS.md`, walking up from the session's directory to the
project root. The client walks the same way, from the same start, bounded by the same project
root — so the panel shows the memory the agent actually gets.

The bound is the user's project selection, then the server's current project, then the known
project that contains the session's directory. With none of them known, the walk stops at the file
system's root or a depth cap of 8.

This matters: if the session runs in a subdirectory of the project, the server injects the
**project root's** file, so a client that only looked in the session's directory would report "no
project memory yet" for a project that has plenty — and the "improve" action would make the agent
write a *second*, shadowing file.

The panel states the file it read, as an absolute path, so the answer is never a guess.

## Wire facts the design is built on

| Fact | Consequence |
|---|---|
| The server injects `AGENTS.md` into every provider turn (V1 `instruction.system()` per step; V2 `InstructionContext` as a `SystemContext` source) | The file is worth showing: it is the highest-leverage memory the client does not own |
| V1 reads `AGENTS.md`, `CLAUDE.md` and configured `instructions` paths/URLs; V2 `InstructionContext` observes `AGENTS.md` only | V0 supports `AGENTS.md` only (NG4) |
| `APIClient.fileContent(path:directory:)` already exists and branches on generation: V1 `GET /file/content?path=&directory=`, V2 `GET /api/fs/read/<path>?location[directory]=` returning **raw bytes** | **The read needs no new wire code at all** |
| `FileContent` is `{type, content}`; V2 decodes UTF-8 to `type: "text"` and anything else to `type: "binary"`, `content: nil` | "not a text file" is a decidable state, not a decode failure |
| A missing file raises `APIError.httpError(statusCode: 404)` on both generations | 404 maps to `.absent`; every other failure maps to `.unreadable(.transport)` |
| `AppState.effectiveProjectDirectory` is the resolved project root (selected project worktree, or the custom-path sentinel resolved to its path) | The read is scoped to the project the user is actually working in — the same scope every other file call uses |
| The server searches instructions **upward** from the active directory to the project root | V0 reads the project root and says so (NG5) |
| The server has no HTTP endpoint that lets a client write a workspace file | The client cannot write `AGENTS.md`; the agent must (NG3) |
| `DiffLineParser.lines(before:after:)` derives a diff from two texts | The before/after diff needs no new diff engine |
| `FileChangeSignalScanner` finds "the agent wrote a file" signals, but a `Signal` carries only the part ID and the turn — **not** the paths | The panel needs its own narrow scanner over `Part.filePathsForNavigation`, which does carry the written paths |
| `AppState.scheduleFileChangeRefresh()` debounces the tree/status/diff refresh by 400 ms after a write | The panel reuses the same settling window so it does not read mid-write |

## The design

### 1. Model

One value holds everything the panel shows, so a read, a baseline and an in-flight turn can never be
observed half-updated:

```
ProjectMemoryModel
├── content: ProjectMemoryModel.Content
│     ├── .notLoaded                the file has not been read yet
│     ├── .loading                  a read is in flight
│     ├── .absent                   no AGENTS.md at or above the session's directory
│     ├── .text(String)             the file's text
│     └── .unreadable(ProjectMemoryFailure)
│           ├── .binary             the file exists but is not UTF-8 text
│           └── .transport(String)  the read failed (offline, auth, 5xx, undecodable body)
├── baseline: ProjectMemorySnapshot?  the version the user has accepted
├── pendingAction: Bool                a request is dispatched and the turn has not settled
├── sawBusySinceDispatch: Bool          the session has been busy since the request went out
├── searchRoot: String?               the directory the last search started from
├── loadedDirectory: String?          the directory the file was actually found in
├── hasLoaded: Bool                   the file has been read at least once
├── notedWritePartIDs: Set<String>    the writes already seen
└── loadGeneration: UInt64            the read generation
```

`ProjectMemoryModel.Content` is `Equatable` + `Sendable` and carries no `Date` — the timestamp comes
from the file change signal, not from the read.

Three details are load-bearing:

- **`settledSnapshot` is the only answer the change logic may use.** A read in flight and a read
  that failed both leave the client without an answer, and neither may be reported as a deletion
  or a creation. `hasChange`, `wasDeleted` and `wasCreated` are all keyed off it.
- **`hasLoaded` is not `searchRoot`.** A root of `nil` means "the server's default directory", not
  "never read", and the two have to be told apart. Inferring one from the other made the panel skip
  its first read entirely, and skip every refresh after it.
- **`notedWritePartIDs` is not `searchRoot` either.** A transcript keeps the writes of every past
  turn, so without this the file would be re-read on every refresh forever — the same mechanism
  `file_changes_surface` uses with `notedChangePartIDs`.

The baseline is a separate value:

```
ProjectMemorySnapshot
└── text: String?     the file's text, or nil when there was no file
```

A snapshot with no text means the file was absent — which is different from "never captured",
which is what a missing baseline means. The baseline is the version the user has **accepted**: it
is captured on the first settled read of a directory and only advances when the user accepts a
change. That is what keeps a rewrite the agent did while the user was elsewhere visible as a diff
instead of being silently adopted.

The baseline is not persisted: it lives in the in-memory `FileStore` so it survives a tab switch
between Files and Chat.

### 2. Wire

**No new endpoint, no new protocol requirement.** The read is a call to the file-read method the
client already has:

```
state.loadFileContent(path: "AGENTS.md", workspaceDirectory: projectMemoryWorkspace)
```

- V1 → `GET /file/content?path=AGENTS.md&directory=<workspace>`
- V2 → `GET /api/fs/read/AGENTS.md?location[directory]=<workspace>`

The workspace is `currentSession?.directory ?? effectiveProjectDirectory ??
serverCurrentProjectWorktree`. The session wins because the server loads instructions relative to
the session's directory; the user's project selection and the server's current project are the
fallbacks.

The result is mapped onto the client-side content:

| Wire outcome | Content |
|---|---|
| `FileContent(type: "text", content:)` | `.text(content)` |
| `FileContent(type: "binary", content: nil)` | `.unreadable(.binary)` |
| HTTP 404 | `.absent` |
| Any other HTTP status | `.unreadable(.transport("HTTP <code>"))` |
| A body that does not decode | `.unreadable(.transport(...))` |

`makeRequest` throws on any non-2xx, so a missing file is a 404 on **both** generations — the
"absent" state needs no per-generation special case.

The mapping lives in two nonisolated static functions on `AppState` —
`projectMemoryContent(for: FileContent)` and `projectMemoryContent(for: Error)` — so the rules are
unit-testable without a server.

### 3. The improve action

A single action, **Improve with the agent**, which sends a crafted prompt into the **current
session** through the ordinary prompt path.

Why the current session and not a dedicated one:

- The user sees the agent's reasoning. Instruction mutation is a privileged operation; making it
  visible is the point.
- The server's own V2 `SystemContext` treats an `AGENTS.md` change as a context-source update, so
  the change takes effect for the running session too. That is desirable, not a problem.
- It needs no new endpoint and no session lifecycle of its own.

The prompt is a single constant in the client, `ProjectMemoryPrompt.improve`, written to mirror
upstream's own `/init` semantics: inspect the manifest, CI config, developer commands and
representative architecture files; record only facts a future session would otherwise have to
rediscover; reject generic advice and unverified claims; and **preserve everything the user wrote**.

Preservation is explicit because the file is injected into every future session: a rewrite that
silently drops a hand-written rule is a regression the user would not notice until much later.

Two consequences are handled explicitly:

- **The action is disabled while the session is busy.** A prompt sent into a running session is
  queued by the server and its position in the conversation is unpredictable.
- **The action stays disabled until the turn settles.** The request being *accepted* is not the
  turn starting — the server marks the session busy a moment later. The latch is cleared on the
  busy → idle transition, so a second tap cannot send the same prompt twice. A refused request
  clears the latch immediately.
- **The prompt is visible.** It is sent as an ordinary user message, so it appears in the
  transcript. The client does not hide it and does not pretend it was not sent.

### 4. Reviewing the change

After the agent's turn, the panel re-reads the file and compares it to the baseline.

- **Unchanged** → the panel returns to its normal state, no diff offered.
- **Changed** → the panel offers a diff, rendered with the existing `DiffLinesView` over
  `DiffLineParser.lines(before:after:)`.
- **Missing now** → the agent deleted it. That is a legitimate outcome (the file was wrong) and is
  reported as such, not as an error.

The diff follows the file-changes vocabulary already established by `file_changes_surface`: additions
in the accent, removals in secondary text, with markers, line numbers and labels carrying the
meaning (one-colour rule).

**Accept** is explicit: **Keep this version**. The file on the server is already the new version, so
accepting only decides whether the client keeps reporting the change. Without it, the panel would
claim a pending change forever, including for a version the user had already reviewed and accepted.

**Restore the previous version** is offered alongside it. The client cannot write the file (NG3),
so restoring is done by the agent: the client sends the accepted content back in a second crafted
prompt, `ProjectMemoryPrompt.restore`, which asks for a verbatim rewrite. This is agent-mediated and
therefore fallible — the panel says so rather than implying a guaranteed revert.

### 5. Freshness

The trigger is a write to the instruction file, detected narrowly and precisely.

`FileChangeSignalScanner` — the mechanism that keeps the Files tab from going stale mid-turn — does
not carry the changed paths; a `Signal` holds a part ID and a turn ID. The paths live on the part
itself, in `Part.filePathsForNavigation`, which resolves the written path from the tool input
(`path` / `file_path`) or from a patch header.

So the panel uses a focused scanner of its own:

```
ProjectMemoryChangeScanner.instructionFileWrites(in: [MessageWithParts]) -> [String]
```

It returns the ids of the parts that named a path whose last component is `AGENTS.md`. Matching on
the last component keeps it independent of whether the server reports the path as absolute or
relative to the project root.

The ids are then filtered against `notedWritePartIDs`. A transcript keeps the writes of every past
turn, so without that filter the file would be re-read on every refresh forever — the same
mechanism `file_changes_surface` uses with `notedChangePartIDs`. The writes are noted **after** the
read lands, not before: a failed read has to be retried.

This is deliberately narrow. The global file-change machinery is shared, battle-tested and keyed
on part IDs; a panel-specific predicate is cheaper to reason about and cannot perturb it. A nested
`docs/AGENTS.md` write is a false positive, and the only cost is one extra read.

The write signal only fires for tools the classifier recognises. A file written any other way would
leave the panel showing a stale version, so the **end of the turn** is the second chance to pick the
change up: the panel re-reads once when the session stops being busy.

The panel also re-reads when it appears and on the toolbar refresh. The baseline is **not** reset by
a re-read: the user asked for the current state, not for the pending change to be forgotten.

The re-read is debounced by the same 400 ms window the file-change refresh uses, so the panel does
not read a file the agent is still writing. A read also carries a generation counter, so a stale
response cannot overwrite a newer one — the panel's own `loadTree` uses the same guard.

### 6. Surfaces

- **Files tab** — a "Project Memory" entry at the top of the workspace browser, above the tree.
  The Files tab is the project's file surface, and this file is a project file with a special role.
  A one-line summary (present / missing, line count) makes it obvious that the file exists without
  opening it. The summary keeps its last known value while a read is in flight, so the section
  does not flicker on every refresh.
- **iPhone** — a pushed detail view with the rendered content, the state banner and the actions.
- **iPad / visionOS** — the same view in the Files column; no separate sheet. `FilesTabView` is
  used by both layouts, so there is one implementation.
- **Chat** — no entry point in V0. The Files tab is the right home for a project-level artifact,
  and adding a fifth toolbar item would crowd the session controls the PRD already fixes in order.

The panel states **which file it read**, as the absolute path when there is a workspace and as
"the server's default directory" when there is not. The server looks for instructions *upward* from
the session's directory, so the client says which one file it read rather than implying it is the
only instruction the agent sees.

### 7. Accessibility

- The state banner is one VoiceOver label: "Project memory. Injected into every agent turn." /
  "No project memory yet."
- The diff uses the same vocabulary as the session diff surface ("added, line 19: …").
- The action label says what it will do ("Improve with the agent"), never "OK".
- Nothing depends on colour: present/absent, changed/unchanged and add/remove are all textual.

## Test coverage

`OpenCodeClientTests/ProjectMemoryTests.swift` (43 tests):

- The wire mapping: text, absent, unreadable, cancelled.
- The settled snapshot: a read in flight and a failed read are neither a change, a deletion nor a
  creation.
- The baseline: unchanged, changed, deleted, created, and no baseline.
- The read asks for `AGENTS.md` in the session's directory; a 404 reads as absent, a 503 as
  unreadable, an undecodable body as unreadable and not as a missing file.
- A failed read does not capture an "absent" baseline, so the next good read is not reported as a
  creation.
- The file is read once per directory, and again when the directory changes.
- The baseline survives a re-read and is cleared when the directory changes.
- The upward search: it starts at the session's directory, stops at the project root, and finds the
  file in the parent directory.
- The improve prompt keeps what the user wrote and rejects generic advice; it is sent through the
  ordinary prompt path to the current session; it is refused while the session is busy and without a
  session.
- The restore prompt carries the previous content verbatim between its markers; restoring without a
  baseline, and restoring an absent baseline, do nothing.
- Accepting the change clears it.
- The scanner finds a write to the instruction file — relative and absolute — and ignores a read
  and a write to another file.
- Freshness: a file that was never read is not refreshed, a write to the instruction file refreshes
  the **content** (not just the request count), the same write is not read twice, and a write to
  another file does not refresh.

`OpenCodeClientUITests/ProjectMemoryUITests.swift` (4 tests) drives the fixture on the simulator:
the Files-tab section, the panel with its content and its path, the absent state, and the agent's
rewrite being offered for review with its diff.

Full unit suite: 1086 tests in 110 suites, green (6 pre-existing known issues in
`DesignTokenTests`).

## Open questions

- **Should the panel live in the Files tab or the Chat toolbar?** The Files tab is the current
  answer, but the Chat toolbar is where `Compact` will live, and a project-level artifact argued
  for in the chat may deserve the same placement. The PRD fixes the toolbar order
  ("Session 列表、重命名、Compact、新建 Session"), so adding a fifth item is a PRD change.
- **Restore semantics.** Agent-mediated restore is lossy in principle. If a server-side file-write
  endpoint ever appears for clients, restore should become exact.
- **The server searches upward.** It loads the nearest `AGENTS.md` between the active directory and
  the project root. V0 reads exactly one file at the project root and says so in the UI. If the
  panel later reports which file the server would actually load, it needs a server-side answer —
  there is no endpoint for "which instructions are active".
