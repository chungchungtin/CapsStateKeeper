import CapsStateCore
import Foundation
import IOKit

public struct KeyboardCapsCacheReader {
    public init() {}

    public func readAll() -> [KeyboardCapsCache] {
        var caches: [KeyboardCapsCache] = []
        var seenRegistryIDs: Set<UInt64> = []

        for className in [
            "AppleHIDKeyboardEventDriverV2",
            "AppleUserHIDEventService",
            "IOHIDEventService",
        ] {
            var iterator: io_iterator_t = 0
            guard IOServiceGetMatchingServices(
                kIOMainPortDefault,
                IOServiceMatching(className),
                &iterator
            ) == KERN_SUCCESS else {
                continue
            }
            defer { IOObjectRelease(iterator) }

            while case let service = IOIteratorNext(iterator), service != 0 {
                defer { IOObjectRelease(service) }

                var registryID: UInt64 = 0
                guard IORegistryEntryGetRegistryEntryID(
                    service,
                    &registryID
                ) == KERN_SUCCESS,
                seenRegistryIDs.insert(registryID).inserted,
                let properties: [String: Any] = property(
                    service,
                    key: "HIDEventServiceProperties"
                ),
                let cache = properties["HIDCapsLockStateCache"] as? Bool else {
                    continue
                }

                let product: String = property(
                    service,
                    key: "Product"
                ) ?? "unknown"
                let vendor: NSNumber = property(
                    service,
                    key: "VendorID"
                ) ?? 0
                let productID: NSNumber = property(
                    service,
                    key: "ProductID"
                ) ?? 0

                caches.append(KeyboardCapsCache(
                    product: product,
                    vendorID: vendor.intValue,
                    productID: productID.intValue,
                    isOn: cache
                ))
            }
        }

        return caches
    }

    private func property<T>(
        _ service: io_service_t,
        key: String
    ) -> T? {
        IORegistryEntryCreateCFProperty(
            service,
            key as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? T
    }
}
