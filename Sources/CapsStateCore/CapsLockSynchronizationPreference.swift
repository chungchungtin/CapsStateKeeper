import Foundation

/// Preserve the user's opt-out across launches without changing other settings.
public struct CapsLockSynchronizationPreference: Equatable, Sendable {
    public static let defaultsKey = "CapsLockSynchronizationEnabled"
    public let isEnabled: Bool

    public init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }

    public init(defaults: UserDefaults) {
        // Existing installations have no saved value and keep synchronization on.
        self.init(isEnabled: (defaults.object(forKey: Self.defaultsKey) as? NSNumber)?.boolValue ?? true)
    }

    public func save(to defaults: UserDefaults) {
        defaults.set(isEnabled, forKey: Self.defaultsKey)
    }
}
