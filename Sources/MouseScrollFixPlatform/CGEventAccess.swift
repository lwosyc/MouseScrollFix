import CoreGraphics
import Foundation
import MouseScrollFixCore

/// Reads and writes the `CGEventField` values of a scroll event.
///
/// Read side: everything the classifier needs, as a plain `ScrollFields` value.
/// Write side: applies a `ScrollMutationPlan` in the order the plan prescribes —
/// `DeltaAxis` first, then the point and fixed-point representations, because writing
/// `DeltaAxis` makes macOS recompute the others.
enum CGEventAccess {
    /// Field availability differs across releases; the extended fields are simply
    /// absent (and read as zero) on older systems.
    static let supportsExtendedFields = true

    static func readFields(from event: CGEvent) -> ScrollFields {
        ScrollFields(
            scrollPhase: event.getIntegerValueField(.scrollWheelEventScrollPhase),
            momentumPhase: event.getIntegerValueField(.scrollWheelEventMomentumPhase),
            isContinuous: event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0,
            deltaAxis1: event.getIntegerValueField(.scrollWheelEventDeltaAxis1),
            deltaAxis2: event.getIntegerValueField(.scrollWheelEventDeltaAxis2),
            pointDeltaAxis1: event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1),
            pointDeltaAxis2: event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2),
            fixedPtDeltaAxis1: event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1),
            fixedPtDeltaAxis2: event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2),
            acceleratedDeltaAxis1: supportsExtendedFields
                ? event.getDoubleValueField(.scrollWheelEventAcceleratedDeltaAxis1) : 0,
            rawDeltaAxis1: supportsExtendedFields
                ? event.getDoubleValueField(.scrollWheelEventRawDeltaAxis1) : 0,
            sourcePID: event.getIntegerValueField(.eventSourceUnixProcessID),
            userData: event.getIntegerValueField(.eventSourceUserData),
            timestamp: event.timestamp
        )
    }

    /// Applies validated writes. Returns true when the event was actually modified.
    @discardableResult
    static func apply(_ writes: [FieldWrite], to event: CGEvent) -> Bool {
        guard !writes.isEmpty else { return false }
        for write in writes {
            switch write.field {
            case .deltaAxis1:
                guard let value = write.intValue else { continue }
                event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: value)
            case .deltaAxis2:
                guard let value = write.intValue else { continue }
                event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: value)
            case .pointDeltaAxis1:
                guard let value = write.intValue else { continue }
                event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: value)
            case .pointDeltaAxis2:
                guard let value = write.intValue else { continue }
                event.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: value)
            case .fixedPtDeltaAxis1:
                guard let value = write.doubleValue else { continue }
                event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: value)
            case .fixedPtDeltaAxis2:
                guard let value = write.doubleValue else { continue }
                event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: value)
            case .acceleratedDeltaAxis1:
                guard let value = write.doubleValue, supportsExtendedFields else { continue }
                event.setDoubleValueField(.scrollWheelEventAcceleratedDeltaAxis1, value: value)
            case .rawDeltaAxis1:
                guard let value = write.doubleValue, supportsExtendedFields else { continue }
                event.setDoubleValueField(.scrollWheelEventRawDeltaAxis1, value: value)
            }
        }
        return true
    }
}
