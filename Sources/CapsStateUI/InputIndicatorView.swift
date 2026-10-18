import AppKit
import CapsStateCore

@MainActor
public final class InputIndicatorView: NSView {
    public static let indicatorSize = NSSize(width: 184, height: 56)
    public private(set) var preferredSize = indicatorSize
    private let language = NSTextField(labelWithString: "")
    private let sourceName = NSTextField(labelWithString: "")
    private let sourceLanguage = NSTextField(labelWithString: "")
    private let letterCase = NSTextField(labelWithString: "")
    private let caseLabel = NSTextField(labelWithString: "")
    private let languageTile = NSView()
    private let divider = NSBox()
    private var languageName = ""
    private var positionHint: String?
    private var opacity = InputIndicatorOpacity()

    public init() {
        super.init(frame: NSRect(origin: .zero, size: Self.indicatorSize))
        wantsLayer = true
        layer?.cornerRadius = 15
        layer?.masksToBounds = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.borderWidth = 0.75
        languageTile.frame = NSRect(x: 10, y: 11, width: 38, height: 34)
        languageTile.wantsLayer = true
        languageTile.layer?.cornerRadius = 9
        languageTile.layer?.backgroundColor = NSColor.clear.cgColor
        languageTile.layer?.borderWidth = 0.75
        addSubview(languageTile)
        divider.frame = NSRect(x: 126, y: 13, width: 1, height: 30)
        divider.boxType = .separator
        addSubview(divider)

        configure(language, frame: NSRect(x: 12, y: 18, width: 34, height: 22),
                  font: .systemFont(ofSize: 16, weight: .semibold), color: .systemBlue)
        language.alignment = .center
        configure(sourceName, frame: NSRect(x: 56, y: 29, width: 66, height: 19),
                  font: .systemFont(ofSize: 13, weight: .semibold), color: .labelColor)
        configure(sourceLanguage, frame: NSRect(x: 56, y: 11, width: 66, height: 15),
                  font: .systemFont(ofSize: 10, weight: .medium), color: .secondaryLabelColor)
        configure(letterCase, frame: NSRect(x: 132, y: 27, width: 44, height: 23),
                  font: .monospacedSystemFont(ofSize: 17, weight: .semibold), color: .labelColor)
        configure(caseLabel, frame: NSRect(x: 132, y: 10, width: 44, height: 15),
                  font: .systemFont(ofSize: 10, weight: .medium), color: .secondaryLabelColor)
        letterCase.alignment = .center
        caseLabel.alignment = .center
        updateOutlineAppearance()
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
    }

    public required init?(coder: NSCoder) { nil }

    public func updateOpacity(_ opacity: InputIndicatorOpacity) {
        self.opacity = opacity
        updateOutlineAppearance()
        needsDisplay = true
    }

    public func update(_ status: TypingStatus) {
        language.stringValue = status.source.badge
        sourceName.stringValue = status.source.displayName
        languageName = status.source.languageName
        sourceLanguage.stringValue = positionHint ?? languageName
        letterCase.stringValue = status.caseExample
        caseLabel.stringValue = status.caseLabel
        letterCase.textColor = status.isUppercase ? .systemOrange : .labelColor
        setAccessibilityLabel(status.accessibilityDescription)
        toolTip = status.accessibilityDescription
        updateTextOutlines()
        updatePreferredSize()
        needsDisplay = true
    }

    public func updatePositionHint(_ hint: String?) {
        positionHint = hint
        sourceLanguage.stringValue = hint ?? languageName
        sourceLanguage.textColor = hint == nil ? .secondaryLabelColor : .labelColor
        updateTextOutlines()
        updatePreferredSize()
    }

    public override var intrinsicContentSize: NSSize { preferredSize }
    public override var isOpaque: Bool { false }

    public override func layout() {
        super.layout()
        // Keep both badges and the original font sizes. Only the name column
        // grows; the containing panel can still clamp us to the visible screen.
        let nameWidth = max(0, bounds.width - 118)
        sourceName.frame = NSRect(x: 56, y: 29, width: nameWidth, height: 19)
        sourceLanguage.frame = NSRect(x: 56, y: 11, width: nameWidth, height: 15)
        divider.frame = NSRect(x: 60 + nameWidth, y: 13, width: 1, height: 30)
        letterCase.frame = NSRect(x: 66 + nameWidth, y: 27, width: 44, height: 23)
        caseLabel.frame = NSRect(x: 66 + nameWidth, y: 10, width: 44, height: 15)
    }

    public override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
        updateOutlineAppearance()
    }

    private func updateOutlineAppearance() {
        // Do not fade the panel or root view: that would multiply background and
        // text opacity. Zero background preserves the original hollow style.
        let textAlpha = CGFloat(opacity.text)
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(CGFloat(opacity.background)).cgColor
            layer?.borderColor = NSColor.labelColor.withAlphaComponent(0.28 * textAlpha).cgColor
            languageTile.layer?.borderColor = NSColor.systemBlue.withAlphaComponent(0.55 * textAlpha).cgColor
        }
        divider.alphaValue = textAlpha
        for label in [language, sourceName, sourceLanguage, letterCase, caseLabel] {
            label.alphaValue = textAlpha
        }
        updateTextOutlines()
    }

    private func updateTextOutlines() {
        for label in [language, sourceName, sourceLanguage, letterCase, caseLabel] {
            guard !label.stringValue.isEmpty, let font = label.font else { continue }
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = label.alignment
            paragraph.lineBreakMode = .byTruncatingTail
            // Negative stroke width draws both fill and stroke. The narrow
            // opposite-tone edge helps text on mixed backgrounds without a box.
            label.attributedStringValue = NSAttributedString(string: label.stringValue, attributes: [
                .font: font,
                .foregroundColor: label.textColor ?? NSColor.labelColor,
                .strokeColor: NSColor.windowBackgroundColor.withAlphaComponent(0.95),
                .strokeWidth: -3.0,
                .paragraphStyle: paragraph,
            ])
        }
    }

    private func updatePreferredSize() {
        let nameWidth = max(66, ceil(max(sourceName.intrinsicContentSize.width,
                                        sourceLanguage.intrinsicContentSize.width)))
        let size = NSSize(width: 118 + nameWidth, height: Self.indicatorSize.height)
        guard preferredSize != size else { return }
        preferredSize = size
        invalidateIntrinsicContentSize()
        // Standalone previews size themselves. A live panel is resized and
        // repositioned together by FloatingInputIndicator, avoiding edge jumps.
        if window == nil { setFrameSize(size) }
        needsLayout = true
    }

    private func configure(_ label: NSTextField, frame: NSRect, font: NSFont, color: NSColor) {
        label.frame = frame
        label.font = font
        label.textColor = color
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        label.isSelectable = false
        label.drawsBackground = false
        label.backgroundColor = .clear
        addSubview(label)
    }
}
