import Foundation

/// Background and foreground are independent; neither fades the menu-bar icon.
public struct InputIndicatorOpacity: Equatable, Sendable {
    public static let legacyDefaultsKey = "FloatingInputIndicatorOpacity"
    public static let backgroundDefaultsKey = "FloatingInputIndicatorBackgroundOpacity"
    public static let textDefaultsKey = "FloatingInputIndicatorTextOpacity"
    public static let minimumBackground = 0.0
    public static let minimumText = 0.20
    public static let maximum = 1.0
    public static let defaultBackground = 0.0
    public static let defaultText = 1.0
    public let background: Double
    public let text: Double
    public var backgroundPercent: Int { Int((background * 100).rounded()) }
    public var textPercent: Int { Int((text * 100).rounded()) }

    public init(background: Double = Self.defaultBackground, text: Double = Self.defaultText) {
        self.background = Self.normalized(background, minimum: Self.minimumBackground, fallback: Self.defaultBackground)
        self.text = Self.normalized(text, minimum: Self.minimumText, fallback: Self.defaultText)
    }

    public init(defaults: UserDefaults) {
        let background = (defaults.object(forKey: Self.backgroundDefaultsKey) as? NSNumber)?.doubleValue
        let text = (defaults.object(forKey: Self.textDefaultsKey) as? NSNumber)?.doubleValue
        let legacy = (defaults.object(forKey: Self.legacyDefaultsKey) as? NSNumber)?.doubleValue
        // The old whole-panel setting faded text on an empty background. Keep
        // that appearance until the user chooses a background or a new text value.
        self.init(background: background ?? Self.defaultBackground,
                  text: text ?? legacy ?? Self.defaultText)
    }

    public func save(to defaults: UserDefaults) {
        defaults.set(background, forKey: Self.backgroundDefaultsKey)
        defaults.set(text, forKey: Self.textDefaultsKey)
    }

    private static func normalized(_ value: Double, minimum: Double, fallback: Double) -> Double {
        let finiteValue = value.isFinite ? value : fallback
        return (min(Self.maximum, max(minimum, finiteValue)) * 100).rounded() / 100
    }
}
