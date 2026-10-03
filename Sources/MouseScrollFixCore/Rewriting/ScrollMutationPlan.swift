import Foundation

/// The scroll-event fields this app ever writes.
public enum MutationField: String, Sendable, Equatable {
    case deltaAxis1
    case deltaAxis2
    case pointDeltaAxis1
    case pointDeltaAxis2
    case fixedPtDeltaAxis1
    case fixedPtDeltaAxis2
    case acceleratedDeltaAxis1
    case rawDeltaAxis1
}

/// One field write, already validated.
public struct FieldWrite: Sendable, Equatable {
    public let field: MutationField
    public let intValue: Int64?
    public let doubleValue: Double?

    public init(field: MutationField, intValue: Int64) {
        self.field = field
        self.intValue = intValue
        self.doubleValue = nil
    }

    public init(field: MutationField, doubleValue: Double) {
        self.field = field
        self.intValue = nil
        self.doubleValue = doubleValue
    }
}

/// Decides exactly which fields to write and in which order.
///
/// Order is not cosmetic. Writing `DeltaAxis` makes macOS internally recompute
/// `PointDeltaAxis` (8x) and `FixedPtDeltaAxis` (1x), so the point and fixed-point
/// representations must be written *after* the integer delta — otherwise smooth
/// scrolling is lost. Each representation is written only when it carries a non-zero
/// magnitude, so a pixel-only event never has its integer delta touched.
public enum ScrollMutationPlan {
    public static func writes(
        for fields: ScrollFields,
        action: ScrollAction,
        supportsExtendedFields: Bool = true
    ) -> [FieldWrite] {
        guard let axes = action.inversion, !fields.hasNoMagnitude else { return [] }

        var writes: [FieldWrite] = []

        // Pass 1 — line-based integer deltas (must land first).
        appendInt(&writes, fields.deltaAxis1, axes.invertsVertical, .deltaAxis1)
        appendInt(&writes, fields.deltaAxis2, axes.invertsHorizontal, .deltaAxis2)

        // Pass 2 — pixel-based integer deltas.
        appendPoint(&writes, fields.pointDeltaAxis1, axes.invertsVertical, .pointDeltaAxis1)
        appendPoint(&writes, fields.pointDeltaAxis2, axes.invertsHorizontal, .pointDeltaAxis2)

        // Pass 3 — fixed-point representations.
        appendDouble(&writes, fields.fixedPtDeltaAxis1, axes.invertsVertical, .fixedPtDeltaAxis1)
        appendDouble(&writes, fields.fixedPtDeltaAxis2, axes.invertsHorizontal, .fixedPtDeltaAxis2)

        // Pass 4 — newer helper fields, only when this OS populates them.
        if supportsExtendedFields {
            appendDouble(
                &writes, fields.acceleratedDeltaAxis1, axes.invertsVertical, .acceleratedDeltaAxis1
            )
            appendDouble(&writes, fields.rawDeltaAxis1, axes.invertsVertical, .rawDeltaAxis1)
        }

        return writes
    }

    private static func appendInt(
        _ writes: inout [FieldWrite],
        _ value: Int64,
        _ enabled: Bool,
        _ field: MutationField
    ) {
        guard enabled, value != 0, value != Int64.min else { return }
        writes.append(FieldWrite(field: field, intValue: -value))
    }

    private static func appendPoint(
        _ writes: inout [FieldWrite],
        _ value: Int64,
        _ enabled: Bool,
        _ field: MutationField
    ) {
        // Point deltas are stored in a 32-bit slot; Int32.min cannot be negated.
        guard enabled, value != 0, value != Int64.min, value != Int64(Int32.min) else { return }
        writes.append(FieldWrite(field: field, intValue: -value))
    }

    private static func appendDouble(
        _ writes: inout [FieldWrite],
        _ value: Double,
        _ enabled: Bool,
        _ field: MutationField
    ) {
        guard enabled, value != 0, value.isFinite else { return }
        writes.append(FieldWrite(field: field, doubleValue: -value))
    }
}
