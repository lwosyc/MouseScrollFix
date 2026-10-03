import Foundation
import MouseScrollFixCore

enum MutationTests {
    private static func wheelFields() -> ScrollFields {
        ScrollFields(
            isContinuous: false,
            deltaAxis1: 1,
            deltaAxis2: -1,
            pointDeltaAxis1: 8,
            pointDeltaAxis2: -8,
            fixedPtDeltaAxis1: 0.1,
            fixedPtDeltaAxis2: -0.1,
            acceleratedDeltaAxis1: 9,
            rawDeltaAxis1: 3
        )
    }

    static func run() {
        Harness.suite("Scroll mutation plan")

        Harness.test("vertical inversion writes every representation of axis one") {
            let writes = ScrollMutationPlan.writes(for: wheelFields(), action: .invert(.vertical))
            Harness.expectEqual(
                writes.map(\.field),
                [.deltaAxis1, .pointDeltaAxis1, .fixedPtDeltaAxis1, .acceleratedDeltaAxis1, .rawDeltaAxis1]
            )
            Harness.expectEqual(writes[0].intValue, -1)
            Harness.expectEqual(writes[1].intValue, -8)
            Harness.expect(abs((writes[2].doubleValue ?? 0) - (-0.1)) < 1e-9, "fixed point axis 1")
            Harness.expect(abs((writes[3].doubleValue ?? 0) - (-9)) < 1e-9, "accelerated axis 1")
            Harness.expect(abs((writes[4].doubleValue ?? 0) - (-3)) < 1e-9, "raw axis 1")
        }

        // The ordering guarantee that keeps smooth scrolling intact: writing DeltaAxis
        // makes macOS recompute PointDelta (8x) and FixedPtDelta (1x).
        Harness.test("delta is written before point and fixed-point") {
            let writes = ScrollMutationPlan.writes(for: wheelFields(), action: .invert(.both))
            let order = writes.map(\.field)
            guard let delta1 = order.firstIndex(of: .deltaAxis1),
                  let delta2 = order.firstIndex(of: .deltaAxis2),
                  let point1 = order.firstIndex(of: .pointDeltaAxis1),
                  let point2 = order.firstIndex(of: .pointDeltaAxis2),
                  let fixed1 = order.firstIndex(of: .fixedPtDeltaAxis1)
            else {
                Harness.expect(false, "expected all representations to be written")
                return
            }
            Harness.expect(delta1 < point1, "delta1 before point1")
            Harness.expect(delta1 < fixed1, "delta1 before fixedPt1")
            Harness.expect(delta1 < delta2, "axis passes are ordered")
            Harness.expect(delta2 < point2, "delta2 before point2")
        }

        Harness.test("horizontal-only inversion touches axis two alone") {
            let writes = ScrollMutationPlan.writes(for: wheelFields(), action: .invert(.horizontal))
            Harness.expect(
                writes.allSatisfy {
                    $0.field == .deltaAxis2 || $0.field == .pointDeltaAxis2 || $0.field == .fixedPtDeltaAxis2
                },
                "axis 1 must not be written"
            )
            Harness.expectEqual(writes.first?.field, .deltaAxis2)
            Harness.expectEqual(writes.first?.intValue, 1)
        }

        Harness.test("zero representations are skipped") {
            let fields = ScrollFields(isContinuous: true, pointDeltaAxis1: 12)
            let writes = ScrollMutationPlan.writes(for: fields, action: .invert(.vertical))
            Harness.expectEqual(writes.map(\.field), [.pointDeltaAxis1])
        }

        Harness.test("pass-through produces no writes") {
            Harness.expect(
                ScrollMutationPlan.writes(for: wheelFields(), action: .passThrough).isEmpty,
                "pass-through must not write"
            )
        }

        Harness.test("integers that cannot be negated are guarded") {
            var fields = wheelFields()
            fields.deltaAxis1 = Int64.min
            fields.pointDeltaAxis1 = Int64(Int32.min)
            let writes = ScrollMutationPlan.writes(for: fields, action: .invert(.vertical))
            Harness.expect(!writes.contains { $0.field == .deltaAxis1 }, "Int64.min guarded")
            Harness.expect(!writes.contains { $0.field == .pointDeltaAxis1 }, "Int32.min guarded")
        }

        Harness.test("non-finite doubles are guarded") {
            var fields = wheelFields()
            fields.fixedPtDeltaAxis1 = .nan
            fields.acceleratedDeltaAxis1 = .infinity
            let writes = ScrollMutationPlan.writes(for: fields, action: .invert(.vertical))
            Harness.expect(!writes.contains { $0.field == .fixedPtDeltaAxis1 }, "NaN guarded")
            Harness.expect(!writes.contains { $0.field == .acceleratedDeltaAxis1 }, "Inf guarded")
            Harness.expect(writes.contains { $0.field == .rawDeltaAxis1 }, "finite field kept")
        }

        Harness.test("extended fields are omitted when unsupported") {
            let writes = ScrollMutationPlan.writes(
                for: wheelFields(), action: .invert(.vertical), supportsExtendedFields: false
            )
            Harness.expect(!writes.contains { $0.field == .acceleratedDeltaAxis1 })
            Harness.expect(!writes.contains { $0.field == .rawDeltaAxis1 })
        }

        Harness.test("an empty event produces no writes") {
            let fields = ScrollFields(isContinuous: true, timestamp: Fixture.t0)
            Harness.expect(
                ScrollMutationPlan.writes(for: fields, action: .invert(.both)).isEmpty,
                "nothing to invert"
            )
        }
    }
}
