import Foundation
import CoreGraphics

public enum FloatingIndicatorPlacement {
    /// Quartz/AX use a top-left origin; AppKit uses the main display's bottom-left.
    /// Do not flip relative to the target display: that breaks vertically stacked displays.
    public static func appKitRect(from rect: CGRect, primaryDisplayTop: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryDisplayTop - rect.maxY,
               width: rect.width, height: rect.height)
    }

    public static func frame(
        size: CGSize, caret: CGRect?, field: CGRect?, pointer: CGPoint, visibleScreen: CGRect
    ) -> CGRect {
        let safe = visibleScreen.insetBy(dx: 8, dy: 8)
        let width = min(size.width, safe.width)
        let height = min(size.height, safe.height)
        var origin: CGPoint

        if let caret {
            // Stay above the insertion point and away from IME candidate lists below it.
            origin = CGPoint(x: caret.maxX + 12, y: caret.maxY + 12)
            if origin.y + height > safe.maxY {
                origin.y = caret.minY - height - 12
            }
            if origin.x + width > safe.maxX {
                origin.x = caret.minX - width - 12
            }
        } else if let field {
            // A browser may expose its input box but not an insertion rectangle.
            // Anchor to that box, never to the top-right of the whole window.
            origin = CGPoint(x: field.minX + 12, y: field.maxY + 10)
            if origin.y + height > safe.maxY {
                origin.y = field.minY - height - 10
            }
        } else {
            // Explicitly labelled fallback for unsupported apps or missing AX
            // permission. This is not presented as a detected typing caret.
            origin = CGPoint(x: pointer.x + 16, y: pointer.y + 16)
            if origin.x + width > safe.maxX { origin.x = pointer.x - width - 16 }
            if origin.y + height > safe.maxY { origin.y = pointer.y - height - 16 }
        }

        origin.x = min(max(origin.x, safe.minX), safe.maxX - width)
        origin.y = min(max(origin.y, safe.minY), safe.maxY - height)
        return CGRect(origin: origin, size: CGSize(width: width, height: height))
    }
}
