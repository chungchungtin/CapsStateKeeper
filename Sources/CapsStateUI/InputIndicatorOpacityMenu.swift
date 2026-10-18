import AppKit
import CapsStateCore

/// One retained target owns the menu controls. The app owns the saved values and
/// panel; this menu reports user changes without waking or repositioning it.
@MainActor
public final class InputIndicatorOpacityMenu: NSObject {
    public let item = NSMenuItem(title: "浮標不透明度", action: nil, keyEquivalent: "")
    private let backgroundLabel = NSTextField(labelWithString: "")
    private let textLabel = NSTextField(labelWithString: "")
    private let backgroundSlider = NSSlider(value: 0, minValue: 0, maxValue: 100, target: nil, action: nil)
    private let textSlider = NSSlider(value: 100, minValue: 20, maxValue: 100, target: nil, action: nil)
    private let preview = InputIndicatorView()
    private var opacity: InputIndicatorOpacity
    private let onChange: (InputIndicatorOpacity) -> Void

    public init(opacity: InputIndicatorOpacity, onChange: @escaping (InputIndicatorOpacity) -> Void) {
        self.opacity = opacity
        self.onChange = onChange
        super.init()

        let submenu = NSMenu(title: "浮標不透明度")
        submenu.autoenablesItems = false
        let controls = NSView(frame: NSRect(x: 0, y: 0, width: 248, height: 276))
        configure(backgroundSlider, label: backgroundLabel, in: controls, y: 212,
                  minimum: InputIndicatorOpacity.minimumBackground,
                  identifier: "background-opacity", action: #selector(backgroundChanged),
                  accessibilityLabel: "背景不透明度，百分比",
                  help: "0% 完全透明、空心，100% 實心；不影響文字，設定會自動儲存",
                  endpoints: ("0% 空心", "100% 實心"))
        configure(textSlider, label: textLabel, in: controls, y: 124,
                  minimum: InputIndicatorOpacity.minimumText,
                  identifier: "text-opacity", action: #selector(textChanged),
                  accessibilityLabel: "文字不透明度，百分比",
                  help: "20% 較淡，100% 最清楚；文字與細框一起調整，不影響背景，設定會自動儲存",
                  endpoints: ("20% 較淡", "100% 清晰"))
        let previewLabel = NSTextField(labelWithString: "外觀預覽")
        previewLabel.frame = NSRect(x: 16, y: 84, width: 216, height: 16)
        previewLabel.font = .systemFont(ofSize: 11)
        previewLabel.textColor = .secondaryLabelColor
        controls.addSubview(previewLabel)
        preview.frame.origin = CGPoint(x: 32, y: 16)
        preview.update(TypingStatus(
            source: TypingInputSource(id: "com.apple.inputmethod.TCIM.Zhuyin", name: "注音", languageCode: "zh-Hant"),
            capsLock: false, shift: false, isUppercase: false
        ))
        preview.setAccessibilityLabel("浮標外觀範例，非目前輸入狀態")
        preview.toolTip = "外觀範例，非目前輸入狀態"
        // A neutral pattern makes background changes visible even when the
        // badge fill and the native menu happen to use the same system color.
        let backdrop = OpacityPreviewBackdrop(frame: preview.frame)
        backdrop.setAccessibilityElement(false)
        controls.addSubview(backdrop)
        controls.addSubview(preview)

        let controlItem = NSMenuItem(title: "調整浮標不透明度", action: nil, keyEquivalent: "")
        controlItem.view = controls
        submenu.addItem(controlItem)
        let reset = NSMenuItem(title: "重設：背景 0%／文字 100%", action: #selector(resetOpacity), keyEquivalent: "")
        reset.target = self
        submenu.addItem(reset)
        item.submenu = submenu
        update(opacity)
    }

    public func update(_ opacity: InputIndicatorOpacity) {
        self.opacity = opacity
        backgroundLabel.stringValue = "背景不透明度：\(opacity.backgroundPercent)%"
        textLabel.stringValue = "文字不透明度：\(opacity.textPercent)%"
        backgroundSlider.doubleValue = Double(opacity.backgroundPercent)
        textSlider.doubleValue = Double(opacity.textPercent)
        preview.updateOpacity(opacity)
    }

    @objc private func backgroundChanged(_ sender: NSSlider) {
        apply(InputIndicatorOpacity(background: sender.doubleValue / 100, text: opacity.text))
    }

    @objc private func textChanged(_ sender: NSSlider) {
        apply(InputIndicatorOpacity(background: opacity.background, text: sender.doubleValue / 100))
    }

    @objc private func resetOpacity() { apply(InputIndicatorOpacity()) }

    private func apply(_ opacity: InputIndicatorOpacity) {
        update(opacity)
        onChange(opacity)
    }

    private func configure(_ slider: NSSlider, label: NSTextField, in controls: NSView,
                           y: CGFloat, minimum: Double, identifier: String, action: Selector,
                           accessibilityLabel: String, help: String, endpoints: (String, String)) {
        label.frame = NSRect(x: 16, y: y + 32, width: 216, height: 20)
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        controls.addSubview(label)
        slider.frame = NSRect(x: 16, y: y, width: 216, height: 24)
        slider.minValue = minimum * 100
        slider.maxValue = InputIndicatorOpacity.maximum * 100
        slider.isContinuous = true
        slider.identifier = NSUserInterfaceItemIdentifier(identifier)
        slider.target = self
        slider.action = action
        slider.setAccessibilityLabel(accessibilityLabel)
        slider.setAccessibilityHelp(help)
        controls.addSubview(slider)
        for (text, x, alignment) in [(endpoints.0, 16.0, NSTextAlignment.left),
                                      (endpoints.1, 132.0, NSTextAlignment.right)] {
            let endpoint = NSTextField(labelWithString: text)
            endpoint.frame = NSRect(x: x, y: y - 19, width: 100, height: 16)
            endpoint.font = .systemFont(ofSize: 11)
            endpoint.textColor = .secondaryLabelColor
            endpoint.alignment = alignment
            controls.addSubview(endpoint)
        }
    }
}

@MainActor
private final class OpacityPreviewBackdrop: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSColor.labelColor.withAlphaComponent(0.12).setStroke()
        let lines = NSBezierPath()
        lines.lineWidth = 0.5
        for y in stride(from: CGFloat(10), to: bounds.height, by: CGFloat(12)) {
            lines.move(to: CGPoint(x: 8, y: y))
            lines.line(to: CGPoint(x: bounds.width - 8, y: y))
        }
        lines.stroke()
    }
}
