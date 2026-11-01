import SwiftUI
import UIKit

struct ComposerPasteControl: View {
    @Environment(\.colorScheme) private var colorScheme
    var beginPaste: () -> ([ComposerPastePayload]) -> Void
    var accessibilityLabel: String

    var body: some View {
        ComposerPasteButton(
            beginPaste: beginPaste,
            accessibilityLabel: accessibilityLabel,
            interfaceStyle: Self.interfaceStyle(for: colorScheme)
        )
        .id(Self.interfaceStyle(for: colorScheme).rawValue)
        .frame(width: ComposerHitTarget.minimum, height: ComposerHitTarget.minimum)
    }

    private static func interfaceStyle(for colorScheme: ColorScheme) -> UIUserInterfaceStyle {
        colorScheme == .dark ? .dark : .light
    }
}

struct ComposerPasteButton: UIViewRepresentable {
    var beginPaste: () -> ([ComposerPastePayload]) -> Void
    var accessibilityLabel: String
    var interfaceStyle: UIUserInterfaceStyle

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIPasteControl {
        let control = UIPasteControl(configuration: PasteChrome.configuration(for: interfaceStyle))
        control.target = context.coordinator
        control.accessibilityIdentifier = "chat-paste"
        control.accessibilityLabel = accessibilityLabel
        return control
    }

    func updateUIView(_ uiView: UIPasteControl, context: Context) {
        context.coordinator.beginPaste = beginPaste
        uiView.target = context.coordinator
        uiView.accessibilityLabel = accessibilityLabel
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIPasteControl, context: Context) -> CGSize? {
        CGSize(width: ComposerHitTarget.minimum, height: ComposerHitTarget.minimum)
    }

    final class Coordinator: UIView {
        var beginPaste: (() -> ([ComposerPastePayload]) -> Void)?

        override init(frame: CGRect) {
            super.init(frame: frame)
            pasteConfiguration = ComposerPastePayload.acceptingConfiguration
            isUserInteractionEnabled = false
            isAccessibilityElement = false
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            pasteConfiguration = ComposerPastePayload.acceptingConfiguration
            isUserInteractionEnabled = false
            isAccessibilityElement = false
        }

        override func paste(itemProviders: [NSItemProvider]) {
            let deliver = beginPaste?()
            let providers = itemProviders
            Task { @MainActor in
                let payloads = await ComposerPastePayload.payloads(from: providers)
                deliver?(payloads)
            }
        }

        override func canPaste(_ itemProviders: [NSItemProvider]) -> Bool {
            itemProviders.contains { ComposerPastePayload.canLoad(from: $0) }
        }
    }
}

enum PasteChrome {
    static func plate(for style: UIUserInterfaceStyle) -> UIColor {
        UIColor(style == .dark ? DesignColors.Neutral.composerDark : DesignColors.Neutral.composerLight)
    }

    static func configuration(for style: UIUserInterfaceStyle) -> UIPasteControl.Configuration {
        let configuration = UIPasteControl.Configuration()
        configuration.displayMode = .iconOnly
        configuration.cornerRadius = 0
        configuration.baseForegroundColor = UIColor(DesignColors.Brand.primary)
        configuration.baseBackgroundColor = plate(for: style)
        return configuration
    }
}

/// What the clipboard brought into the composer.
///
/// The clipboard holds more than text: a screenshot the user copied on the
/// phone is an image, and the composer can send images. So the paste is a
/// payload, not a string.
enum ComposerPastePayload: Equatable {
    /// Text the user pasted.
    case text(String)
    /// The bytes of an image the user pasted.
    case image(Data)

    /// What the paste control offers: text and images.
    ///
    /// The configuration is what the system reads to decide whether the paste
    /// button shows up at all, so accepting strings alone hid the button for
    /// an image on the clipboard.
    static var acceptingConfiguration: UIPasteConfiguration {
        let configuration = UIPasteConfiguration(forAccepting: NSString.self)
        configuration.addTypeIdentifiers(forAccepting: UIImage.self)
        return configuration
    }

    /// Whether the provider holds something the composer can take.
    static func canLoad(from provider: NSItemProvider) -> Bool {
        provider.canLoadObject(ofClass: NSString.self) || provider.canLoadObject(ofClass: UIImage.self)
    }

    /// What the providers hold, in the order the clipboard lists them.
    static func payloads(from providers: [NSItemProvider]) async -> [ComposerPastePayload] {
        var payloads: [ComposerPastePayload] = []
        for provider in providers {
            // An image wins over a text rendering of the same item: a copied
            // screenshot also carries its file name as text.
            if provider.canLoadObject(ofClass: UIImage.self), let data = await imageData(from: provider) {
                payloads.append(.image(data))
                continue
            }
            if provider.canLoadObject(ofClass: NSString.self), let text = await string(from: provider) {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                payloads.append(.text(text))
            }
        }
        return payloads
    }

    private static func string(from provider: NSItemProvider) async -> String? {
        await withCheckedContinuation { continuation in
            provider.loadObject(ofClass: NSString.self) { object, _ in
                continuation.resume(returning: object as? String)
            }
        }
    }

    /// The image's bytes.
    ///
    /// PNG keeps a screenshot lossless; a photo falls back to JPEG. The
    /// composer transcodes whatever arrives, so the size is not the concern
    /// here.
    private static func imageData(from provider: NSItemProvider) async -> Data? {
        let image: UIImage? = await withCheckedContinuation { continuation in
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                continuation.resume(returning: object as? UIImage)
            }
        }
        guard let image else { return nil }
        return image.pngData() ?? image.jpegData(compressionQuality: 0.9)
    }
}
