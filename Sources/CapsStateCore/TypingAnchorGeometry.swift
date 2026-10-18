import CoreGraphics

public enum TypingAnchorGeometry {
    public static func validField(_ rect: CGRect, window: CGRect?) -> Bool {
        valid(rect) && rect.width >= 1 && rect.height >= 1
            && (window.map { $0.intersects(rect) } ?? true)
    }

    public static func validCaret(_ rect: CGRect, field: CGRect?, window: CGRect?) -> Bool {
        guard valid(rect), rect.width >= 0, rect.width < 500,
              rect.height > 0, rect.height < 150 else { return false }
        // A zero-width insertion point is valid, but an offscreen/stale AX
        // rectangle is not. Allow a few points for text-container insets.
        let caret = rect.insetBy(dx: -1, dy: -1)
        if let field, !field.insetBy(dx: -8, dy: -8).intersects(caret) { return false }
        if let window, !window.insetBy(dx: -8, dy: -8).intersects(caret) { return false }
        return true
    }

    private static func valid(_ rect: CGRect) -> Bool {
        !rect.isNull && !rect.isInfinite && rect.origin.x.isFinite && rect.origin.y.isFinite
            && rect.width.isFinite && rect.height.isFinite
    }
}
