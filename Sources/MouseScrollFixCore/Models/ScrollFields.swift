import Foundation

/// Immutable snapshot of the `CGEventField` values we read from one scroll event.
///
/// Keeping this as a plain value type is what makes the classifier and the policy
/// engine testable without hardware: the platform layer reads the event, Core
/// decides, the platform layer writes.
public struct ScrollFields: Sendable, Equatable {
    /// `kCGScrollWheelEventScrollPhase`: began=1, changed=2, ended=4, cancelled=8, mayBegin=128.
    public var scrollPhase: Int64
    /// `kCGScrollWheelEventMomentumPhase`: none=0, begin=1, continue=2, end=3.
    public var momentumPhase: Int64
    /// `kCGScrollWheelEventIsContinuous`: true = pixel-based, false = line-based.
    /// Describes the *encoding*, not the device.
    public var isContinuous: Bool

    /// `kCGScrollWheelEventDeltaAxis1` — vertical, line-based counter.
    public var deltaAxis1: Int64
    /// `kCGScrollWheelEventDeltaAxis2` — horizontal, line-based counter.
    public var deltaAxis2: Int64

    /// `kCGScrollWheelEventPointDeltaAxis1` — vertical, pixel-based.
    public var pointDeltaAxis1: Int64
    /// `kCGScrollWheelEventPointDeltaAxis2` — horizontal, pixel-based.
    public var pointDeltaAxis2: Int64

    /// `kCGScrollWheelEventFixedPtDeltaAxis1` — 16.16 fixed point, read as Double.
    public var fixedPtDeltaAxis1: Double
    /// `kCGScrollWheelEventFixedPtDeltaAxis2` — 16.16 fixed point, read as Double.
    public var fixedPtDeltaAxis2: Double

    /// `kCGScrollWheelEventAcceleratedDeltaAxis1` (newer field; 0 when absent).
    public var acceleratedDeltaAxis1: Double
    /// `kCGScrollWheelEventRawDeltaAxis1` (newer field; 0 when absent).
    public var rawDeltaAxis1: Double

    /// `kCGEventSourceUnixProcessID`. Non-zero means a user-space process posted it.
    public var sourcePID: Int64
    /// `kCGEventSourceUserData` — used as our own synthetic-event marker.
    public var userData: Int64

    /// Event timestamp in nanoseconds (`CGEventGetTimestamp`), used for stream state.
    public var timestamp: UInt64

    public init(
        scrollPhase: Int64 = 0,
        momentumPhase: Int64 = 0,
        isContinuous: Bool = false,
        deltaAxis1: Int64 = 0,
        deltaAxis2: Int64 = 0,
        pointDeltaAxis1: Int64 = 0,
        pointDeltaAxis2: Int64 = 0,
        fixedPtDeltaAxis1: Double = 0,
        fixedPtDeltaAxis2: Double = 0,
        acceleratedDeltaAxis1: Double = 0,
        rawDeltaAxis1: Double = 0,
        sourcePID: Int64 = 0,
        userData: Int64 = 0,
        timestamp: UInt64 = 0
    ) {
        self.scrollPhase = scrollPhase
        self.momentumPhase = momentumPhase
        self.isContinuous = isContinuous
        self.deltaAxis1 = deltaAxis1
        self.deltaAxis2 = deltaAxis2
        self.pointDeltaAxis1 = pointDeltaAxis1
        self.pointDeltaAxis2 = pointDeltaAxis2
        self.fixedPtDeltaAxis1 = fixedPtDeltaAxis1
        self.fixedPtDeltaAxis2 = fixedPtDeltaAxis2
        self.acceleratedDeltaAxis1 = acceleratedDeltaAxis1
        self.rawDeltaAxis1 = rawDeltaAxis1
        self.sourcePID = sourcePID
        self.userData = userData
        self.timestamp = timestamp
    }

    /// True when every representation of both axes is zero: nothing to invert.
    public var hasNoMagnitude: Bool {
        deltaAxis1 == 0 && deltaAxis2 == 0
            && pointDeltaAxis1 == 0 && pointDeltaAxis2 == 0
            && fixedPtDeltaAxis1 == 0 && fixedPtDeltaAxis2 == 0
            && acceleratedDeltaAxis1 == 0 && rawDeltaAxis1 == 0
    }
}
