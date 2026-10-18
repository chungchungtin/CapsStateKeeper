import Foundation

public struct TypingInputSource: Equatable, Sendable {
    public let id: String
    public let name: String
    public let languageCode: String

    public init(id: String, name: String, languageCode: String) {
        self.id = id
        self.name = name
        self.languageCode = languageCode
    }

    public var displayName: String {
        // TIS can return the English name even while the system UI is Chinese.
        // Match the built-in input source, not arbitrary third-party names.
        switch id {
        case "com.apple.inputmethod.TCIM.Zhuyin": "注音"
        default: name
        }
    }

    public var badge: String {
        switch languageCode.lowercased().split(separator: "-").first {
        case "zh": "中"
        case "en": "EN"
        case "ja": "日"
        case "ko": "한"
        case "ru": "RU"
        case .some(let code): String(code.prefix(3)).uppercased()
        case nil: "⌨"
        }
    }

    public var languageName: String {
        Locale(identifier: "zh_TW").localizedString(forLanguageCode: languageCode)
            ?? name
    }
}

public struct TypingStatus: Equatable, Sendable {
    public let source: TypingInputSource
    public let capsLock: Bool
    public let shift: Bool
    public let isUppercase: Bool

    public init(source: TypingInputSource, capsLock: Bool, shift: Bool, isUppercase: Bool) {
        self.source = source
        self.capsLock = capsLock
        self.shift = shift
        self.isUppercase = isUppercase
    }

    public var caseExample: String { isUppercase ? "ABC" : "abc" }
    public var caseLabel: String { isUppercase ? "大寫" : "小寫" }
    public var accessibilityDescription: String {
        "\(source.languageName)，\(source.displayName)，英文字母\(caseLabel)；"
            + "Caps Lock \(capsLock ? "開啟" : "關閉")，Shift \(shift ? "按住" : "放開")"
    }
}
