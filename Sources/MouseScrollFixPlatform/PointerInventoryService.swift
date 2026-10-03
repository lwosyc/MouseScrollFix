import Foundation
import IOKit
import MouseScrollFixCore

/// Enumerates pointing devices from the I/O Registry and watches for changes.
///
/// Deliberately *not* IOHIDManager with input callbacks: opening a device for input
/// would require Input Monitoring permission, and it would still not tell us which
/// device produced a given scroll event (no public API does). Enumeration through
/// `IOServiceMatching` opens nothing and needs no permission at all.
///
/// What this service is for:
/// * `hasExternalPointer` — enables mouse-priority for otherwise ambiguous pixel
///   streams in the policy engine.
/// * the "only a built-in trackpad is present" fast path — protects the trackpad.
/// * showing the user what the system actually sees.
///
/// What it is *not* for: attributing an individual scroll event to a device.
public final class PointerInventoryService: @unchecked Sendable {
    /// Property keys. The values are the documented contents of the `IOHIDDeviceKeys.h`
    /// constants (`kIOHIDDeviceUsagePairsKey` and friends); spelled out so the target
    /// does not depend on how the Clang importer exposes those string macros.
    private enum Key {
        static let usagePairs = "DeviceUsagePairs"
        static let deviceUsage = "DeviceUsage"
        static let deviceUsagePage = "DeviceUsagePage"
        static let vendorID = "VendorID"
        static let productID = "ProductID"
        static let product = "Product"
        static let manufacturer = "Manufacturer"
        static let transport = "Transport"
        static let locationID = "LocationID"
        static let builtIn = "Built-In"                 // kIOHIDBuiltInKey, undocumented
        static let virtualDevice = "HIDVirtualDevice"   // kIOHIDVirtualHIDDevice
    }

    /// Notification names: values of `kIOFirstMatchNotification` / `kIOTerminatedNotification`.
    private enum Notification {
        static let firstMatch = "IOFirstMatchNotification"
        static let terminated = "IOTerminatedNotification"
    }

    private let lock = NSLock()
    private var storedSnapshot: InventorySnapshot = .empty

    private var port: IONotificationPortRef?
    private var runLoopSource: CFRunLoopSource?
    private var arrivalIterator: io_iterator_t = 0
    private var removalIterator: io_iterator_t = 0
    private var started = false

    /// Called on the main thread whenever the inventory changes.
    public var onChange: ((InventorySnapshot) -> Void)?

    public init() {}

    deinit {
        stop()
    }

    public var snapshot: InventorySnapshot {
        lock.lock()
        defer { lock.unlock() }
        return storedSnapshot
    }

    // MARK: Lifecycle (main thread)

    public func start() {
        guard !started else {
            refresh()
            return
        }
        started = true

        guard let newPort = IONotificationPortCreate(kIOMainPortDefault) else {
            refresh()
            return
        }
        port = newPort

        if let source = IONotificationPortGetRunLoopSource(newPort)?.takeUnretainedValue() {
            runLoopSource = source
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        }

        let context = Unmanaged.passUnretained(self).toOpaque()
        let arrived = IOServiceAddMatchingNotification(
            newPort,
            Notification.firstMatch,
            IOServiceMatching("IOHIDDevice"),
            pointerInventoryServiceChanged,
            context,
            &arrivalIterator
        )
        let removed = IOServiceAddMatchingNotification(
            newPort,
            Notification.terminated,
            IOServiceMatching("IOHIDDevice"),
            pointerInventoryServiceChanged,
            context,
            &removalIterator
        )

        if arrived != KERN_SUCCESS || removed != KERN_SUCCESS {
            tearDown()
            started = false
        }

        // A notification is armed only once its initial iterator has been drained.
        drain(arrivalIterator)
        drain(removalIterator)
        refresh()
    }

    public func stop() {
        started = false
        tearDown()
        publish(.empty)
    }

    private func tearDown() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        runLoopSource = nil
        if arrivalIterator != 0 {
            IOObjectRelease(arrivalIterator)
            arrivalIterator = 0
        }
        if removalIterator != 0 {
            IOObjectRelease(removalIterator)
            removalIterator = 0
        }
        if let port {
            IONotificationPortDestroy(port)
        }
        port = nil
    }

    public func refresh() {
        publish(readInventory())
    }

    fileprivate func handleServiceChange(_ iterator: io_iterator_t) {
        drain(iterator)
        refresh()
    }

    private func drain(_ iterator: io_iterator_t) {
        guard iterator != 0 else { return }
        while case let service = IOIteratorNext(iterator), service != 0 {
            IOObjectRelease(service)
        }
    }

    private func publish(_ next: InventorySnapshot) {
        lock.lock()
        let changed = storedSnapshot != next
        storedSnapshot = next
        lock.unlock()
        if changed {
            onChange?(next)
        }
    }

    // MARK: Enumeration

    private func readInventory() -> InventorySnapshot {
        var iterator: io_iterator_t = 0
        let status = IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("IOHIDDevice"),
            &iterator
        )
        guard status == KERN_SUCCESS else { return .empty }
        defer { IOObjectRelease(iterator) }

        var collected: [PointerDevice] = []
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            var registryID: UInt64 = 0
            guard IORegistryEntryGetRegistryEntryID(service, &registryID) == KERN_SUCCESS else {
                continue
            }
            collected.append(makeDevice(service: service, registryID: registryID))
        }
        return InventorySnapshot(devices: Self.deduplicate(collected))
    }

    private func makeDevice(service: io_service_t, registryID: UInt64) -> PointerDevice {
        let usagePairs = readUsagePairs(service)
        let vendorID = (property(Key.vendorID, service) as? NSNumber)?.intValue ?? 0
        let productID = (property(Key.productID, service) as? NSNumber)?.intValue ?? 0
        let transport = (property(Key.transport, service) as? String) ?? ""
        let isBuiltIn = property(Key.builtIn, service) as? Bool
        let isVirtual = (property(Key.virtualDevice, service) as? Bool)
            ?? (transport == "Virtual")

        return PointerDevice(
            id: registryID,
            name: (property(Key.product, service) as? String) ?? "Unknown device",
            manufacturer: property(Key.manufacturer, service) as? String,
            vendorID: vendorID,
            productID: productID,
            transport: transport,
            isBuiltIn: isBuiltIn,
            isVirtual: isVirtual,
            usagePairs: usagePairs,
            locationID: (property(Key.locationID, service) as? NSNumber)?.intValue ?? 0,
            kind: Self.classify(
                vendorID: vendorID,
                productID: productID,
                transport: transport,
                isBuiltIn: isBuiltIn,
                isVirtual: isVirtual,
                usagePairs: usagePairs
            )
        )
    }

    private func readUsagePairs(_ service: io_service_t) -> [PointerDevice.UsagePair] {
        if let raw = property(Key.usagePairs, service) as? [[String: Any]], !raw.isEmpty {
            return raw.compactMap { pair in
                guard let page = (pair[Key.deviceUsagePage] as? NSNumber)?.intValue,
                      let usage = (pair[Key.deviceUsage] as? NSNumber)?.intValue
                else { return nil }
                return PointerDevice.UsagePair(page: page, usage: usage)
            }
        }
        // Older devices expose a single primary usage pair instead of a list.
        guard let page = (property("PrimaryUsagePage", service) as? NSNumber)?.intValue,
              let usage = (property("PrimaryUsage", service) as? NSNumber)?.intValue
        else { return [] }
        return [PointerDevice.UsagePair(page: page, usage: usage)]
    }

    private func property(_ name: String, _ service: io_service_t) -> Any? {
        IORegistryEntryCreateCFProperty(
            service,
            name as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue()
    }

    // MARK: Classification

    /// Documented usage ids from `IOHIDUsageTables.h`.
    private static let genericDesktopMouse = PointerDevice.UsagePair(page: 0x01, usage: 0x02)
    private static let genericDesktopPointer = PointerDevice.UsagePair(page: 0x01, usage: 0x01)
    private static let digitizerTouchPad = PointerDevice.UsagePair(page: 0x0D, usage: 0x05)

    private static let appleVendorIDs: Set<Int> = [0x05AC, 0x004C]
    private static let magicMouseProductIDs: Set<Int> = [0x0269, 0x030D, 0x0323]
    private static let magicTrackpadProductIDs: Set<Int> = [0x0265, 0x030E, 0x0324]
    private static let builtInTrackpadProductIDs: Set<Int> = [0x0273, 0x0276, 0x0278, 0x0340]

    /// Classifies one registry node.
    ///
    /// The touch-surface signal is the Digitizer/Touch Pad usage pair: the built-in
    /// trackpad advertises it *in addition* to Generic Desktop/Mouse, and its primary
    /// usage is Mouse, so primary-usage matching alone would misclassify it.
    static func classify(
        vendorID: Int,
        productID: Int,
        transport: String,
        isBuiltIn: Bool?,
        isVirtual: Bool,
        usagePairs: [PointerDevice.UsagePair]
    ) -> PointerDeviceKind {
        if isVirtual { return .unknown }

        let isTouchPad = usagePairs.contains(digitizerTouchPad)
        if isTouchPad {
            let builtIn = isBuiltIn ?? (transport == "FIFO")
            return builtIn ? .builtInTrackpad : .externalTrackpad
        }

        if appleVendorIDs.contains(vendorID) {
            if magicMouseProductIDs.contains(productID) { return .touchSurface }
            if magicTrackpadProductIDs.contains(productID) { return .externalTrackpad }
            if builtInTrackpadProductIDs.contains(productID) { return .builtInTrackpad }
        }

        if usagePairs.contains(genericDesktopMouse) || usagePairs.contains(genericDesktopPointer) {
            return .mouse
        }
        return .unknown
    }

    /// One physical device shows up as several registry nodes. Collapse them so counts
    /// and the UI are honest, merging the usage pairs of the duplicates.
    static func deduplicate(_ devices: [PointerDevice]) -> [PointerDevice] {
        var merged: [String: PointerDevice] = [:]
        for device in devices {
            let key = "\(device.vendorID)|\(device.productID)|\(device.locationID)|\(device.transport)|\(device.isBuiltIn.map(String.init) ?? "?")"
            guard let existing = merged[key] else {
                merged[key] = device
                continue
            }
            let usages = Array(Set(existing.usagePairs).union(device.usagePairs))
            merged[key] = PointerDevice(
                id: existing.id,
                name: existing.name.count >= device.name.count ? existing.name : device.name,
                manufacturer: existing.manufacturer ?? device.manufacturer,
                vendorID: existing.vendorID,
                productID: existing.productID,
                transport: existing.transport,
                isBuiltIn: existing.isBuiltIn,
                isVirtual: existing.isVirtual && device.isVirtual,
                usagePairs: usages,
                locationID: existing.locationID,
                kind: existing.kind == .unknown ? device.kind : existing.kind
            )
        }
        return merged.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}

private let pointerInventoryServiceChanged: IOServiceMatchingCallback = { context, iterator in
    guard let context else { return }
    let service = Unmanaged<PointerInventoryService>.fromOpaque(context).takeUnretainedValue()
    service.handleServiceChange(iterator)
}
