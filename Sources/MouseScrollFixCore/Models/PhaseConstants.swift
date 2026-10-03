import Foundation

/// Documented values of `CGScrollPhase` (`CGEventTypes.h`).
public enum ScrollPhaseBits {
    public static let began: Int64 = 1
    public static let changed: Int64 = 2
    public static let ended: Int64 = 4
    public static let cancelled: Int64 = 8
    public static let mayBegin: Int64 = 128
}

/// Documented values of `CGMomentumScrollPhase` (`CGEventTypes.h`).
public enum MomentumPhaseValue {
    public static let none: Int64 = 0
    public static let begin: Int64 = 1
    public static let end: Int64 = 3
}

/// Tunables of the stream state machine. All are deliberately explicit values rather
/// than magic numbers, and all are covered by unit tests.
public struct TimingConstants: Sendable, Equatable {
    /// After a touch gesture ends, phase-free pixel events within this window are still
    /// attributed to the trackpad. Protects against misclassifying a trackpad stream
    /// whose phase was not delivered.
    public var graceGapNanos: UInt64
    /// How long a finished gesture may "seed" a following momentum stream.
    public var momentumOwnerMaxGapNanos: UInt64
    /// Idle timeout after which stream state is considered stale.
    public var idleResetNanos: UInt64

    public init(
        graceGapNanos: UInt64 = 400_000_000,
        momentumOwnerMaxGapNanos: UInt64 = 1_000_000_000,
        idleResetNanos: UInt64 = 5_000_000_000
    ) {
        self.graceGapNanos = graceGapNanos
        self.momentumOwnerMaxGapNanos = momentumOwnerMaxGapNanos
        self.idleResetNanos = idleResetNanos
    }

    public static let `default` = TimingConstants()
}
