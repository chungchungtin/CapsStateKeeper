import AppKit
import CapsStateCore
import CapsStateUI

// Offline rendering of our own view with fixed sample states; does not read the desktop.
@MainActor
final class PreviewCanvas: NSView {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor(srgbRed: 0.96, green: 0.97, blue: 0.98, alpha: 1).setFill()
        bounds.fill()
        NSColor(srgbRed: 0.10, green: 0.12, blue: 0.15, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: bounds.width, height: 110).fill()
        // Keep transparency guides for development; omit them from public
        // product images with --clean, using the same native indicator views.
        for row in 0..<2 {
            (row == 0 ? NSColor.white : NSColor.black).withAlphaComponent(0.10).setStroke()
            if !CommandLine.arguments.contains("--clean") {
                for offset in stride(from: 18, through: 72, by: 18) {
                    let y = CGFloat(row * 110 + offset)
                    let line = NSBezierPath()
                    line.move(to: CGPoint(x: 16, y: y))
                    line.line(to: CGPoint(x: bounds.width - 16, y: y))
                    line.lineWidth = 0.5
                    line.stroke()
                }
            }
            let title = row == 0 ? "深色背景" : "淺色背景"
            (title as NSString).draw(at: CGPoint(x: 26, y: row * 110 + 86), withAttributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .medium),
                .foregroundColor: row == 0 ? NSColor.lightGray : NSColor.darkGray,
            ])
        }
    }
}

@MainActor
final class MenuPreviewCanvas: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        bounds.fill()
    }
}

let application = NSApplication.shared
let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "dist/indicator-preview.png")
let canvas: NSView
if CommandLine.arguments.contains("--opacity-menu") {
    let opacityMenu = InputIndicatorOpacityMenu(opacity: InputIndicatorOpacity(background: 0.35, text: 0.9)) { _ in }
    guard let controls = opacityMenu.item.submenu?.items.first?.view else {
        fatalError("Unable to locate opacity menu controls")
    }
    canvas = MenuPreviewCanvas(frame: NSRect(x: 0, y: 0, width: controls.frame.width + 32, height: controls.frame.height + 32))
    canvas.appearance = NSAppearance(named: CommandLine.arguments.contains("--dark") ? .darkAqua : .aqua)
    controls.frame.origin = CGPoint(x: 16, y: 16)
    canvas.addSubview(controls)
} else {
    canvas = PreviewCanvas(frame: NSRect(x: 0, y: 0, width: 448, height: 220))
    let sources = [
        TypingInputSource(id: "com.apple.keylayout.ABC", name: "ABC", languageCode: "en"),
        TypingInputSource(id: "com.apple.inputmethod.TCIM.Zhuyin", name: "Zhuyin - Traditional", languageCode: "zh-Hant")
    ]
    for index in 0..<4 {
        let view = InputIndicatorView()
        view.appearance = NSAppearance(named: index >= 2 ? .darkAqua : .aqua)
        view.frame.origin = CGPoint(x: index % 2 == 0 ? 26 : 238, y: index < 2 ? 128 : 18)
        view.update(TypingStatus(source: sources[index / 2], capsLock: index % 2 != 0,
                                 shift: false, isUppercase: index % 2 != 0))
        if index == 2 { view.updatePositionHint("輸入框旁") }
        if index == 3 { view.updatePositionHint("滑鼠旁") }
        canvas.addSubview(view)
    }
}
canvas.layoutSubtreeIfNeeded()
guard let bitmap = canvas.bitmapImageRepForCachingDisplay(in: canvas.bounds) else {
    fatalError("Unable to allocate indicator preview")
}
canvas.cacheDisplay(in: canvas.bounds, to: bitmap)
guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Unable to encode indicator preview")
}
try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
try png.write(to: output, options: .atomic)
print(output.path)
