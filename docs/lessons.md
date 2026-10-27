# Lessons — OpenCode iOS Client

> Reusable lessons distilled from the implementation and Code Review process

## 0. Change Workflow: Align the Docs First, Then Change the Code

A stable, reusable engineering workflow (especially suited to this project's "PRD/RFC-driven + fast iteration" collaboration model):

1. **First decide whether the PRD is affected**: as long as the change touches product behavior, interaction logic, or feature scope (even if it is only a fine-tuning of the iPad UI), update `docs/OpenCode_iOS_Client_PRD.md` first.
2. **Then decide whether the RFC is affected**: if the change alters the technical approach, the architecture constraints, or the development phases, update `docs/OpenCode_iOS_Client_RFC.md` in sync.
3. **Implement the code according to the docs**: code strictly following the established documents, and any correction to the approach made during implementation must be written back into the documents in a timely manner.
4. **Fill in the test cases**: business logic suitable for unit testing should be guarded against regressions with unit tests wherever possible; UI-level changes must at least cover the key pure-logic tests and the model decoding tests.
5. **Make sure the build and the tests are all green**: finally run `xcodebuild build` and then `xcodebuild test`, and confirm that the main flows have no regression.

**Lesson**: distill the "why" behind a decision into the PRD/RFC, and let the code focus only on the "how". Whether it is Code Review, problem tracing, or later iteration, the communication and maintenance costs drop dramatically.

## 1. Verify the API Directly Instead of Writing Code First and Guessing

**Scenario**: when researching the SSE event format, you need to know the actual response data structure of OpenCode `/global/event`.

**Anti-pattern**: make subjective assumptions first and write the parsing code, then run the iOS client and reverse-engineer the response format from the logs.

**Correct approach**: connect to the server and measure it directly with a command-line tool such as `curl`. For example:

```bash
curl -s -N -H "Accept: text/event-stream" "http://192.168.180.128:4096/global/event"
```

You can confirm on the spot that the actual output is `data: {"payload":{"type":"server.connected","properties":{}}}`, which visually verifies that it is single-line JSON.

**Lesson**: when integrating with or researching an external API, always prioritize capturing packets or measuring from the command line. Using the real response instead of subjective assumptions saves a large amount of ineffective coding and debugging cost.

---

## 2. Test First, Ship in Small Steps

**Scenario**: refactoring core logic such as splitting up the AppState module, extracting PathNormalizer, and Session filtering.

**Approach**:
- Before splitting, first fill in the test cases for the critical paths, covering the core business logic.
- First make the expected behavior explicit through tests, and only then restructure the code.
- Commit promptly after completing each independent sub-task, and update `WORKING.md` in sync.

**Lesson**: a thorough test suite is the safety net for a case refactor; small-step commits make code review clearer and make problems easier to roll back.

---

## 3. Organize Work with a Task List So Nothing Is Duplicated or Missed

**Scenario**: handling the cross-cutting tasks of Code Review 1.1–1.4, including adding tests, splitting modules, SSE handling, Session filtering, and extracting PathNormalizer.

**Approach**: build a structured task list and track the whole flow, checking off and archiving each item as it advances, so that nothing is missed and nothing is developed twice.

**Lesson**: breaking a complex multi-task effort into a quantifiably trackable Checklist effectively avoids the passive situation of "working along and then missing a key point".

---

## 4. API Measured vs Specification Assumed

**Scenario**: the standard SSE specification includes mechanisms such as multi-line data, the `event:` field, and comment keep-alive, and the Code Review suggested fully supporting the standard specification.

**Approach**: capture packets and measure the server's real behavior, confirming that it only pushes single-line `data:`. The existing streamlined implementation fully meets the business requirement, so there is no need for over-encapsulation for now.

**Lesson**: theoretical specifications and real system implementations often differ; verify the real data flow before starting, spend effort where it counts, and avoid premature over-design.

---

## 5. Keep the External API Unchanged When Splitting

**Scenario**: splitting the huge AppState refactor into dedicated stores such as SessionStore, MessageStore, FileStore, and TodoStore.

**Approach**: on AppState, forward the delegation through computed properties, fully preserving the existing APIs such as `state.messages` and `state.sessions`, so that the upper-layer Views stay unchanged.

**Lesson**: an internal system refactor should keep the upper-layer public interfaces as stable as possible and converge the surface area of the code change, thereby minimizing the regression risk.

---

## 6. SSE Filtering in Multi-Session Scenarios

**Scenario**: in a multi-Session concurrent scenario, if the received `message.updated` events are not validated and filtered by sessionID, data will leak across sessions.

**Approach**: in the event dispatch layer, strictly extract the `sessionID` from the event payload for the check, and only respond to and update data for the currently active session.

**Lesson**: in a multi-session or similar multi-tenant architecture, events must carry a unique scope identifier (such as a Session or Tenant ID), and the client must also filter precisely before consuming them.

---

## 7. Centralize Cross-Module Logic into a Single Layer

**Scenario**: the path normalization logic was originally scattered across Message.swift and the string-trimming logic in various views, which easily produces divergent standards.

**Approach**: converge all path handling into the `PathNormalizer` utility class, centrally parsing and handling formats such as the a/b prefix, the `#` anchor, and the `:line:col` line/column numbers.

**Lesson**: any general rule or data-cleaning logic that spans modules should be gathered into a single-responsibility layer and maintained in one place, avoiding the redundancy and behavioral inconsistency caused by scattered implementations.

---

## 8. @MainActor and Testability

**Scenario**: `shouldProcessMessageEvent` was originally declared inside AppState, so calling it directly in a unit test triggered a main thread isolation error (main actor-isolated).

**Approach**: explicitly mark the stateless pure-logic methods as `nonisolated` so that they can be called synchronously and directly in a test context.

**Lesson**: pure computation or decision logic that needs unit test coverage should be extracted into nonisolated or static methods wherever possible, removing the unnecessary coupling with the MainActor lifecycle and the concurrent environment.

---

## 9. SSE-first Does Not Mean "Relying on SSE Alone"; Pair It with a One-Off Compensating Sync

**Scenario**: the iOS app can lose SSE events that fall into a gap window when it switches between foreground and background, when the network fluctuates, when the session is switched, or when the connection is re-established after a drop.

**Approach**:
- In the normal state, rely entirely on SSE to push deltas, avoiding the resource cost of a resident high-frequency poll.
- At key lifecycle moments (such as a successful SSE reconnect, or when the user switches into a session), trigger one lightweight full reconciliation (bootstrap): run `loadMessages + refreshPendingPermissions`.
- Improve the bootstrap's trigger-context logging, recording the trigger reason (reason), the elapsed time (elapsed), the message count (messages), and the permission entries (permissions).

**Lesson**: real-time communication on mobile should adopt the cooperative design of "delta events as the main channel + full reconciliation compensation at key moments", keeping the system stable while staying low-power.

---

## 10. SSH Secure Defaults: TOFU + Mismatch Hard Fail

**Scenario**: if the SSH tunnel is configured directly with `acceptAnything`, it has in fact completely given up on verifying the identity of the remote host.

**Approach**:
- First connection: use the TOFU (Trust On First Use) mechanism, persistently recording the host key per host:port.
- Subsequent connections: as soon as the public key fingerprint mismatch is detected, immediately block the connection (hard fail) and clearly warn the user about the risk of a man-in-the-middle attack (MITM) or of a reinstalled host.
- At the UI level, provide fingerprint detail display and an entry point for resetting the trusted host (reset trusted host).

**Lesson**: when a feature involving remote communication ships, the security baseline must land with it; "getting the connection working" is only the first step, while "establishing a trusted channel" is the standard for a qualified delivery.

---

## 11. Use a Gate-Based Test-First Approach for Complex Refactors

**Scenario**: a deep split of AppState involves many chains — state machine migration, SSE dispatch, UI refresh rules, and so on — so the regression risk is extremely high.

**Approach**:
- Decompose it into multiple progressive iteration rounds following Iteration A/B/C/D, with every round strictly following the principle of "first complete the behavior tests, then restructure the code".
- Set an explicit acceptance gate for each round (Gate, for example that all behavior tests pass), and only proceed to the next round once the gate is met.
- After each round is complete, record it thoroughly in `WORKING.md`, clearly listing the new test points and the risk assessment conclusions.

**Lesson**: a complex refactor must avoid a sweeping all-at-once change and should instead be broken into verifiable incremental migrations; gating them with objective test gates is far more trustworthy than subjective experience and intuition.

---

## 12. Activity Copy Needs "Debounce Semantics" Instead of Blind Real-Time Updates

**Scenario**: during tool calls and model reasoning, frequent changes to the copy cause the interface to shake violently, which brings severe visual noise.

**Approach**:
- Gather the derivation of the copy state and the debounce logic together into the underlying logic layer.
- Define a clear refresh rule: changes within a 2.5s time window use a delayed smooth update, and changes beyond the window take effect immediately.
- Make the calculation priority of the elapsed-time data in the completed and running states explicit, avoiding the display of misleading pseudo-precise numbers.

**Lesson**: the readability of information is also an important part of the real-time interaction experience; for the user, a "stable and trustworthy" state presentation is far more valuable than "refreshing immediately on any tiny change".

---

## 13. SSH UX Must Write the User's Next Action into the Interface

**Scenario**: when configuring an SSH tunnel, users easily fall into the confusion of "the switch is on but the connection still fails, or it is unclear what to do next".

**Approach**:
- Generate the complete SSH command line directly in the interface, with one-tap copy, eliminating the cognitive burden of the user assembling the command by hand.
- Make the public key copy entry point permanently visible, removing its hard binding to the switch's enabled state.
- Give clear operating guidance in the SSH configuration area: after enabling the configuration, the user must go back up and tap `Test Connection` to complete the connectivity verification.

**Lesson**: the core value of a configuration screen lies not only in the completeness of its fields but in whether it can guide the user smoothly through the whole flow. Writing the explicit "next action" directly into the UI copy greatly reduces interaction friction.

---

## 14. Optimize Long Sessions on Weak Networks with "Message Pagination" First, Not by Redoing Rendering

**Scenario**: after completing the view rendering optimization, the interaction in a LAN environment is smooth enough, but when accessing a long session across a WAN or through an SSH tunnel, the first-screen load still has noticeable delay.

**Approach**:
- First verify that the backend supports the `GET /session/:id/message?limit=` endpoint, then adjust the client's initial load strategy to fetch only the most recent 3 turns by default (that is, 6 messages).
- Provide a clear "pull down to load more history messages" interaction mechanism, each time going back a fixed step (+6).
- Handle the localization of the pagination hint copy and the loading state properly, avoiding the user's misunderstanding that "old data is lost".

**Lesson**: on weak networks and high-latency links, the bottleneck of the first-screen load often lies in the data transfer volume and the network round-trip overhead (RTT). Landing controlled message pagination first usually brings more significant and more stable performance gains than digging into micro-tuning in the View rendering layer.

---

## 15. Clarify the message Semantics First, Then Design the limit Strategy

**Scenario**: discussing message truncation often raises the question of the counting unit: "if one model interaction contains 10 tool calls and 1 final answer, does it count as 11 messages or as 1 message?"

**Approach**:
- Align strictly with the server's underlying data model: each tool call is a `part` under a message, not a standalone `message` entity.
- Make it clear that the pagination parameter `limit` controls the number of top-level messages, not the granularity of tool calls.
- Unify that definition in the specification documents such as the PRD and RFC, eliminating later misunderstandings about "3 turns of conversation correspond to 6 messages".

**Lesson**: before designing the pagination and truncation strategies, you must first clarify and unify the counting unit of the underlying data entities. Otherwise, product and technical discussions easily waste effort on the ambiguity of "is it one item visually, or many logical items".

---

## 16. Session and Project: Creation Is Limited to the Server Default

**Scenario**: after creating a session in the iOS client, the newly created Session unexpectedly disappears when tapping the session list or when switching the app to the background and then back to the foreground.

**Root cause**: the server's `POST /session` endpoint does not support passing a `directory` parameter, so a Session is always created under the server's current default Project (determined by the CLI startup path or by the last action in Web/TUI). The Project switcher on iOS essentially only affects the `GET /session?directory=X` list filtering and cannot change where a new session is actually created. When the Project selected by the user on the client differs from the server's default Project, the newly created Session falls into the server's default Project and therefore cannot be shown in the currently filtered list, so it simply "disappears" after a refresh.

**Attempts made**:
1. **mergeCurrentSessionIfMissing**: during `loadSessions`, if the current session is not in the list, request that Session separately and force-prepend it to the front of the list → treats the symptom rather than the cause, and `GET /session/:id` may return 404 directly when queried across Projects.
2. **session.updated filtered by project**: prevents Session change events from other Projects from leaking into the current list → a reasonable design, so it is kept.
3. **Settings warning + guidance to switch in Web** → the approach does not hold up: the Web client cannot change the server's working directory remotely either.
4. **Remove the Project selection (roll back)** → not adopted: keeping the multi-Project list filtering capability still has practical value.

**Final approach**: the new-session entry point is only enabled when the Server default is selected. When the user switches to a specific Project, the create button is automatically grayed out and disabled, with an info hint icon next to it that pops up an explanation on tap: to create a session in another directory, you must start OpenCode from the terminal with the target working directory passed on the command line, and then switch back to the Server default on the client to create normally.

**Lesson**: in a multi-Project system, if the underlying API does not yet support specifying the working directory at creation time, the constraint should be applied to the creation entry point at the interaction layer, rather than making a fragile after-the-fact remedy at the data layer; the semantic boundary between "list filtering" and "session creation" must be clearly decoupled, to avoid leaving users with the wrong mental model that "as long as I filter by some Project, I can create sessions here".

---

## 17. Relative Path Normalization Cannot Just "Delete .."; It Must Genuinely Fold

**Scenario**: when viewing deep documents such as `docs/reports/*.md` in the iOS client's Markdown preview, images referenced through relative paths in the text (such as `![x](../assets/foo.png)`) fail to load and display, while the text layout is completely normal.

**Root cause**: `MarkdownImageResolver` first concatenates the document's directory with the relative path into `docs/reports/../assets/foo.png`, and then hands it to `PathNormalizer.resolveWorkspaceRelativePath(...)` for resolution. The original implementation crudely filtered out the `.` and `..` segments in the path instead of folding the path according to standard filesystem semantics, which caused it to be incorrectly resolved as `docs/reports/assets/foo.png`, and a file path that does not exist was requested.

**Final approach**: fix it at two levels separately. The first level refactors `PathNormalizer.normalize()` into a stack-based path-folding algorithm: ordinary path segments are pushed onto the stack in order, `.` is skipped, and `..` pops the top element when the stack is not empty. In this way `docs/reports/../assets/foo.png` folds accurately into `docs/assets/foo.png`, while still effectively preventing path traversal attacks that go beyond the Workspace root. The second level, in the Markdown preview layer of `FileContentView`, no longer relies on `MarkdownUI`'s default network image loader to guess relative paths; instead, `imageBaseURL` and a custom `WorkspaceMarkdownImageProvider` are explicitly injected, and the image data inside the Workspace is uniformly read through `state.loadFileContent` to complete the controlled rendering.

**Lesson**: securing relative paths is by no means solved by simply "stripping dangerous characters". Crude trimming of `..` directly breaks the legitimate hierarchy of relative paths, and easily causes hidden failures in scenarios such as document image rendering, Patch-related navigation, and relative references inside code. Moreover, the default image-loading strategy of third-party Markdown rendering engines usually assumes that what is passed in is a final, usable network URL; to reliably support relative path resources inside the project, the client must take over Base URL maintenance and the custom resource loader itself, and cannot depend on the implicit behavior of the default network loader.

---

## 18. The Streaming reasoning Parser Is a One-Shot State Machine: A Literal End Tag Inside thinking Permanently Ends reasoning Early

**Scenario**: streaming parsers such as SGLang's `--reasoning-parser qwen3` are essentially **one-shot** state machines — during the thinking output stage, as soon as the **first** `</think>` is detected (wherever it appears on the line), the state machine permanently turns off reasoning mode, and every subsequent streaming chunk is passed through as ordinary body text. If the model outputs the literal string `</think>` inside its thinking content (for example while analyzing and discussing that very tag), the thinking stream ends prematurely and unexpectedly, and the remaining unfinished thinking content together with the real `</think>` tag leaks entirely into the body content stream.

**Approach**: when troubleshooting "the thinking process leaking into the body", first read the parser implementation source in the Serving layer, confirm how the state machine works (including whether it is one-way triggered and the exact matching rules for the end tag), and then cross-check against the log data: check whether the reasoning part is forcibly truncated in the middle of a sentence, and whether the text part continues right after the content of the first half of that sentence.

**Lesson**: the tokenizer cannot distinguish at the low level between "discussing a tag as ordinary text" and "a genuine end-of-thinking marker"; such ambiguity can usually only be absorbed in the client's normalization layer. Before starting the troubleshooting, you must first understand the state machine flow of the Serving-layer Parser, to avoid pointless investigation in the server business layer or the model training layer.

---

## 19. Client-Side Normalization Is the Right Layer to Fix Model Output Quirks, and It Must Be fence-aware

**Scenario**: the server usually stores and relays the model's raw output as-is (the extra blank lines and the leaked thinking tags in the output are generation characteristics of the model itself, not server defects); the same data renders correctly on the Web and Android clients after each applies its own display normalization. When one client shows a rendering anomaly, the root cause often lies in that client's missing targeted data normalization logic, rather than in a problem with the server or the model.

**Approach**: uniformly normalize and clean the text parts in the client's view rendering layer (including removing extra leading and trailing whitespace, filtering out whitespace-only chunks, and stripping leaked thinking tags, etc.), and this normalization must be **code-fence aware (fence-aware)** — detect the code fence syntax (``` and ~~~) line by line, and do not clean any tags inside a fence (including the fence marker lines themselves), because the server-side parser is completely unaware of code fences. In addition, the normalization applies only to the text parts of the assistant role, and user messages are strictly kept as-is (to make sure that content discussing tags in user input is unaffected).

**Lesson**: client-side normalization is inherently idempotent (it has no side effect on a well-behaved model), has the smallest blast radius, and can keep behavior consistent with the Web / Android clients. For the output special cases and quirks of all kinds of models, prefer defensive fixes in the client rendering layer, and try not to disturb the server and model chain.

---

## 20. "session-specific vs systemic": Distinguish by Comparing against a Clean session's Statistics

**Scenario**: when diagnosing a defect in some model's output, it is easy to misjudge "a peculiar phenomenon (artifact) that occurs only in a specific session" as "a systemic defect that exists globally in that model" (for example, the think-tag leak encountered in this investigation actually originated only from that session happening to be discussing those very tags, while its frequency in other regular sessions was 0).

**Approach**: select a **clean session** (that is, one that does not involve the specific discussion topic at all and has a sufficient sample size, for example a regular session containing 219 text parts) as the baseline control group, and compare statistical indicators item by item with the problematic session (such as extra leading and trailing newlines, whitespace-only chunks, the proportion of chunks containing a specific tag, etc.). If the anomaly statistics in the baseline session are 0 while the current session is significantly higher, then it is purely a session-specific phenomenon; only when the control group also shows high-frequency anomalies can it be classified as a systemic problem.

**Lesson**: before classifying an issue as a "systemic defect", a baseline control sample that contains no interfering factors must be introduced for quantitative statistics; without a rigorous comparison, the mere impression that "there are a lot of samples" cannot directly lead to the conclusion of a "global systemic" problem.

---

## 21. A Progress Label Must Be Owned by the Operation It Names

**Scenario**: the Settings connection row kept reading "Checking…" next to an already known server version ("OpenCode 2.1.3"). The Check action set a view-local flag and cleared it only after the whole `state.refresh()` returned, but `refresh()` awaits the health check **and then** a dozen workspace loads (sessions, messages, diffs, todos, file tree, file status, status poll). The connection had been proven in the first few hundred milliseconds; the spinner kept asserting the opposite for the whole reload, and forever when one load stalled on a large project over a slow link.

**Anti-pattern**: deriving "is this still working?" from a flag that wraps a *larger* pipeline than the thing the label talks about, and letting a shared phase string double as a live signal that any late writer can strand in a "checking" value. `testConnection()` also published its "checking health" phase *after* awaiting the server, without the host-request guard the rest of the function used, so a check that was superseded mid-flight could leave the *new* host on a phase that never finishes.

**Correct approach**: give the state an explicit in-flight flag owned by the operation itself — raised before the first await and released on every exit path, including early returns — so the label follows the check and not the reload behind it. Scope every shared diagnostic write to the request that produced it, so a superseded check publishes nothing and stamps its phase with the host it was made for. Have the row read only the current host's diagnostic.

**Lesson**: a progress label must be scoped to the operation it names and must have a guaranteed terminal state. The tell-tale sign is a progress label sitting next to a value that only a *completed* operation could have produced — when those two disagree, the label's owner is wrong, not the value.

---

## 22. A Voice Feature That Needs a Credential Is a Voice Feature Most People Never Use

**Scenario**: Ambient Mode — the hands-free car surface — was the only voice feature in
the app that could not be used without setup. It ran on a hosted realtime service and
refused to start until the user pasted an access token into Settings. Dictation, right
next to it, needed no credential at all. The feature was built for a moment when the
user is driving and cannot reach for a keyboard, and it was the one surface that
demanded a keyboard first.

**Anti-pattern**: treating "the platform provides this model" as "the user provides the
credential for it". The hosted service also turned out to be the only part of the app
that uploaded raw audio to somebody else's server, so the token was not just a
configuration step: it was the whole privacy story of the voice feature.

**Correct approach**: ask what the user's own machine already has. The OpenCode server
already holds the model credentials and already answers over an API the app speaks, so
the conversation brain never needed a hosted service — and Apple's Speech framework
recognises and synthesises on the device with no account. The one platform limit worth
knowing: watchOS ships no `Speech.framework` at all, so the watch cannot recognise
locally and its microphone has to travel to the phone over the private
Apple-to-iPhone connection, which is still "on the user's own devices".

**Lesson**: before wiring a feature to a hosted service, check what the user's own
machine already provides — a hosted service adds a credential, a privacy disclosure
and a third-party failure mode, and the local path often needs none of the three.

---

## 23. App Store Connect: A Version in Review Cannot Change Its Build — and the Cancel Route Is Not Where You Expect It

**Scenario**: shipping a new build of an app version that is already in the review
queue. The build has to change (the shipped build is not the one that was reviewed),
but App Store Connect refused every obvious route.

**Anti-pattern**: reaching for `DELETE /v1/reviewSubmissions/{id}` to cancel the
submission. The API answers `403` with "the resource 'reviewSubmissions' does not
allow 'DELETE'. Allowed operations are: CREATE, GET_COLLECTION, GET_INSTANCE,
UPDATE" — the review submission is not deletable at all. The same applies to
`POST /v1/appStoreVersionSubmissions` (403: "does not allow 'CREATE'") and to
`PATCH /v1/appStoreVersions/{id}/relationships/appStoreVersionSubmission` (403: "does
not allow 'UPDATE'").

**Correct approach**: the cancellation route is keyed by the *version*, not by the
submission: `DELETE /v1/appStoreVersionSubmissions/{appStoreVersionId}`. That clears
the version's submission, the version returns to `READY_FOR_REVIEW`, and only then can
the build be swapped (`PATCH /v1/appStoreVersions/{id}/relationships/build`). The
submission itself is then rebuilt in three steps, and every step matters:

1. `POST /v1/reviewSubmissions` with **both** `attributes.platform` (`"IOS"`) and the
   `app` relationship. A submission created without the platform attribute comes back
   with `"platform": null`, and Apple then refuses every later step with "Resource is
   not in submittable state" / "not in updatable state" — and since review submissions
   cannot be deleted, that shell is an orphan for good.
2. `POST /v1/reviewSubmissionItems` with the `reviewSubmission` and the
   `appStoreVersion` relationships. This is what moves the version from
   `PREPARE_FOR_SUBMISSION` to `READY_FOR_REVIEW`.
3. `PATCH /v1/reviewSubmissions/{id}` with `{"attributes": {"submitted": true}}`. This
   is the only step that actually sends the version to App Review: the submission gets
   a `submittedDate` and moves to `WAITING_FOR_REVIEW`.

**Lesson**: the review-submission API is not a CRUD resource — it is a three-step
workflow with a point of no return, and the one attribute that cannot be patched
afterwards (`platform`) has to be set at creation. Measure the whole chain once
(`reviewSubmissions` → `reviewSubmissionItems` → `submitted`) and keep the exact
bodies; a single missing field turns into an orphan that the API refuses to clean
up.
