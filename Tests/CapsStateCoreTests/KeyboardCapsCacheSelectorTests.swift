import XCTest
@testable import CapsStateCore

final class KeyboardCapsCacheSelectorTests: XCTestCase {
    private let internalKeyboard = KeyboardDescriptor(
        deviceID: 1,
        product: "Apple Internal Keyboard / Trackpad",
        vendorID: 1452,
        productID: 834
    )
    private let keychron = KeyboardDescriptor(
        deviceID: 2,
        product: "Keychron K10 Max",
        vendorID: 13364,
        productID: 2720
    )
    private let caches = [
        KeyboardCapsCache(
            product: "Apple Internal Keyboard / Trackpad",
            vendorID: 0,
            productID: 0,
            isOn: true
        ),
        KeyboardCapsCache(
            product: "Keychron K10 Max",
            vendorID: 13364,
            productID: 2720,
            isOn: false
        ),
    ]

    func testConflictingCachesWithoutRecentKeyboardFailClosed() {
        XCTAssertNil(KeyboardCapsCacheSelector.state(
            from: caches,
            preferredKeyboard: nil
        ))
    }

    func testSelectsKeychronCacheByVendorAndProductID() {
        XCTAssertEqual(KeyboardCapsCacheSelector.state(
            from: caches,
            preferredKeyboard: keychron
        ), false)
    }

    func testFallsBackToProductNameForInternalKeyboardDriver() {
        XCTAssertEqual(KeyboardCapsCacheSelector.state(
            from: caches,
            preferredKeyboard: internalKeyboard
        ), true)
    }

    func testCommonStateIsSafeWithoutARecentKeyboard() {
        let matchingCaches = caches.map {
            KeyboardCapsCache(
                product: $0.product,
                vendorID: $0.vendorID,
                productID: $0.productID,
                isOn: true
            )
        }

        XCTAssertEqual(KeyboardCapsCacheSelector.state(
            from: matchingCaches,
            preferredKeyboard: nil
        ), true)
    }
}
