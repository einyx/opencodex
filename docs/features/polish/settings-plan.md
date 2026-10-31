# OpenCodex Settings refresh

**Approved design:** `.occlient/settings-preview.html` (light/dark concept approved in chat).

**Goal:** implement the preview's warm, borderless Settings layout, eliminate repeated connection feedback, and distinguish checking from failure.

**Scope:** Settings only. Existing host, workspace, model, voice, capability and advanced functionality remains accessible. No transport, credential, signing, tab-bar or server changes.

## Implementation

- [x] Add Settings navigation coverage before implementation. Initial UI execution was blocked by simulator AX initialization; diagnostic tests first failed to compile against the missing progress-classification API.
- [x] Add Settings-scoped semantic palette tokens; retain system typography for Dynamic Type.
- [x] Reorganize Settings into Connection, Workspace, Preferences and About. Show one connection-status row and a neutral Check action; do not repeat a successful diagnostic.
- [x] Move existing input/voice controls and advanced configuration into native pushed pages, preserving their bindings and accessibility identifiers.
- [x] Classify diagnostic progress phases separately from failure; test all phases. Keep real failures actionable.
- [x] Localize new labels in English and Simplified Chinese.
- [x] Run unit tests and focused Settings UI tests sequentially, then inspect simulator screenshots in both themes. No automatic commit or deployment. See the UI runner caveat below.

## Review focus

- Large Dynamic Type: labels and status/version wrap rather than collide.
- No configured host: Manage Hosts remains available; Check is disabled.
- Connection checking: no red text or warning triangle until a real failure.
- Preferences and voice: moving a control must not reset its stored value or alter microphone ownership.
- Existing Settings deep-link to Models must still scroll to and highlight that row.

## Verification record

- `ConnectionPresentationTests`: 2 tests passed (all progress phases classified separately from failure).
- First Settings UI attempt: simulator accessibility initialization timed out before executing assertions. The repo's pinned simulator was rebooted.
- Isolated Settings verification: 2 UI tests passed, including Input & Voice / Advanced navigation and light/dark native captures. A temporary worktree was needed because unrelated capability edits were being written in the main workspace. The worktree used the original permission-summary expression; the main tree retains the capability task's host-scoped summary integration.
- Native screenshot inspection found a stale data-loading error below Connected, and a low-contrast menu value after a theme change. The connection fallback error is now restricted to disconnected hosts without a diagnostic; menu values have explicit theme-aware tint.
- Main-tree full unit run: 1,089 passed, 1 failed because `CarLiveToolsTests.partialArchiveResultStaysWithinFunctionOutputLimit()` was killed. This is not recorded as a passing suite.
- Main-tree Settings UI: both tests passed their assertions (including Connected without the stale error and Input & Voice / Advanced navigation); the runner then stalled during result-bundle finalization and was stopped at the configured 180-second limit. This is not recorded as a clean runner pass.
- Final native light/dark screenshots were captured directly from a second simulator using the existing offline Host Profiles fixture and inspected. Paths: `.occlient/settings-final-light.png` and `.occlient/settings-final-dark.png` (not committed).
- The archive-tool suite was retried by suite name: 36 tests passed, including the earlier killed test. A method-name-only filter first selected no tests and is not counted as a pass.
- Final full unit suite: **1,090 tests / 111 suites passed**, exit 0, parsed Passed result bundle: `.occlient/test-runs/unit-20261025T203411Z-zHqvc9/test.xcresult`.
