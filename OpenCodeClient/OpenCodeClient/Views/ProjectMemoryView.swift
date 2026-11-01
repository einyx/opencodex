//
//  ProjectMemoryView.swift
//  OpenCodeClient
//

import SwiftUI

/// The Project Memory panel: the `AGENTS.md` file the OpenCode server injects into every
/// provider turn, and the action that asks the agent to bring it up to date.
///
/// Spec: docs/features/project_memory/design.md
struct ProjectMemoryView: View {
    @Bindable var state: AppState
    @Environment(\.colorScheme) private var colorScheme

    /// Whether the content area shows the change instead of the file.
    @State private var showingReview = false
    /// The action that was refused, so the panel can say why instead of failing silently.
    @State private var actionError: String?
    /// The diff between the accepted version and the one on the server.
    @State private var diffLines: [DiffLine] = []
    /// The pair the diff was derived from, so it is only recomputed when one of them changes.
    @State private var diffKey: String?

    private var model: ProjectMemoryModel { state.projectMemory }

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .navigationTitle(L10n.t(.projectMemoryTitle))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await reload() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityIdentifier("project-memory-refresh")
            }
        }
        .safeAreaInset(edge: .bottom) { actionBar }
        .task { await load() }
        .onChange(of: model.hasChange) { _, hasChange in
            // The review is only meaningful while there is a change to review.
            if !hasChange { showingReview = false }
        }
        .onChange(of: state.sessionStatuses) { _, _ in
            state.updateProjectMemoryActionState()
            Task { await refreshAfterTurnIfNeeded() }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.sm) {
            Text(L10n.t(.projectMemoryExplains))
                .font(DesignTypography.meta)
                .foregroundStyle(DesignColors.Neutral.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(readPath)
                .font(DesignTypography.microMono)
                .foregroundStyle(DesignColors.Neutral.textTertiary)
                .accessibilityIdentifier("project-memory-path")
            stateBanner
        }
        .padding(.horizontal, DesignSpacing.lg)
        .padding(.vertical, DesignSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignColors.Brand.surface(for: colorScheme))
    }

    /// Where the file was read from.
    ///
    /// The server looks for instructions upward from the session's directory, so the client says
    /// which one file it read rather than implying it is the only instruction the agent sees.
    private var readPath: String {
        guard let directory = model.loadedDirectory, !directory.isEmpty else {
            return "\(ProjectMemoryFile.instructionFileName) · \(L10n.t(.projectMemoryServerDefault))"
        }
        return "\(directory)/\(ProjectMemoryFile.instructionFileName)"
    }

    @ViewBuilder
    private var stateBanner: some View {
        switch model.content {
        case .notLoaded, .loading:
            HStack(spacing: DesignSpacing.sm) {
                ProgressView()
                Text(L10n.t(.projectMemoryLoading))
                    .font(DesignTypography.meta)
                    .foregroundStyle(DesignColors.Neutral.textSecondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("project-memory-loading")

        case .absent:
            Text(L10n.t(.projectMemoryAbsent))
                .font(DesignTypography.bodyProminent)
                .foregroundStyle(DesignColors.Neutral.textSecondary)
                .accessibilityIdentifier("project-memory-absent")

        case .unreadable(let failure):
            Text(L10n.t(.projectMemoryUnreadable, L10n.t(.projectMemoryFileName)))
                .font(DesignTypography.bodyProminent)
                .foregroundStyle(DesignColors.Neutral.textSecondary)
                .accessibilityIdentifier("project-memory-unreadable")
                .accessibilityHint(describe(failure))

        case .text:
            if model.hasChange {
                changeBanner
            } else {
                Text(summaryLine)
                    .font(DesignTypography.meta)
                    .foregroundStyle(DesignColors.Neutral.textTertiary)
                    .accessibilityIdentifier("project-memory-summary")
            }
        }
    }

    private var changeBanner: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.sm) {
            Label {
                Text(changeHeadline)
                    .font(DesignTypography.bodyProminent)
                    .accessibilityIdentifier("project-memory-changed")
            } icon: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(DesignColors.Brand.primary)
            }
            .foregroundStyle(DesignColors.Brand.primary)

            HStack(spacing: DesignSpacing.md) {
                if showingReview {
                    Button(L10n.t(.projectMemoryBackToFile)) { showingReview = false }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("project-memory-back-to-content")
                } else {
                    Button(L10n.t(.projectMemoryReviewTitle)) { showingReview = true }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("project-memory-review")
                }
            }
        }
    }

    private var changeHeadline: String {
        if model.wasDeleted { return L10n.t(.projectMemoryDeleted) }
        if model.wasCreated { return L10n.t(.projectMemoryCreated) }
        return L10n.t(.projectMemoryChanged)
    }

    private var summaryLine: String {
        guard let text = model.currentText else { return L10n.t(.projectMemoryAbsent) }
        return L10n.t(.projectMemoryPresent, L10n.t(.projectMemoryFileName), ProjectMemoryModel.lineCount(of: text))
    }

    private func describe(_ failure: ProjectMemoryFailure) -> String {
        switch failure {
        case .binary:
            return L10n.t(.projectMemoryNotText)
        case .transport(let message):
            return message
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if showingReview, model.hasChange {
            review
        } else {
            fileContent
        }
    }

    @ViewBuilder
    private var fileContent: some View {
        switch model.content {
        case .text(let text):
            if text.isEmpty {
                emptyState(
                    title: L10n.t(.projectMemoryEmptyContent),
                    systemImage: "doc.text",
                    identifier: "project-memory-empty-file"
                )
            } else if MarkdownPreviewView.isTooLargeForMarkdown(text) {
                RawTextView(text: text, monospaced: false, onRefresh: { Task { await reload() } })
            } else {
                MarkdownPreviewView(
                    text: text,
                    state: state,
                    markdownFilePath: ProjectMemoryFile.instructionFileName,
                    workspaceDirectory: model.loadedDirectory
                )
            }
        case .notLoaded, .loading:
            Color.clear
        case .absent:
            emptyState(
                title: L10n.t(.projectMemoryAbsent),
                systemImage: "brain",
                identifier: "project-memory-empty"
            )
        case .unreadable(let failure):
            emptyState(
                title: L10n.t(.projectMemoryUnreadable, L10n.t(.projectMemoryFileName)),
                systemImage: "exclamationmark.triangle",
                identifier: "project-memory-failed"
            )
            .accessibilityHint(describe(failure))
        }
    }

    private func emptyState(title: String, systemImage: String, identifier: String) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier(identifier)
    }

    @ViewBuilder
    private var review: some View {
        ScrollView(.vertical, showsIndicators: true) {
            if model.wasDeleted {
                Text(L10n.t(.projectMemoryDeleted))
                    .font(DesignTypography.body)
                    .foregroundStyle(DesignColors.Neutral.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DesignSpacing.lg)
            } else if model.wasCreated {
                Text(L10n.t(.projectMemoryCreated))
                    .font(DesignTypography.body)
                    .foregroundStyle(DesignColors.Neutral.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DesignSpacing.lg)
            } else if !diffLines.isEmpty {
                DiffLinesView(lines: diffLines)
                    .padding(DesignSpacing.sm)
            } else {
                Text(L10n.t(.changesDiffUnavailable))
                    .font(DesignTypography.body)
                    .foregroundStyle(DesignColors.Neutral.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DesignSpacing.lg)
            }
        }
        .accessibilityIdentifier("project-memory-review-diff")
        .task(id: diffKey) { recomputeDiff() }
    }

    /// The diff between the accepted version and the one on the server.
    ///
    /// The alignment pass is O(n·m), so it is only redone when one of the two texts changes.
    private func recomputeDiff() {
        guard let before = model.baseline?.text, let after = model.currentText, before != after else {
            diffLines = []
            diffKey = nil
            return
        }
        let key = "\(before.hashValue)-\(after.hashValue)"
        guard key != diffKey else { return }
        diffKey = key
        diffLines = DiffLineParser.lines(before: before, after: after)
    }

    // MARK: - Actions

    @ViewBuilder
    private var actionBar: some View {
        VStack(spacing: DesignSpacing.sm) {
            if state.projectMemoryAgentIsWorking {
                HStack(spacing: DesignSpacing.sm) {
                    ProgressView()
                    Text(L10n.t(.projectMemoryWorking))
                        .font(DesignTypography.meta)
                        .foregroundStyle(DesignColors.Neutral.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("project-memory-working")
            }

            if let actionError {
                Text(actionError)
                    .font(DesignTypography.meta)
                    .foregroundStyle(DesignColors.Neutral.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("project-memory-error")
            }

            if model.hasChange, model.baseline?.text != nil {
                Text(L10n.t(.projectMemoryRestoreNote))
                    .font(DesignTypography.micro)
                    .foregroundStyle(DesignColors.Neutral.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Three long labels do not fit on one row on a phone, and a squeezed row reads as
            // a broken button. The row is used when it fits; otherwise the actions stack.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: DesignSpacing.md) { actionButtons }
                VStack(alignment: .leading, spacing: DesignSpacing.sm) { actionButtons }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, DesignSpacing.lg)
        .padding(.vertical, DesignSpacing.md)
        .background(DesignColors.Brand.surface(for: colorScheme))
    }

    @ViewBuilder
    private var actionButtons: some View {
        Button {
            Task { await improve() }
        } label: {
            Text(model.pendingAction
                ? L10n.t(.projectMemoryImproveBusy)
                : L10n.t(.projectMemoryImprove))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!state.canRunProjectMemoryAction)
        .accessibilityIdentifier("project-memory-improve")

        if model.hasChange, model.baseline?.text != nil {
            Button {
                state.acceptProjectMemoryChange()
            } label: {
                Text(L10n.t(.projectMemoryKeep))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("project-memory-keep")

            Button {
                Task { await restore() }
            } label: {
                Text(L10n.t(.projectMemoryRestore))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .buttonStyle(.bordered)
            .disabled(!state.canRunProjectMemoryAction)
            .accessibilityIdentifier("project-memory-restore")
        }
    }

    // MARK: - Actions

    private func load() async {
        await state.loadProjectMemory()
    }

    /// Re-read the file without touching the baseline: the user asked for the current state,
    /// not for the pending change to be forgotten.
    private func reload() async {
        await state.loadProjectMemory()
    }

    /// Re-read once the turn settles.
    ///
    /// The write signal only fires for tools the classifier recognises. A file written any other
    /// way would leave the panel showing a stale version, so the end of the turn is the second
    /// chance to pick the change up.
    private func refreshAfterTurnIfNeeded() async {
        guard state.projectMemory.hasLoaded else { return }
        guard !state.projectMemoryAgentIsWorking else { return }
        await state.loadProjectMemory()
    }

    private func improve() async {
        actionError = nil
        let sent = await state.improveProjectMemory()
        guard sent else {
            actionError = state.sendError ?? L10n.t(.projectMemoryActionFailed)
            return
        }
        showingReview = false
    }

    private func restore() async {
        actionError = nil
        let sent = await state.restoreProjectMemory()
        guard sent else {
            actionError = state.sendError ?? L10n.t(.projectMemoryActionFailed)
            return
        }
        showingReview = false
    }
}
