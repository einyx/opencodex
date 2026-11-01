//
//  FilesTabView.swift
//  OpenCodeClient
//

import SwiftUI

struct FilesTabView: View {
    @Bindable var state: AppState
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.effectiveLayout) private var effectiveLayout

    var body: some View {
        NavigationStack(path: $state.filesNavigationPath) {
            FileTreeView(state: state)
                .fileSearchQueryHandlers(state: state)
                .safeAreaInset(edge: .top, spacing: 0) {
                    VStack(spacing: 0) {
                        FilesProjectMemorySection(state: state)
                        FilesChangesSection(state: state)
                    }
                }
            .navigationTitle(L10n.t(.navFiles))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if sizeClass == .regular, effectiveLayout != .regular {
                    ToolbarItem(placement: .primaryAction) {
                        LayoutPreferenceMenu(state: state)
                    }
                }
            }
        }
        .sheet(item: Binding<AppState.SessionChangesPreview?>(
            get: {
                guard let changes = state.changesPreview, changes.host == .files else { return nil }
                return changes
            },
            set: { newValue, _ in if newValue == nil { state.closeSessionChanges() } }
        )) { changes in
            NavigationStack {
                SessionChangesView(
                    paths: changes.paths,
                    diffs: state.sessionDiffs,
                    scope: .session,
                    workspaceDirectory: changes.workspaceDirectory,
                    onOpenFile: { path in
                        state.closeSessionChanges()
                        state.presentFilesColumnPreview(
                            path: path,
                            workspaceDirectory: changes.workspaceDirectory
                        )
                    },
                    onClose: { state.closeSessionChanges() }
                )
                .navigationTitle(L10n.t(.changesSectionTitle))
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium, .large])
        }
        .onChange(of: state.filesNavigationPath) { oldPath, newPath in
            if newPath.count > oldPath.count, let last = newPath.last {
                state.adoptFilesPush(last)
                return
            }
            if state.ignoreNextFilesPathShrink {
                state.ignoreNextFilesPathShrink = false
                return
            }
            guard effectiveLayout == .compact, newPath.isEmpty, let closed = oldPath.last else { return }
            state.closeMatchingPreview(closed)
        }
    }
}

/// The Files tab's "Changes" section: the files this session changed.
///
/// Per the HIG's File management guidance the tree keeps the shape people
/// know; the session's edits sit above it as a transient section.
private struct FilesChangesSection: View {
    @Bindable var state: AppState
    @Environment(\.colorScheme) private var colorScheme

    private var totals: FileChangeTotals? {
        guard !state.sessionDiffs.isEmpty else { return nil }
        return FileChangeTotals(
            additions: state.sessionDiffs.reduce(0) { $0 + $1.additions },
            deletions: state.sessionDiffs.reduce(0) { $0 + $1.deletions }
        )
    }

    var body: some View {
        if !state.sessionDiffs.isEmpty {
            Button {
                state.presentSessionChanges(
                    host: .files,
                    sessionID: state.currentSessionID,
                    turnUserMessageID: nil,
                    paths: state.sessionDiffs.map(\.file),
                    workspaceDirectory: state.currentSession?.directory
                )
            } label: {
                HStack(spacing: DesignSpacing.sm) {
                    Image(systemName: "doc.text.fill")
                        .foregroundStyle(DesignColors.Brand.primary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.patchFilesChanged(state.sessionDiffs.count))
                            .font(DesignTypography.bodyProminent)
                            .foregroundStyle(DesignColors.Brand.primary)
                        HStack(spacing: 6) {
                            if let totals {
                                Text(L10n.t(.changesAdded, totals.additions))
                                    .foregroundStyle(DesignColors.Brand.primary)
                                Text(L10n.t(.changesDeleted, totals.deletions))
                                    .foregroundStyle(DesignColors.Neutral.textSecondary)
                                Text("·").foregroundStyle(DesignColors.Neutral.textTertiary)
                            }
                            Text(L10n.t(.changesSectionSubtitle))
                                .foregroundStyle(DesignColors.Neutral.textSecondary)
                        }
                        .font(DesignTypography.microMono)
                    }
                    Spacer(minLength: DesignSpacing.sm)
                    Image(systemName: "chevron.right")
                        .font(DesignTypography.micro)
                        .foregroundStyle(DesignColors.Neutral.textTertiary)
                }
                .padding(.horizontal, DesignSpacing.lg)
                .padding(.vertical, DesignSpacing.md)
                .background(DesignColors.Brand.surface(for: colorScheme))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("files-changes-section")
        }
    }
}

/// The Files tab's "Project Memory" section: the instruction file the server injects into
/// every agent turn.
///
/// It is a project artifact, not a transient one, so it stays on screen: the user has to be able
/// to see that their project has memory at all.
private struct FilesProjectMemorySection: View {
    @Bindable var state: AppState
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationLink {
            ProjectMemoryView(state: state)
        } label: {
            HStack(spacing: DesignSpacing.sm) {
                Image(systemName: "brain")
                    .foregroundStyle(DesignColors.Brand.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t(.projectMemoryTitle))
                        .font(DesignTypography.bodyProminent)
                        .foregroundStyle(DesignColors.Brand.primary)
                    Text(subtitle)
                        .font(DesignTypography.microMono)
                        .foregroundStyle(DesignColors.Neutral.textSecondary)
                }
                Spacer(minLength: DesignSpacing.sm)
                Image(systemName: "chevron.right")
                    .font(DesignTypography.micro)
                    .foregroundStyle(DesignColors.Neutral.textTertiary)
            }
            .padding(.horizontal, DesignSpacing.lg)
            .padding(.vertical, DesignSpacing.md)
            .background(DesignColors.Brand.surface(for: colorScheme))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("files-project-memory-section")
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(L10n.t(.projectMemoryTitle)). \(subtitle)")
        .accessibilityHint(L10n.t(.projectMemoryExplains))
        .task { await state.loadProjectMemoryIfNeeded() }
    }

    /// The one-line summary.
    ///
    /// A read in flight keeps the last known summary: flipping to a generic line on every
    /// refresh would make the section flicker for no reason.
    private var subtitle: String {
        let model = state.projectMemory
        switch model.content {
        case .notLoaded, .loading:
            return model.hasLoaded
                ? summary(for: model)
                : L10n.t(.projectMemorySectionSubtitle)
        case .absent:
            return L10n.t(.projectMemoryAbsent)
        case .unreadable:
            return L10n.t(.projectMemorySectionSubtitle)
        case .text(let text):
            return L10n.t(.projectMemoryPresent, L10n.t(.projectMemoryFileName), ProjectMemoryModel.lineCount(of: text))
        }
    }

    private func summary(for model: ProjectMemoryModel) -> String {
        guard let text = model.currentText else { return L10n.t(.projectMemorySectionSubtitle) }
        return L10n.t(.projectMemoryPresent, L10n.t(.projectMemoryFileName), ProjectMemoryModel.lineCount(of: text))
    }
}

extension View {
    func fileSearchQueryHandlers(state: AppState) -> some View {
        modifier(FileSearchQueryModifier(state: state))
    }
}

private struct FileSearchQueryModifier: ViewModifier {
    @Bindable var state: AppState

    func body(content: Content) -> some View {
        if FileSearchFixture.isActive {
            content
                .searchable(
                    text: $state.fileSearchQuery,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: L10n.t(.appSearchFiles)
                )
                .onSubmit(of: .search) {
                    Task { await state.submitFileSearch() }
                }
                .onChange(of: state.fileSearchQuery) { _, newValue in
                    state.fileSearchQueryChanged(newValue)
                }
        } else {
            content
                .searchable(text: $state.fileSearchQuery, prompt: L10n.t(.appSearchFiles))
                .onSubmit(of: .search) {
                    Task { await state.submitFileSearch() }
                }
                .onChange(of: state.fileSearchQuery) { _, newValue in
                    state.fileSearchQueryChanged(newValue)
                }
        }
    }
}
