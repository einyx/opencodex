import SwiftUI

/// The licences of the packages the app links.
///
/// The notices ship inside the app as a resource, generated from the resolved
/// package graph by `scripts/generate_third_party_notices.py`, so the text
/// cannot drift away from what is actually linked.
struct OpenSourceLicencesView: View {
    private static let noticesResource = "ThirdPartyNotices"

    private var notices: String {
        guard let url = Bundle.main.url(forResource: Self.noticesResource, withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return L10n.t(.settingsOpenSourceLicencesMissing)
        }
        return text
    }

    /// The notices as paragraphs.
    ///
    /// The document is long — every licence in full. One `Text` would lay out
    /// every line at once, and the page stayed blank for seconds while it did
    /// that: the layout of a 100 KB string is one pass, not a scroll. The
    /// paragraphs live in a lazy stack instead, so only the ones on screen are
    /// laid out, and the page is there the moment it opens.
    private var paragraphs: [String] {
        notices
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .newlines) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignSpacing.md) {
                ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                    Text(paragraph)
                        .font(DesignTypography.microMono)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(DesignSpacing.lg)
            .accessibilityIdentifier("settings-open-source-licences-text")
        }
        .navigationTitle(L10n.t(.settingsOpenSourceLicences))
        .navigationBarTitleDisplayMode(.inline)
    }
}
