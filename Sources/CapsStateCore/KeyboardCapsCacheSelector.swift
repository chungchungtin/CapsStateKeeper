public struct KeyboardDescriptor: Equatable, Hashable, Sendable {
    public let deviceID: UInt64
    public let product: String
    public let vendorID: Int
    public let productID: Int

    public init(
        deviceID: UInt64,
        product: String,
        vendorID: Int,
        productID: Int
    ) {
        self.deviceID = deviceID
        self.product = product
        self.vendorID = vendorID
        self.productID = productID
    }
}

public struct KeyboardCapsCache: Equatable, Sendable {
    public let product: String
    public let vendorID: Int
    public let productID: Int
    public let isOn: Bool

    public init(
        product: String,
        vendorID: Int,
        productID: Int,
        isOn: Bool
    ) {
        self.product = product
        self.vendorID = vendorID
        self.productID = productID
        self.isOn = isOn
    }
}

public enum KeyboardCapsCacheSelector {
    public static func state(
        from caches: [KeyboardCapsCache],
        preferredKeyboard: KeyboardDescriptor?
    ) -> Bool? {
        guard !caches.isEmpty else { return nil }

        if let preferredKeyboard {
            if preferredKeyboard.vendorID != 0,
               preferredKeyboard.productID != 0 {
                let exact = caches.filter {
                    $0.vendorID == preferredKeyboard.vendorID &&
                    $0.productID == preferredKeyboard.productID
                }
                if let state = unambiguousState(in: exact) {
                    return state
                }
            }

            let sameProduct = caches.filter {
                $0.product == preferredKeyboard.product
            }
            if let state = unambiguousState(in: sameProduct) {
                return state
            }
            return nil
        }

        return unambiguousState(in: caches)
    }

    private static func unambiguousState(
        in caches: [KeyboardCapsCache]
    ) -> Bool? {
        guard let first = caches.first,
              caches.allSatisfy({ $0.isOn == first.isOn }) else {
            return nil
        }
        return first.isOn
    }
}
