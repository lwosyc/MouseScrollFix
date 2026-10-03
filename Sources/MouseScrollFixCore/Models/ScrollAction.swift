import Foundation

/// Which scroll axes to negate.
public enum ScrollAxisInversion: String, Sendable, Equatable {
    case vertical
    case horizontal
    case both

    public var invertsVertical: Bool { self == .vertical || self == .both }
    public var invertsHorizontal: Bool { self == .horizontal || self == .both }
}

/// The decision for one scroll event.
public enum ScrollAction: Sendable, Equatable {
    /// Leave the event exactly as it is.
    case passThrough
    /// Negate the given axes on all delta representations.
    case invert(ScrollAxisInversion)

    public var isPassThrough: Bool {
        if case .passThrough = self { return true }
        return false
    }

    public var inversion: ScrollAxisInversion? {
        if case .invert(let axes) = self { return axes }
        return nil
    }
}
