public struct CapsStateSnapshot: Equatable, Sendable {
    public let sourceID: String
    public let eventCapsLock: Bool
    public let hidCapsLock: Bool?

    public init(sourceID: String, eventCapsLock: Bool, hidCapsLock: Bool?) {
        self.sourceID = sourceID
        self.eventCapsLock = eventCapsLock
        self.hidCapsLock = hidCapsLock
    }
}

public enum CapsStateAction: Equatable, Sendable {
    case setCapsLock(Bool)
}

public struct CapsStatePolicy: Sendable {
    public let latinSourceIDs: Set<String>

    public init(latinSourceIDs: Set<String>) {
        self.latinSourceIDs = latinSourceIDs
    }

    public func action(for snapshot: CapsStateSnapshot) -> CapsStateAction? {
        guard latinSourceIDs.contains(snapshot.sourceID),
              snapshot.hidCapsLock == true,
              !snapshot.eventCapsLock else {
            return nil
        }
        return .setCapsLock(true)
    }
}
