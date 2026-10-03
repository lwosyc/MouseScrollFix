import Foundation
import MouseScrollFixCore

/// Shared builders so every test expresses intent, not field plumbing.
enum Fixture {
    static let t0: UInt64 = 1_000_000_000

    static func trackpadMayBegin(at t: UInt64 = Fixture.t0) -> ScrollFields {
        ScrollFields(scrollPhase: ScrollPhaseBits.mayBegin, isContinuous: true, timestamp: t)
    }

    static func trackpadBegan(
        pointV: Int64 = 0, pointH: Int64 = 0, at t: UInt64 = Fixture.t0
    ) -> ScrollFields {
        ScrollFields(
            scrollPhase: ScrollPhaseBits.began,
            isContinuous: true,
            pointDeltaAxis1: pointV,
            pointDeltaAxis2: pointH,
            timestamp: t
        )
    }

    static func trackpadChanged(
        pointV: Int64, pointH: Int64 = 0, at t: UInt64 = Fixture.t0
    ) -> ScrollFields {
        ScrollFields(
            scrollPhase: ScrollPhaseBits.changed,
            isContinuous: true,
            pointDeltaAxis1: pointV,
            pointDeltaAxis2: pointH,
            timestamp: t
        )
    }

    static func ended(phase: Int64 = ScrollPhaseBits.ended, at t: UInt64) -> ScrollFields {
        ScrollFields(scrollPhase: phase, isContinuous: true, pointDeltaAxis1: 2, timestamp: t)
    }

    /// Phase-free pixel event (high-resolution mouse wheel, or a trackpad whose phase
    /// was not delivered).
    static func pixel(v: Int64, at t: UInt64 = Fixture.t0) -> ScrollFields {
        ScrollFields(isContinuous: true, pointDeltaAxis1: v, timestamp: t)
    }

    /// Notched wheel tick: line-based, no phases. Razer Orochi V2 and friends.
    static func wheelTick(v: Int64 = 1, at t: UInt64 = Fixture.t0) -> ScrollFields {
        ScrollFields(isContinuous: false, deltaAxis1: v, timestamp: t)
    }

    /// Magic Mouse: phased, but Apple documents that it never emits `mayBegin`.
    static func touchSurfaceBegan(at t: UInt64 = Fixture.t0) -> ScrollFields {
        ScrollFields(
            scrollPhase: ScrollPhaseBits.began,
            isContinuous: true,
            pointDeltaAxis1: 3,
            timestamp: t
        )
    }

    static func momentum(_ phase: Int64, v: Int64 = 5, at t: UInt64) -> ScrollFields {
        ScrollFields(momentumPhase: phase, isContinuous: true, pointDeltaAxis1: v, timestamp: t)
    }
}

/// Baseline where natural scrolling is ON and a mouse is attached — the user's setup.
func naturalOnMouseAttached(
    _ overrides: (inout SettingsSnapshot) -> Void = { _ in }
) -> PolicyContext {
    var settings = SettingsSnapshot.default
    overrides(&settings)
    return PolicyContext(naturalScrolling: true, hasExternalPointer: true, settings: settings)
}
