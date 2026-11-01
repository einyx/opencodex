//
//  MessageRowView.swift
//  OpenCodeClient
//

import SwiftUI
import MarkdownUI
import UIKit

struct MessageRowView: View {
    private static let markdownRenderCharacterLimit = 12_000
    /// A long message is still shown in full: only the Markdown rendering is
    /// skipped, because MarkdownUI freezes on very large content. The cut is
    /// only a last resort for a pathologically long payload.
    private static let largeMessagePreviewCharacterLimit = 500_000

    @Bindable var state: AppState
    let message: MessageWithParts
    var turnMessages: [MessageWithParts]? = nil
    let sessionTodos: [TodoItem]
    let workspaceDirectory: String?
    let onOpenResolvedPath: (String) -> Void
    let onOpenMarkdownResolvedPath: (String) -> Void
    let onOpenFilesTab: () -> Void
    let onForkFromMessage: ((String) -> Void)?
    let onEditFromMessage: ((String) -> Void)?
    @Environment(\.effectiveLayout) private var effectiveLayout
    @Environment(\.colorScheme) private var colorScheme
    @State private var showsTextSelection = false
    /// The messages whose reasoning the reader opened by hand.
    ///
    /// The thinking pill and the thinking card are two views for one piece of
    /// reasoning, so the choice to keep it open cannot live in either of them.
    @State private var openedThinkingMessageIDs: Set<String> = []

    // iPhone packs file-operation cards two-up to keep information density
    // high; iPad has room for a 3-up grid. Thinking and tool-call tiles are
    // not part of that grid — they take a full-width row of their own.
    private var cardGridColumnCount: Int { effectiveLayout == .regular ? 3 : 2 }

    /// Assistant footer line: "provider/model", then the general (persisted)
    /// throughput when present, then the best-effort SSE-derived "decoding"
    /// throughput when the client observed the live stream for this step. Each
    /// optional segment is omitted when nil, so a message loaded purely from REST
    /// (no SSE) shows only the model plus general throughput.
    ///
    /// The general segment excludes the step's tool wall-clock: the step window
    /// (`created` -> `completed`) contains tool execution on both server
    /// lineages, which otherwise collapses a 2000-token write call whose tool
    /// ran 48s into single-digit t/s.
    private static func modelFooter(model: Message.ModelInfo, general: String?, decode: String?) -> String {
        var parts: [String] = ["\(model.providerID)/\(model.modelID)"]
        if let general { parts.append(general) }
        if let decode { parts.append(decode) }
        return parts.joined(separator: " | ")
    }

    /// Compact token count for the session status line: raw value below 1000,
    /// then K/M/B/T with one decimal at >= 10 and two below, trailing zeros
    /// stripped: 950, 85.2K, 1.11M, 2B. Mirrors the Android formatter.
    nonisolated static func compactTokenCount(_ value: Int) -> String {
        guard value > 0 else { return "0" }
        if value < 1_000 { return String(value) }
        var scaled: Double
        var suffix: String
        if value >= 1_000_000_000_000 {
            scaled = Double(value) / 1_000_000_000_000
            suffix = "T"
        } else if value >= 1_000_000_000 {
            scaled = Double(value) / 1_000_000_000
            suffix = "B"
        } else if value >= 1_000_000 {
            scaled = Double(value) / 1_000_000
            suffix = "M"
        } else {
            scaled = Double(value) / 1_000
            suffix = "K"
        }
        var decimals = scaled >= 10 ? 1 : 2
        // Carry into the next unit when rounding overflows (999_999 -> 1M).
        let factor = decimals == 1 ? 10.0 : 100.0
        if suffix != "T", (scaled * factor).rounded() / factor >= 1000 {
            scaled /= 1000
            switch suffix {
            case "K": suffix = "M"
            case "M": suffix = "B"
            default: suffix = "T"
            }
            decimals = 2
        }
        var text = String(format: "%.\(decimals)f", scaled)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text + suffix
    }

    enum AssistantBlock: Identifiable {
        case text(Part)
        case thinking(Part)
        case cards([Part])
        case attachment(Part)

        var id: String {
            switch self {
            case .text(let p):
                return "text-\(p.id)"
            case .thinking(let p):
                return "thinking-\(p.id)"
            case .cards(let parts):
                let first = parts.first?.id ?? "nil"
                let last = parts.last?.id ?? "nil"
                return "cards-\(first)-\(last)"
            case .attachment(let part):
                return "attachment-\(part.id)"
            }
        }
    }

    /// One cell of the assistant card grid. Every process tile (thinking,
    /// merged non-file tool calls, file-operation cards) is produced in part
    /// order; the row layout below decides which of them share a grid row.
    enum CardGridTile: Identifiable {
        case thinking(Part)
        /// The thinking pill shown while the model is thinking but has not
        /// produced reasoning yet. The indicator has to be live while the
        /// thinking happens, not only once the reasoning has landed.
        case thinkingPlaceholder
        case fileCard(Part)
        case toolCall(Part)
        /// The "N files changed" card.
        case changes(Part)

        var id: String {
            switch self {
            case .thinking(let part):
                return "tile-thinking-\(part.id)"
            case .thinkingPlaceholder:
                return "tile-thinking-placeholder"
            case .fileCard(let part):
                return "tile-file-\(part.id)"
            case .toolCall(let part):
                return "tile-toolcall-\(part.id)"
            case .changes(let part):
                return "tile-changes-\(part.id)"
            }
        }

        /// Whether this tile carries the model's thinking.
        var isThinking: Bool {
            switch self {
            case .thinking, .thinkingPlaceholder:
                return true
            case .fileCard, .toolCall, .changes:
                return false
            }
        }
    }

    /// A rendered row of process tiles. File cards share a grid row (2-up on
    /// iPhone, 3-up on iPad); a thinking or tool-call tile always occupies a
    /// full-width row, because a tool command wrapped into a half-width tile
    /// is unreadable.
    struct ProcessTileRow: Identifiable {
        let id: String
        let tiles: [CardGridTile]
        let isFullWidth: Bool
    }

    static func processTileRows(for tiles: [CardGridTile], columnCount: Int) -> [ProcessTileRow] {
        var rows: [ProcessTileRow] = []
        var pending: [CardGridTile] = []

        func flushPending() {
            guard !pending.isEmpty else { return }
            rows.append(ProcessTileRow(id: "row-\(pending[0].id)", tiles: pending, isFullWidth: false))
            pending.removeAll()
        }

        for tile in tiles {
            switch tile {
            case .fileCard:
                pending.append(tile)
                if pending.count == columnCount { flushPending() }
            case .thinking, .thinkingPlaceholder, .toolCall, .changes:
                flushPending()
                rows.append(ProcessTileRow(id: "row-\(tile.id)", tiles: [tile], isFullWidth: true))
            }
        }
        flushPending()
        return rows
    }

    // A "file operation" is a patch part, or a tool whose name matches one of the
    // file-op verbs (loose prefix match so aliases like "edit"/"write"/"read"/"patch"
    // and full forms like "edit_file"/"apply_patch" all count). These render as
    // file cards in the grid; everything else collapses into "N tool calls".
    // Classification lives in ToolCardClassifier so it can be unit-tested.
    private func isFileOperation(_ part: Part) -> Bool {
        ToolCardClassifier.isFileOperation(part)
    }

    /// Splits the assistant parts into blocks.
    ///
    /// `keepingEmptyReasoningOf` names the message whose reasoning parts are
    /// kept even while they carry no text: that is the step the model is
    /// still thinking in, and its reasoning part is the slot the thinking
    /// pill holds until the words arrive. A finished step drops the empty
    /// part instead — there is nothing to show for it.
    static func buildAssistantBlocks(
        parts: [Part],
        keepingEmptyReasoningOf messageID: String? = nil
    ) -> [AssistantBlock] {
        var blocks: [AssistantBlock] = []
        var buffer: [Part] = []

        func flushBuffer() {
            guard !buffer.isEmpty else { return }
            blocks.append(.cards(buffer))
            buffer.removeAll(keepingCapacity: true)
        }

        for part in parts {
            if part.isReasoning {
                if normalizedText(part.text).isEmpty {
                    guard let messageID, part.messageID == messageID else { continue }
                    flushBuffer()
                    blocks.append(.thinking(part))
                    continue
                }
                flushBuffer()
                blocks.append(.thinking(part))
                continue
            }
            if part.isTool || part.isPatch {
                buffer.append(part)
                continue
            }
            if part.isStepStart || part.isStepFinish { continue }
            if part.isText {
                if normalizedText(part.text).isEmpty { continue }
                flushBuffer()
                blocks.append(.text(part))
            } else if part.isFile {
                flushBuffer()
                blocks.append(.attachment(part))
            } else {
                flushBuffer()
            }
        }

        flushBuffer()
        return blocks
    }

    private var turnPresentation: AssistantTurnPresentation {
        AssistantTurnPresentation(messages: turnMessages ?? [message])
    }

    private struct AssistantLayout {
        let tiles: [CardGridTile]
        let contents: [AssistantBlock]
    }

    static func cardGridTiles(
        for parts: [Part],
        keepingEmptyReasoningOf messageID: String? = nil
    ) -> [CardGridTile] {
        var tiles: [CardGridTile] = []
        for block in buildAssistantBlocks(parts: parts, keepingEmptyReasoningOf: messageID) {
            switch block {
            case .thinking(let part):
                tiles.append(.thinking(part))
            case .cards(let cardParts):
                let split = ToolCardClassifier.split(cardParts)
                for filePart in split.fileParts {
                    tiles.append(.fileCard(filePart))
                }
                // Every remaining tool call gets its own row: a merged
                // "N tool calls" tile stacked a group disclosure on top of
                // each card's own disclosure.
                for otherPart in split.otherParts {
                    tiles.append(.toolCall(otherPart))
                }
                for changePart in split.changeParts {
                    tiles.append(.changes(changePart))
                }
            case .text, .attachment:
                break
            }
        }
        return tiles
    }

    /// Splits the assistant blocks into grid tiles (process tiles plus file
    /// cards, in part order) and full-width content blocks (text /
    /// attachments), which render after the grid.
    private func assistantLayout(for parts: [Part]) -> AssistantLayout {
        // The pill has to be up while the model thinks, not only once the
        // reasoning lands. Without it the transcript sits empty for the
        // whole first step of a turn and the agent looks idle.
        //
        // The running step's empty reasoning part is kept, so the pill holds
        // the very slot the reasoning will fill: it never jumps when the
        // words arrive.
        let runningStep = turnPresentation.messages.last
        let pendingReasoning = isTurnRunning ? runningStep?.info.id : nil
        let blocks = Self.buildAssistantBlocks(parts: parts, keepingEmptyReasoningOf: pendingReasoning)
        var tiles = Self.cardGridTiles(for: parts, keepingEmptyReasoningOf: pendingReasoning)
        // A step whose reasoning part has not arrived at all has no slot to
        // hold: the pill stands in at the end, where that part will land.
        let runningStepParts = runningStep?.parts ?? []
        if !tiles.contains(where: \.isThinking),
           Self.showsThinkingPlaceholder(parts: runningStepParts, isTurnRunning: isTurnRunning) {
            tiles.append(.thinkingPlaceholder)
        }
        return AssistantLayout(
            tiles: tiles,
            contents: blocks.compactMap { block in
                switch block {
                case .text, .attachment:
                    return block
                case .thinking, .cards:
                    return nil
                }
            }
        )
    }

    @ViewBuilder
    /// Renders a text part.
    ///
    /// While the turn is still streaming, the text is rendered plain. A
    /// Markdown parse re-reads the whole message, so on a phone every token
    /// meant a full re-parse of the paragraph so far — the text only appeared
    /// in chunks, when the parse had caught up. Plain text updates per token
    /// and the Markdown takes over when the turn completes.
    private func markdownText(
        _ text: String,
        isUser: Bool,
        forcingMarkdown: Bool = false,
        isStreaming: Bool = false
    ) -> some View {
        let trimmed = isUser
            ? text.trimmingCharacters(in: .whitespacesAndNewlines)
            : Self.normalizedText(text)
        let font = isUser ? DesignTypography.bodyProminent : DesignTypography.body
        let style = isStreaming
            ? TextRenderStyle.plain
            : Self.renderStyle(for: trimmed, forcingMarkdown: forcingMarkdown)
        if trimmed.isEmpty {
            EmptyView()
        } else if style == .largePreview {
            LargeMessagePreview(text: trimmed, preview: Self.largeMessagePreview(trimmed))
                .font(font)
                .textSelection(.enabled)
        } else if style == .markdown {
            ResolvedMarkdownView(
                text: trimmed,
                state: state,
                workspaceDirectory: workspaceDirectory,
                handlesWorkspaceLinks: !isUser,
                onOpenResolvedPath: onOpenMarkdownResolvedPath
            )
                .font(font)
                .textSelection(.enabled)
        } else {
            Text(trimmed)
                .font(font)
                .textSelection(.enabled)
        }
    }

    private struct ResolvedMarkdownView: View {
        let text: String
        let state: AppState
        let workspaceDirectory: String?
        let handlesWorkspaceLinks: Bool
        let onOpenResolvedPath: (String) -> Void
        @Environment(\.openURL) private var openURL
        @State private var resolvedText: String?
        
        var body: some View {
            Markdown(resolvedText ?? text)
                .markdownImageProvider(
                    WorkspaceMarkdownImageProvider(
                        loadFileContent: { pathBytes in try await state.loadFileContent(pathBytes: pathBytes, workspaceDirectory: workspaceDirectory) },
                        workspaceDirectory: workspaceDirectory
                    )
                )
                .environment(\.openURL, OpenURLAction { url in
                    if OpenCodeDeepLinkParser.handles(url) {
                        state.receiveDeepLink(url)
                        return .handled
                    }
                    guard handlesWorkspaceLinks else {
                        openURL(url)
                        return .handled
                    }
                    switch WorkspaceLinkResolver.resolve(url.absoluteString, workspaceDirectory: workspaceDirectory) {
                    case .external(let externalURL):
                        openURL(externalURL)
                        return .handled
                    case .file(let path):
                        onOpenResolvedPath(path)
                        return .handled
                    case .fragmentOnly:
                        return .handled
                    case .rejected(let reason):
                        state.sendError = reason
                        return .discarded
                    }
                })
                .task(id: text) {
                    resolvedText = nil
                    let sourceText = text
                    // A streamed message changes on every delta, and resolving an
                    // image reference fetches the file over the network. Let the
                    // text settle so the resolution happens once instead of
                    // once per token.
                    try? await Task.sleep(for: .milliseconds(250))
                    guard !Task.isCancelled, sourceText == text else { return }
                    let resolved = await MarkdownImageResolver.resolveImages(
                        in: sourceText,
                        workspaceDirectory: workspaceDirectory,
                        fetchContent: { path in try await state.loadFileContent(path: path, workspaceDirectory: workspaceDirectory) }
                    )
                    guard !Task.isCancelled, sourceText == text else { return }
                    resolvedText = resolved
            }
        }
    }

    private func shouldRenderMarkdown(_ text: String) -> Bool {
        Self.hasMarkdownSyntax(text)
    }

    nonisolated enum TextRenderStyle {
        case markdown
        case plain
        case largePreview
    }

    /// Thinking cards force markdown rendering regardless of length (parity with
    /// Android ReasoningCard). Regular text parts keep the >12k plain preview.
    static func renderStyle(for trimmedText: String, forcingMarkdown: Bool) -> TextRenderStyle {
        guard !trimmedText.isEmpty else { return .plain }
        if forcingMarkdown {
            // MarkdownUI freezes on very long or long-lined content, and a
            // thinking block is server-supplied text of any size.
            return MarkdownPreviewView.isTooLargeForMarkdown(trimmedText) ? .plain : .markdown
        }
        if isLargeMessage(trimmedText) { return .largePreview }
        return hasMarkdownSyntax(trimmedText) ? .markdown : .plain
    }

    static func isLargeMessage(_ text: String) -> Bool {
        text.count > markdownRenderCharacterLimit
    }

    static func largeMessagePreview(_ text: String) -> String {
        if text.count <= largeMessagePreviewCharacterLimit { return text }
        return String(text.prefix(largeMessagePreviewCharacterLimit))
    }

    /// Whether the preview had to cut the message.
    static func largeMessageIsTruncated(_ text: String) -> Bool {
        text.count > largeMessagePreviewCharacterLimit
    }

    static func hasMarkdownSyntax(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let markdownSignals = [
            "```", "`", "**", "__", "#", "- ", "* ", "+ ", "1. ",
            "[", "](", "> ", "|", "~~"
        ]
        if markdownSignals.contains(where: { trimmed.contains($0) }) {
            return true
        }

        return trimmed.contains("\n\n")
    }

    static func isRenderableText(_ text: String?) -> Bool {
        guard let text else { return false }
        return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // qwen3-family reasoning delimiters. Built from unicode escapes so tooling
    // that strips reasoning spans from source files cannot mangle the literals.
    static let thinkOpenTag = "\u{3C}think\u{3E}"
    static let thinkCloseTag = "\u{3C}/think\u{3E}"

    /// Normalizes an assistant text part by removing leaked thinking content.
    /// See docs/archive/2026-08_qwen38_rendering_fix.md (batch 2). Never apply to user text —
    /// users may legitimately quote the tags.
    ///
    /// SGLang's one-shot qwen3 reasoning parser ends reasoning at the FIRST
    /// think-close token it sees, anywhere (inline included, zero code-fence
    /// awareness). When the model's own thinking quotes the tag, the remaining
    /// thinking plus the real close token flow into the text part. The real
    /// closing boundary is therefore the LAST standalone-line close token;
    /// everything up to and including it is a leaked thinking tail and is cut.
    /// A dangling standalone open line (stream truncated before the close) cuts
    /// the rest of the part. Tags inside code fences and inline (mid-line) tags
    /// are left untouched.
    static func normalizedText(_ text: String?) -> String {
        guard let text, !text.isEmpty else { return "" }
        let lines = text.components(separatedBy: "\n")

        // Pass 1: fence tracking. A fence opens on a line whose trimmed content
        // starts with ``` or ~~~ (up to 3 leading spaces; the opening line may
        // carry an info string) and closes only on a line made purely of the
        // same fence character, at least as long as the opener. Lines inside a
        // fence (including the fence lines) are never tag boundaries.
        var protectedLines = [Bool](repeating: false, count: lines.count)
        var inFence = false
        var fenceChar: Character = " "
        var fenceLength = 3
        for index in lines.indices {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            if inFence {
                protectedLines[index] = true
                let pureFence = !trimmed.isEmpty
                    && trimmed.count >= fenceLength
                    && trimmed.allSatisfy { $0 == fenceChar }
                if pureFence { inFence = false }
            } else if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                let char = trimmed[trimmed.startIndex]
                let run = trimmed.prefix { $0 == char }.count
                guard run >= 3 else { continue }
                inFence = true
                fenceChar = char
                fenceLength = run
                protectedLines[index] = true
            }
        }

        func isStandaloneTag(_ index: Int, _ tag: String) -> Bool {
            !protectedLines[index]
                && lines[index].trimmingCharacters(in: .whitespaces) == tag
        }

        // Pass 2: leaked thinking tail — cut everything up to and including
        // the last standalone close line. A real response, if any, follows it.
        var keptStart = 0
        for index in lines.indices.reversed() where isStandaloneTag(index, Self.thinkCloseTag) {
            keptStart = index + 1
            break
        }

        // Pass 3: dangling standalone open in the remainder (stream truncated
        // before the close) — cut from that line to the end.
        var keptEnd = lines.count
        for index in keptStart..<lines.count where isStandaloneTag(index, Self.thinkOpenTag) {
            keptEnd = index
            break
        }

        return lines[keptStart..<keptEnd]
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func structuredSpeechFallback(for message: MessageWithParts) -> String? {
        guard !message.parts.contains(where: { $0.isText }) else { return nil }
        return message.info.carResponseEnvelope?.speech
    }

    nonisolated static func taskNotification(for part: Part) -> TaskNotification? {
        guard part.isSyntheticText, let text = part.text else { return nil }
        return TaskNotificationParser.parse(text)
    }

    static func taskNotification(in message: MessageWithParts) -> TaskNotification? {
        message.parts.compactMap(taskNotification(for:)).first
    }

    static func showsEditFromHere(_ message: MessageWithParts) -> Bool {
        message.info.isUser && taskNotification(in: message) == nil
    }

    static func taskNotificationAccessibilityIdentifier(for message: MessageWithParts) -> String? {
        guard taskNotification(in: message) != nil else { return nil }
        return TaskNotificationParser.cardAccessibilityIdentifier
    }

    static func copyableText(for message: MessageWithParts) -> String {
        let isAssistant = message.info.isAssistant
        let text = message.parts
            .filter(\.isText)
            .compactMap { part -> String? in
                if let notification = taskNotification(for: part) {
                    let result = notification.resultText.trimmingCharacters(in: .whitespacesAndNewlines)
                    return result.isEmpty ? nil : result
                }
                let normalized = isAssistant
                    ? normalizedText(part.text)
                    : (part.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                return normalized.isEmpty ? nil : normalized
            }
            .joined(separator: "\n\n")
        if !text.isEmpty { return text }
        return structuredSpeechFallback(for: message) ?? ""
    }

    static func selectionText(from markdown: String) -> String {
        var insideCodeFence = false
        return markdown
            .split(separator: "\n", omittingEmptySubsequences: false)
            .compactMap { substring -> String? in
                let line = String(substring)
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                    insideCodeFence.toggle()
                    return nil
                }
                if insideCodeFence { return line }

                var content = line
                let leadingWhitespace = content.prefix { $0 == " " || $0 == "\t" }
                var body = content.dropFirst(leadingWhitespace.count)
                if let markerEnd = body.firstIndex(where: { $0 != "#" }),
                   markerEnd != body.startIndex,
                   body.distance(from: body.startIndex, to: markerEnd) <= 6,
                   body[markerEnd] == " " {
                    body = body[body.index(after: markerEnd)...]
                    content = String(leadingWhitespace) + String(body)
                } else if body.hasPrefix("> ") {
                    content = String(leadingWhitespace) + String(body.dropFirst(2))
                }

                guard let inline = try? AttributedString(
                    markdown: content,
                    options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
                ) else { return content }
                return String(inline.characters)
            }
            .joined(separator: "\n")
    }

    private var copyableText: String {
        if message.info.isUser {
            return Self.copyableText(for: message)
        }
        return turnPresentation.copyableText
    }

    private var messageActionsMenu: some View {
        Menu {
            Button {
                showsTextSelection = true
            } label: {
                Label(L10n.t(.chatSelectText), systemImage: "text.viewfinder")
            }

            Button {
                UIPasteboard.general.string = copyableText
            } label: {
                Label(L10n.t(.chatCopyMessage), systemImage: "doc.on.doc")
            }

            if Self.showsEditFromHere(message), let onEditFromMessage {
                Button {
                    onEditFromMessage(message.info.id)
                } label: {
                    Label(L10n.t(.chatEditFromHere), systemImage: "pencil")
                }
                .disabled(state.isBusy)
            }

            if let onForkFromMessage {
                Button {
                    onForkFromMessage(message.info.id)
                } label: {
                    Label(L10n.t(.chatForkFromHere), systemImage: "arrow.triangle.branch")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityIdentifier("message-actions")
    }

    private struct LargeMessagePreview: View {
        let text: String
        let preview: String
        var isTruncated: Bool { MessageRowView.largeMessageIsTruncated(text) }

        var body: some View {
            VStack(alignment: .leading, spacing: DesignSpacing.sm) {
                Text(preview)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(
                    isTruncated
                        ? L10n.t(.chatLargeMessageTruncatedNotice, preview.count.formatted(), text.count.formatted())
                        : L10n.t(.chatLargeMessagePreviewNotice, text.count.formatted())
                )
                    .font(DesignTypography.micro)
                    .foregroundStyle(.secondary)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if message.info.isUser {
                userMessageView
            } else {
                assistantMessageView
            }
        }
        .sheet(isPresented: $showsTextSelection) {
            MessageTextSelectionSheet(text: copyableText)
        }
    }

    private var taskNotificationParts: [(id: String, notification: TaskNotification)] {
        message.parts.compactMap { part in
            guard let notification = Self.taskNotification(for: part) else { return nil }
            return (part.id, notification)
        }
    }

    private var bubbleTextParts: [Part] {
        message.parts.filter { part in
            part.isText && Self.isRenderableText(part.text) && Self.taskNotification(for: part) == nil
        }
    }

    private var userMessageView: some View {
        let notifications = taskNotificationParts
        let bubbleParts = bubbleTextParts
        let attachments = message.parts.filter(\.isFile)
        return VStack(alignment: .leading, spacing: 6) {
            ForEach(notifications, id: \.id) { item in
                TaskNotificationCardView(notification: item.notification) {
                    Task { await state.openReferencedSession(sessionID: item.notification.sessionID) }
                } result: {
                    markdownText(item.notification.resultText, isUser: false)
                }
            }

            if !bubbleParts.isEmpty || !attachments.isEmpty {
                // Claude-style bubble: right-aligned, capped width, one
                // rounded corner tucked in. The old accent stripe read as a
                // system event rather than as something the person said.
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(bubbleParts, id: \.id) { part in
                            markdownText(part.text ?? "", isUser: true)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                        }
                        if !attachments.isEmpty {
                            MessageAttachmentsGrid(parts: attachments)
                                .padding(.horizontal, 14)
                                .padding(.bottom, 10)
                        }
                    }
                    .frame(maxWidth: DesignControls.userBubbleMaxWidth, alignment: .leading)
                    .background(
                        DesignColors.Neutral.text.opacity(DesignColors.surfaceFill(for: colorScheme))
                    )
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 20,
                            bottomLeadingRadius: 20,
                            bottomTrailingRadius: 6,
                            topTrailingRadius: 20
                        )
                    )
                }
            }

            // Inline send-failure banner (async session.error or failed HTTP
            // send): subtle, non-modal, attached to the affected row. The row's
            // text stays available for copy & manual resend.
            if let failureReason = state.messageStore.failedSendReasonsByID[message.info.id] {
                Text(failureReason)
                    .font(.caption)
                    .foregroundStyle(DesignColors.Semantic.error)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DesignColors.Semantic.error.opacity(DesignColors.surfaceFill(for: colorScheme)))
                    .clipShape(RoundedRectangle(cornerRadius: DesignCorners.medium))
                    .textSelection(.enabled)
            }

            HStack {
                // User messages don't carry a model line — the model belongs to
                // the assistant's reply, not to what the human said.
                Spacer()
                if !copyableText.isEmpty { messageActionsMenu }
            }
            .padding(.leading, 4)
        }
        .overlay(alignment: .topLeading) {
            Text(verbatim: userSendStatus)
                .font(.system(size: 1))
                .frame(width: 1, height: 1)
                .foregroundStyle(.primary.opacity(0.01))
                .allowsHitTesting(false)
                .accessibilityIdentifier("user-message-\(message.info.id)")
                .accessibilityAddTraits(.updatesFrequently)
        }
    }

    private var userSendStatus: String {
        if state.messageStore.failedSendReasonsByID[message.info.id] != nil {
            return "failed"
        }
        if state.messageStore.isPendingOptimisticMessage(message.info.id) {
            return "pending"
        }
        return "confirmed"
    }

    private var assistantMessageView: some View {
        let presentation = turnPresentation
        let copyable = presentation.copyableText
        return VStack(alignment: .leading, spacing: 6) {
            // No "OpenCode" speaker title — the user's blue left-bar vs the
            // assistant's container-less reply already make it clear who's
            // speaking, so an extra blue label is redundant.
            ForEach(presentation.speeches, id: \.messageID) { speech in
                markdownText(speech.text, isUser: false)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("structured-assistant-speech")
            }

            let layout = assistantLayout(for: presentation.parts)

            // File cards keep the 2-up (iPhone) / 3-up (iPad) grid. Thinking and
            // tool-call tiles get a full-width row each, in part order.
            if !layout.tiles.isEmpty {
                VStack(alignment: .leading, spacing: DesignSpacing.sm) {
                    ForEach(Self.processTileRows(for: layout.tiles, columnCount: cardGridColumnCount)) { row in
                        if row.isFullWidth {
                            tileView(row.tiles[0])
                        } else {
                            HStack(alignment: .top, spacing: DesignSpacing.sm) {
                                ForEach(row.tiles) { tile in
                                    tileView(tile)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                if row.tiles.count < cardGridColumnCount {
                                    Color.clear.frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }
                }
            }

            ForEach(layout.contents) { block in
                switch block {
                case .text(let part):
                    markdownText(part.text ?? "", isUser: false, isStreaming: isPartStreaming(part))
                        .frame(maxWidth: .infinity, alignment: .leading)
                case .attachment(let part):
                    MessageAttachmentView(part: part)
                case .thinking, .cards:
                    EmptyView()
                }
            }

            // Model footer: same caption2/tertiary "providerID/modelID" treatment as
            // the user message, placed at the end of the assistant turn.
            if let footer = presentation.footer {
                HStack {
                    if let model = footer.model {
                        let timing = state.stepTimings[footer.messageID]
                        Text(
                            Self.modelFooter(
                                model: model,
                                general: footer.generalThroughput,
                                decode: timing?.decodeLabel
                            )
                        )
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    if !copyable.isEmpty { messageActionsMenu }
                }
                .padding(.leading, 4)
            }

            ForEach(presentation.errors, id: \.messageID) { error in
                Text(error.text)
                    .font(.caption)
                    .foregroundStyle(DesignColors.Semantic.error)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DesignColors.Semantic.error.opacity(DesignColors.surfaceFill(for: colorScheme)))
                    .clipShape(RoundedRectangle(cornerRadius: DesignCorners.medium))
                    .textSelection(.enabled)
            }
        }
    }

    private func thinkingCard(_ part: Part) -> some View {
        ThinkingCard(
            isStreaming: isPartStreaming(part),
            openedByHand: openedThinkingMessageIDs.contains(part.messageID)
        ) {
            markdownText(part.text ?? "", isUser: false, forcingMarkdown: true,
                         isStreaming: isPartStreaming(part))
        }
    }

    /// Keep the reasoning of a message open, or let it follow the turn again.
    ///
    /// The pill and the thinking card are two views for one piece of
    /// reasoning, so the choice cannot live in either of them: it has to
    /// outlive the swap between the two.
    private func toggleThinkingOpen(_ messageID: String) {
        if openedThinkingMessageIDs.contains(messageID) {
            openedThinkingMessageIDs.remove(messageID)
        } else {
            openedThinkingMessageIDs.insert(messageID)
        }
    }

    /// The message the thinking pill stands for: the running step's.
    private var thinkingPlaceholderMessageID: String {
        turnPresentation.messages.last?.info.id ?? ""
    }

    /// The turn that owns this row is still producing output.
    ///
    /// A turn spans several assistant messages — one per step — and the
    /// earlier steps are already completed while the last one is running.
    /// The last message decides, not the first.
    private var isTurnRunning: Bool {
        guard let last = turnPresentation.messages.last else { return false }
        return last.info.time.completed == nil
    }

    /// Whether the step that owns a part is still producing output.
    ///
    /// A merged turn holds several steps: the finished ones keep their
    /// Markdown, while the running one streams as plain text. The part's
    /// own message decides, not the row's.
    private func isPartStreaming(_ part: Part) -> Bool {
        guard let owner = turnPresentation.messages.first(where: { $0.info.id == part.messageID }) else {
            return isTurnRunning
        }
        return owner.info.time.completed == nil
    }

    /// Whether the thinking pill should stand in for a reasoning card that
    /// has not arrived yet.
    ///
    /// True while the step is live and the model has produced nothing the
    /// reader can see yet: no reasoning words, no answer text, and no tool
    /// still running (a running tool card carries its own live indicator).
    /// The pill is then the only sign that the agent is working.
    static func showsThinkingPlaceholder(parts: [Part], isTurnRunning: Bool) -> Bool {
        guard isTurnRunning else { return false }
        if parts.contains(where: { $0.isReasoning && !normalizedText($0.text).isEmpty }) { return false }
        if parts.contains(where: { $0.isText && !normalizedText($0.text).isEmpty }) { return false }
        if parts.contains(where: { $0.isTool && Self.isPartRunning($0) }) { return false }
        return true
    }

    /// Whether a tool part is still in flight.
    private static func isPartRunning(_ part: Part) -> Bool {
        guard let state = part.stateDisplay?.lowercased() else { return false }
        return state == "running" || state == "pending"
    }

    @ViewBuilder
    private func tileView(_ tile: CardGridTile) -> some View {
        switch tile {
        case .thinking(let part):
            // The reasoning part exists but carries no words yet: the model
            // is thinking. The pill holds the slot the prose will fill.
            if Self.normalizedText(part.text).isEmpty {
                ThinkingPlaceholderPill(
                    isOpen: openedThinkingMessageIDs.contains(part.messageID),
                    onToggle: { toggleThinkingOpen(part.messageID) }
                )
            } else {
                thinkingCard(part)
            }
        case .thinkingPlaceholder:
            ThinkingPlaceholderPill(
                isOpen: openedThinkingMessageIDs.contains(thinkingPlaceholderMessageID),
                onToggle: { toggleThinkingOpen(thinkingPlaceholderMessageID) }
            )
        case .fileCard(let part):
            FileCardView(
                part: part,
                workspaceDirectory: workspaceDirectory,
                onOpenResolvedPath: onOpenResolvedPath,
                onOpenFilesTab: onOpenFilesTab
            )
        case .toolCall(let part):
            ToolPartView(
                part: part,
                sessionTodos: sessionTodos,
                workspaceDirectory: workspaceDirectory,
                onOpenResolvedPath: onOpenResolvedPath
            )
        case .changes(let part):
            PatchPartView(
                part: part,
                totals: state.fileChangeTotals(turnUserMessageID: message.info.parentID, part: part),
                scope: .turn,
                onOpen: { openChanges(for: part) }
            )
        }
    }

    /// Open the changes surface for a change part.
    private func openChanges(for part: Part) {
        let paths = part.filePathsForNavigation
        guard !paths.isEmpty else {
            // A patch part without paths still means "files changed": send the
            // person to the file browser rather than to nothing.
            onOpenFilesTab()
            return
        }
        state.presentSessionChanges(
            host: .chat,
            sessionID: message.info.sessionID,
            turnUserMessageID: message.info.parentID,
            paths: paths,
            workspaceDirectory: workspaceDirectory
        )
    }
}

/// The thinking pill shown while the model is working but has not produced
/// reasoning yet.
///
/// It is the same chip the thinking card collapses into, so the transcript
/// shows one element that fills in rather than two that swap. It is a
/// disclosure: the reader can ask for the reasoning to stay open before the
/// words arrive, and the choice outlives the swap into the card.
private struct ThinkingPlaceholderPill: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    /// Whether the reader asked for the reasoning to stay open.
    let isOpen: Bool
    /// Opens or closes the reasoning that is coming.
    let onToggle: () -> Void

    var body: some View {
        Button {
            onToggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "brain.head.profile")
                    .font(DesignTypography.micro)
                    .scaleEffect(isPulsing ? 1.08 : 1)
                Text(L10n.t(.chatThinkingCard))
                    .fontWeight(.medium)
                Image(systemName: isOpen ? "chevron.down" : "chevron.right")
                    .font(DesignTypography.micro)
                    .foregroundStyle(DesignColors.Neutral.textTertiary)
            }
            .font(DesignTypography.micro)
            .foregroundStyle(DesignColors.Brand.primary)
            .padding(.horizontal, DesignSpacing.chipHorizontal)
            .padding(.vertical, DesignSpacing.chipVertical)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(DesignColors.surfaceFillColor(for: colorScheme))
            )
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.t(.chatThinkingCard))
        .accessibilityIdentifier("message-thinking-placeholder")
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(L10n.t(isOpen ? .expanded : .collapsed))
        .animation(reduceMotion ? nil : DesignAnimation.breathing, value: isPulsing)
        .onAppear { isPulsing = true }
    }
}

// Full-width process row: the thinking card is prose, so it takes the whole
// content width instead of a grid column. The self-drawn header is the only
// tappable element and toggles expansion in place.
private struct ThinkingCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false
    /// Set once the reader taps the disclosure: their choice then wins over
    /// the automatic open/close.
    @State private var hasManualChoice = false
    /// True while the turn that owns this reasoning is still running: the card
    /// opens itself so the reasoning is readable as it streams, and the user
    /// can still collapse it.
    private let isStreaming: Bool
    /// The reader opened this reasoning by hand — through the pill, before the
    /// words arrived. The choice has to survive the swap between the two.
    private let openedByHand: Bool
    private let content: Content

    init(isStreaming: Bool = false, openedByHand: Bool = false, @ViewBuilder content: () -> Content) {
        self.isStreaming = isStreaming
        self.openedByHand = openedByHand
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Compact tag, like the tool rows: the thinking card is prose, but
            // its header is a one-line disclosure, not a band across the
            // transcript.
            Button {
                hasManualChoice = true
                withAnimation(reduceMotion ? nil : DesignAnimation.spring) { expanded.toggle() }
            } label: {
            HStack(spacing: 6) {
                Image(systemName: "brain.head.profile")
                    .font(.caption)
                Text(L10n.t(.chatThinkingCard))
                    .fontWeight(.medium)
                Image(systemName: expanded ? "chevron.down" : "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(DesignColors.Neutral.textTertiary)
            }
            .font(DesignTypography.micro)
            .foregroundStyle(DesignColors.Brand.primary)
            .padding(.horizontal, DesignSpacing.chipHorizontal)
            .padding(.vertical, DesignSpacing.chipVertical)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(DesignColors.surfaceFillColor(for: colorScheme))
            )
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L10n.t(.chatThinkingCard))
            .accessibilityIdentifier("message-thinking-card")
            .accessibilityAddTraits(.isButton)
            .accessibilityValue(L10n.t(expanded ? .expanded : .collapsed))

            if expanded {
                content
                    .foregroundStyle(DesignColors.Neutral.textSecondary)
                    .padding(.leading, DesignSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onChange(of: isStreaming) { _, streaming in
            // Follow the turn: open when it starts, close when it ends — unless
            // the reader made their own choice.
            guard !hasManualChoice else { return }
            withAnimation(reduceMotion ? nil : DesignAnimation.spring) {
                expanded = streaming
            }
        }
        .onAppear {
            if openedByHand {
                // The reader opened this reasoning before the words arrived:
                // it comes open, and it stays open when the turn ends.
                hasManualChoice = true
                expanded = true
                return
            }
            guard !hasManualChoice else { return }
            expanded = isStreaming
        }
    }
}

private struct MessageTextSelectionSheet: View {
    let text: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            SelectableMessageTextView(text: text)
                .navigationTitle(L10n.t(.chatSelectText))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L10n.t(.appDone)) { dismiss() }
                    }
                }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct SelectableMessageTextView: UIViewRepresentable {
    let text: String

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.isEditable = false
        view.isSelectable = true
        view.alwaysBounceVertical = true
        view.adjustsFontForContentSizeCategory = true
        view.backgroundColor = .clear
        view.textColor = .label
        view.textContainerInset = UIEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)
        view.accessibilityIdentifier = "message-text-selection"
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        guard view.text != selectableText else { return }
        view.font = .preferredFont(forTextStyle: .body)
        view.text = selectableText
    }

    private var selectableText: String {
        MessageRowView.selectionText(from: text)
    }
}

private struct MessageAttachmentsGrid: View {
    let parts: [Part]

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 120, maximum: 180), spacing: DesignSpacing.sm)]
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: DesignSpacing.sm) {
            ForEach(parts, id: \.id) { part in
                MessageAttachmentView(part: part)
            }
        }
    }
}

private struct MessageAttachmentView: View {
    let part: Part
    @State private var showImage = false

    private var imageData: Data? {
        guard part.isImageAttachment, let url = part.url else { return nil }
        return Self.decodeDataURL(url)
    }

    var body: some View {
        Group {
            if let imageData, let image = UIImage(data: imageData) {
                Button {
                    showImage = true
                } label: {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 140, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: DesignCorners.medium))
                        .overlay(alignment: .bottomLeading) {
                            Text(part.filename ?? L10n.t(.attachmentImageTitle))
                                .font(DesignTypography.micro)
                                .lineLimit(1)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.black.opacity(0.45))
                        }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("message-attachment-image")
                .sheet(isPresented: $showImage) {
                    NavigationStack {
                        ImageView(uiImage: image)
                            .navigationTitle(part.filename ?? L10n.t(.attachmentImageTitle))
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button(L10n.t(.appDone)) { showImage = false }
                                }
                            }
                    }
                }
            } else {
                HStack(spacing: DesignSpacing.sm) {
                    Image(systemName: "paperclip")
                        .foregroundStyle(DesignColors.Brand.primary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(part.filename ?? L10n.t(.attachmentFileTitle))
                            .font(DesignTypography.meta)
                            .lineLimit(1)
                        if let mime = part.mime {
                            Text(mime)
                                .font(DesignTypography.micro)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(DesignSpacing.cardPadding)
                .background(DesignColors.Neutral.text.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: DesignCorners.medium))
                .accessibilityIdentifier("message-attachment-file")
            }
        }
    }

    private static func decodeDataURL(_ url: String) -> Data? {
        guard let comma = url.firstIndex(of: ",") else { return nil }
        let metadata = url[..<comma]
        guard metadata.contains(";base64") else { return nil }
        let raw = url[url.index(after: comma)...]
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: " ", with: "")
        return Data(base64Encoded: raw)
    }
}
