import Foundation

/// What kind of pointing device the system reports. Derived from public IORegistry
/// properties only; never from a scroll event (which carries no device identity).
public enum PointerDeviceKind: String, Sendable, Equatable {
    case builtInTrackpad
    case externalTrackpad
    case touchSurface
    case mouse
    case unknown
}

/// One entry of the machine-wide device inventory.
public struct PointerDevice: Sendable, Equatable, Identifiable {
    /// IORegistry entry ID — stable while the device stays connected.
    public let id: UInt64
    public let name: String
    public let manufacturer: String?
    public let vendorID: Int
    public let productID: Int
    public let transport: String
    /// `kIOHIDBuiltInKey` ("Built-In"). Undocumented key; `nil` when absent.
    public let isBuiltIn: Bool?
    public let isVirtual: Bool
    public let usagePairs: [UsagePair]
    public let locationID: Int
    public let kind: PointerDeviceKind

    public struct UsagePair: Sendable, Equatable, Hashable {
        public let page: Int
        public let usage: Int
        public init(page: Int, usage: Int) {
            self.page = page
            self.usage = usage
        }
    }

    public init(
        id: UInt64,
        name: String,
        manufacturer: String?,
        vendorID: Int,
        productID: Int,
        transport: String,
        isBuiltIn: Bool?,
        isVirtual: Bool,
        usagePairs: [UsagePair],
        locationID: Int,
        kind: PointerDeviceKind
    ) {
        self.id = id
        self.name = name
        self.manufacturer = manufacturer
        self.vendorID = vendorID
        self.productID = productID
        self.transport = transport
        self.isBuiltIn = isBuiltIn
        self.isVirtual = isVirtual
        self.usagePairs = usagePairs
        self.locationID = locationID
        self.kind = kind
    }
}

/// Inventory state as a value, so it can be handed to the tap thread.
public struct InventorySnapshot: Sendable, Equatable {
    public let devices: [PointerDevice]

    public init(devices: [PointerDevice] = []) {
        self.devices = devices
    }

    public static let empty = InventorySnapshot()

    /// Any non-virtual external pointing device (mouse or external trackpad).
    public var hasExternalPointer: Bool {
        devices.contains { device in
            !device.isVirtual && device.isBuiltIn != true && device.kind != .unknown
        }
    }

    public var hasInternalTrackpad: Bool {
        devices.contains { $0.kind == .builtInTrackpad }
    }

    /// Magic Mouse and other phased touch surfaces that are not trackpads.
    public var hasTouchSurface: Bool {
        devices.contains { $0.kind == .touchSurface }
    }

    public var mice: [PointerDevice] { devices.filter { $0.kind == .mouse } }
    public var trackpads: [PointerDevice] {
        devices.filter { $0.kind == .builtInTrackpad || $0.kind == .externalTrackpad }
    }

    /// Human-readable one-liner used by the menu bar status.
    public var summary: String {
        let pointers = devices.filter { $0.kind != .unknown && !$0.isVirtual }
        if pointers.isEmpty { return "No pointing device detected" }
        return pointers.map(\.name).joined(separator: " · ")
    }
}
