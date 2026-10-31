# OpenCodex Settings

Approved from the light/dark mockup in `.occlient/settings-preview.html`.

- Warm off-white and charcoal page backgrounds; restrained separators and no oversized card containers.
- OpenCodex identity above a large Settings title. Native navigation and the existing tab bar remain intact.
- Connection: host name and transport, one status/version line, a quiet Check action, then Manage Hosts. No duplicated Connected success block or long host explanation.
- Workspace: Project picker and Models navigation in one group. The picker appears once; custom-path entry remains conditional.
- Preferences: Appearance, Language, Input & Voice, Advanced. Existing voice/input controls move to Input & Voice. Layout, Ambient feature toggle, quota configuration and capability permissions move to Advanced.
- About: OpenCodex version and open-source licenses.
- Checking is progress, not failure: spinner and neutral text for SSH setup, health probing and bootstrap. Only an actual failed phase uses error treatment. Keep recovery hints visible on real failures.
- Settings palette is local to this screen family; do not recolor the rest of the app or modify connection/authentication logic.
- Preserve English/Simplified Chinese, Dynamic Type, VoiceOver labels, existing control identifiers, Settings-to-Models focus behavior and device-specific Ambient availability.

The HTML mockup is a visual reference, not a replacement runtime. The implementation uses native SwiftUI lists, forms, pickers and pushed pages; scrolling, safe areas and the tab bar follow the system.

## Implementation files

- `Views/SettingsTabView.swift`: overview, host check/status, workspace and preferences.
- `Views/SettingsDetailViews.swift`: native Input & Voice and Advanced forms; existing public-key/help sheets remain available to Host Profiles.
- `Views/SettingsStyle.swift`: Settings-only light/dark palette and shared page styling.
- `Models/HostProfile.swift`: diagnostic progress classification; checking is not failure.
- `Views/HostProfilesView.swift`: shared diagnostics use progress styling for in-flight phases, retaining actual failure messages and recovery hints.
- `Support/L10n.swift`: new English/Simplified Chinese navigation labels.

No credentials, host profiles, connection results, microphone lifecycle, or saved preference values are migrated or reset by this UI change.
