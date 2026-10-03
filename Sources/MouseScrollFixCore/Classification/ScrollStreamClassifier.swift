import Foundation

/// Infers the class of a scroll stream from documented Quartz phase fields.
///
/// This type is deliberately pure: it sees only a `ScrollFields` value and its own
/// state. It has no knowledge of CoreGraphics, IOKit, the UI, or the device
/// inventory (the inventory fast path lives in `ScrollPolicyEngine`), which is what
/// makes every rule here unit-testable without hardware.
///
/// Ownership rules that matter:
/// * A touch gesture keeps ownership from `mayBegin`/`began` through its terminal
///   phase, regardless of the flags on intermediate events.
/// * Momentum belongs to the gesture that produced it, and is tracked separately
///   from direct ownership, so a wheel tick cannot steal a trackpad's tail.
/// * Discrete (line-based) ticks are never affected by the trackpad grace window,
///   so a wheel tick right after a gesture is still classified as a wheel.
public struct ScrollStreamClassifier: Sendable {
    public private(set) var state: ClassifierState
    public let timing: TimingConstants

    public init(timing: TimingConstants = .default) {
        self.timing = timing
        self.state = ClassifierState()
    }

    /// Clears all ownership. Called on tap start/stop, wake, user-input disable,
    /// settings change and inventory change.
    public mutating func reset(reason: ClassifierReason = .idleReset) {
        state = ClassifierState()
    }

    /// Classifies one event and advances the stream state.
    public mutating func classify(_ fields: ScrollFields) -> ClassifierDecision {
        // Our own synthetic events are never classified or modified.
        if SyntheticEventMarker.isOurs(fields.userData) {
            return ClassifierDecision(streamClass: .unknown, reason: .ownSyntheticEvent)
        }

        // Long idle periods invalidate ownership so a stale gesture cannot swallow a
        // later mouse wheel.
        if let last = state.lastEventAt,
           fields.timestamp > last,
           fields.timestamp - last > timing.idleResetNanos {
            state = ClassifierState(lastEventAt: fields.timestamp)
        } else {
            state.lastEventAt = fields.timestamp
        }

        let phase = fields.scrollPhase
        let momentum = fields.momentumPhase

        // 1. Momentum continues the stream that produced it.
        if momentum != MomentumPhaseValue.none {
            return classifyMomentum(fields, momentum: momentum)
        }

        // 2. `mayBegin` is documented trackpad evidence and arrives before `began`.
        if phase & ScrollPhaseBits.mayBegin != 0 {
            state.directOwner = .trackpad
            state.awaitingBegin = true
            state.pendingMomentumOwner = nil
            state.pendingMomentumAt = nil
            return ClassifierDecision(streamClass: .trackpad, reason: .trackpadMayBegin)
        }

        // 3. `began` with no pending `mayBegin` is a phased touch surface that does not
        //    emit `mayBegin` — Apple documents this for Magic Mouse.
        if phase & ScrollPhaseBits.began != 0 {
            let owner: StreamClass = state.awaitingBegin ? .trackpad : .touchSurfaceOther
            state.directOwner = owner
            state.awaitingBegin = false
            state.pendingMomentumOwner = nil
            state.pendingMomentumAt = nil
            return ClassifierDecision(streamClass: owner, reason: .phaseBegan)
        }

        // 4. Remaining phases keep the current owner, and end it when terminal.
        if phase != 0 {
            if state.awaitingBegin {
                // Some streams omit `began`; the pending phase still owns the stream.
                state.directOwner = .trackpad
                state.awaitingBegin = false
            }
            let owner = state.directOwner ?? .touchSurfaceOther
            if phase & ScrollPhaseBits.ended != 0 {
                state.pendingMomentumOwner = owner
                state.pendingMomentumAt = fields.timestamp
                state.lastGestureEndAt = fields.timestamp
                state.directOwner = nil
                state.awaitingBegin = false
                return ClassifierDecision(streamClass: owner, reason: .phaseEnded)
            }
            if phase & ScrollPhaseBits.cancelled != 0 {
                state.directOwner = nil
                state.awaitingBegin = false
                state.pendingMomentumOwner = nil
                state.pendingMomentumAt = nil
                state.lastGestureEndAt = fields.timestamp
                return ClassifierDecision(streamClass: owner, reason: .phaseCancelled)
            }
            return ClassifierDecision(streamClass: owner, reason: .phaseChanged)
        }

        // 5. Posted by another user-space process: apply the injected-events policy.
        if fields.sourcePID != 0 {
            return ClassifierDecision(streamClass: .injected, reason: .injectedByProcess)
        }

        // 6. Line-based deltas are a wheel. This check sits above the grace window on
        //    purpose: a notched wheel tick is never mistaken for a trackpad tail.
        if !fields.isContinuous {
            return ClassifierDecision(streamClass: .wheelMouse, reason: .discreteLineTick)
        }

        // 7. Pixel-based and phase-free: either a trackpad whose phase we missed, or a
        //    high-resolution mouse wheel. Protect an in-flight trackpad stream first.
        if state.directOwner == .trackpad || state.awaitingBegin {
            return ClassifierDecision(streamClass: .trackpad, reason: .trackpadContinuation)
        }
        if let lastEnd = state.lastGestureEndAt,
           fields.timestamp >= lastEnd,
           fields.timestamp - lastEnd <= timing.graceGapNanos {
            return ClassifierDecision(streamClass: .trackpad, reason: .graceContinuation)
        }
        return ClassifierDecision(streamClass: .pixelMouse, reason: .phaseFreePixel)
    }

    private mutating func classifyMomentum(
        _ fields: ScrollFields,
        momentum: Int64
    ) -> ClassifierDecision {
        if momentum == MomentumPhaseValue.begin || state.momentumOwner == nil {
            let isFresh: Bool
            if let at = state.pendingMomentumAt {
                isFresh = fields.timestamp >= at
                    && fields.timestamp - at <= timing.momentumOwnerMaxGapNanos
            } else {
                isFresh = false
            }
            state.momentumOwner = isFresh ? state.pendingMomentumOwner : nil
            state.pendingMomentumOwner = nil
            state.pendingMomentumAt = nil
        }

        let owner = state.momentumOwner ?? .unknown

        if momentum == MomentumPhaseValue.end {
            state.momentumOwner = nil
            state.pendingMomentumOwner = nil
            state.pendingMomentumAt = nil
        }

        return ClassifierDecision(
            streamClass: owner,
            reason: owner == .unknown ? .momentumWithoutOwner : .momentum
        )
    }
}
