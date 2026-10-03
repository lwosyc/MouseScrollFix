import Foundation

/// Why the classifier decided what it decided. Surfaced by diagnostics so a user can
/// see *why* a device scrolled the way it did.
public enum ClassifierReason: String, Sendable, Equatable {
    case ownSyntheticEvent
    case momentum
    case momentumWithoutOwner
    case trackpadMayBegin
    case phaseBegan
    case phaseChanged
    case phaseEnded
    case phaseCancelled
    case injectedByProcess
    case discreteLineTick
    case trackpadContinuation
    case graceContinuation
    case phaseFreePixel
    case idleReset
}

/// The classifier's verdict for one event.
public struct ClassifierDecision: Sendable, Equatable {
    public let streamClass: StreamClass
    public let reason: ClassifierReason

    public init(streamClass: StreamClass, reason: ClassifierReason) {
        self.streamClass = streamClass
        self.reason = reason
    }
}

/// Mutable stream state. Owned exclusively by the event-tap thread.
///
/// Direct gesture ownership and momentum ownership are tracked separately on purpose:
/// a phase-free wheel tick that arrives during a trackpad's inertial tail must not
/// hijack that tail (and vice versa).
public struct ClassifierState: Sendable, Equatable {
    /// Owner of the current direct (non-momentum) gesture.
    public var directOwner: StreamClass?
    /// True between `mayBegin` and its matching `began` / terminal phase.
    public var awaitingBegin: Bool
    /// Owner of the current momentum stream.
    public var momentumOwner: StreamClass?
    /// Gesture that just ended, eligible to seed a momentum stream.
    public var pendingMomentumOwner: StreamClass?
    public var pendingMomentumAt: UInt64?
    /// Timestamp of the last terminal phase, used for the grace gap.
    public var lastGestureEndAt: UInt64?
    /// Timestamp of the last event we saw, used for idle reset.
    public var lastEventAt: UInt64?

    public init(
        directOwner: StreamClass? = nil,
        awaitingBegin: Bool = false,
        momentumOwner: StreamClass? = nil,
        pendingMomentumOwner: StreamClass? = nil,
        pendingMomentumAt: UInt64? = nil,
        lastGestureEndAt: UInt64? = nil,
        lastEventAt: UInt64? = nil
    ) {
        self.directOwner = directOwner
        self.awaitingBegin = awaitingBegin
        self.momentumOwner = momentumOwner
        self.pendingMomentumOwner = pendingMomentumOwner
        self.pendingMomentumAt = pendingMomentumAt
        self.lastGestureEndAt = lastGestureEndAt
        self.lastEventAt = lastEventAt
    }

    /// A recognised touch-surface gesture is in progress.
    public var isTouchWindowActive: Bool {
        awaitingBegin || directOwner == .trackpad || directOwner == .touchSurfaceOther
    }

    public var isIdle: Bool {
        directOwner == nil
            && momentumOwner == nil
            && pendingMomentumOwner == nil
            && !awaitingBegin
            && lastGestureEndAt == nil
    }
}
