import Foundation
import MouseScrollFixCore

/// End-to-end behaviour through the same pipeline the tap worker uses: the scenarios
/// from the Phase 1 contract, expressed against the real decision path.
enum ScenarioTests {
    static func run() {
        Harness.suite("Scroll behaviour scenarios")

        Harness.test("Scenario 1 — a trackpad event is never modified") {
            let pipeline = ScrollDecisionPipeline()
            var mutable = pipeline
            let context = naturalOnMouseAttached()

            var result = mutable.process(Fixture.trackpadMayBegin(at: Fixture.t0), context: context)
            Harness.expectEqual(result.streamClass, .trackpad)
            Harness.expectEqual(result.action, .passThrough)

            result = mutable.process(
                Fixture.trackpadBegan(pointV: 6, at: Fixture.t0 + 1), context: context
            )
            Harness.expectEqual(result.action, .passThrough)

            result = mutable.process(
                Fixture.trackpadChanged(pointV: 9, at: Fixture.t0 + 2), context: context
            )
            Harness.expectEqual(result.action, .passThrough)
        }

        Harness.test("Scenario 2 — mouse vertical scroll is inverted") {
            var pipeline = ScrollDecisionPipeline()
            let result = pipeline.process(Fixture.wheelTick(v: 1), context: naturalOnMouseAttached())
            Harness.expectEqual(result.streamClass, .wheelMouse)
            Harness.expectEqual(result.action, .invert(.vertical))
        }

        Harness.test("Scenario 3 — horizontal is inverted only when enabled") {
            var fields = Fixture.wheelTick(v: 1)
            fields.deltaAxis2 = 1

            var pipeline = ScrollDecisionPipeline()
            let verticalOnly = naturalOnMouseAttached {
                $0.invertVertical = true
                $0.invertHorizontal = false
            }
            var writes = ScrollMutationPlan.writes(
                for: fields, action: pipeline.process(fields, context: verticalOnly).action
            )
            Harness.expect(writes.contains { $0.field == .deltaAxis1 }, "vertical inverted")
            Harness.expect(!writes.contains { $0.field == .deltaAxis2 }, "horizontal untouched")

            pipeline = ScrollDecisionPipeline()
            let bothEnabled = naturalOnMouseAttached {
                $0.invertVertical = true
                $0.invertHorizontal = true
            }
            writes = ScrollMutationPlan.writes(
                for: fields, action: pipeline.process(fields, context: bothEnabled).action
            )
            Harness.expect(writes.contains { $0.field == .deltaAxis2 }, "horizontal inverted")
        }

        Harness.test("Scenario 4 — trackpad and mouse simultaneously get opposite handling") {
            var pipeline = ScrollDecisionPipeline()
            let context = naturalOnMouseAttached()

            _ = pipeline.process(Fixture.trackpadMayBegin(at: Fixture.t0), context: context)
            _ = pipeline.process(Fixture.trackpadBegan(pointV: 5, at: Fixture.t0 + 1), context: context)

            let mouse = pipeline.process(
                Fixture.wheelTick(v: 1, at: Fixture.t0 + 2), context: context
            )
            Harness.expectEqual(mouse.streamClass, .wheelMouse)
            Harness.expectEqual(mouse.action, .invert(.vertical))

            let trackpad = pipeline.process(
                Fixture.trackpadChanged(pointV: 7, at: Fixture.t0 + 3), context: context
            )
            Harness.expectEqual(trackpad.streamClass, .trackpad)
            Harness.expectEqual(trackpad.action, .passThrough)
        }

        Harness.test("Scenario 5 — a disconnected mouse leaves the trackpad natural") {
            var pipeline = ScrollDecisionPipeline()
            let disconnected = PolicyContext(naturalScrolling: true, hasExternalPointer: false)
            let result = pipeline.process(Fixture.pixel(v: 10), context: disconnected)
            Harness.expectEqual(result.streamClass, .pixelMouse)
            Harness.expectEqual(result.action, .passThrough)
        }

        Harness.test("Scenario 6 — a disabled app touches nothing") {
            let context = naturalOnMouseAttached { $0.mouseInversionEnabled = false }
            for fields in [Fixture.wheelTick(), Fixture.pixel(v: 9), Fixture.trackpadBegan(pointV: 4)] {
                var pipeline = ScrollDecisionPipeline()
                Harness.expectEqual(
                    pipeline.process(fields, context: context).action, .passThrough
                )
            }
        }

        Harness.test("Scenario 8 — a whole sequence, momentum included, keeps one direction") {
            var pipeline = ScrollDecisionPipeline()
            var settings = SettingsSnapshot.default
            settings.touchSurfaceWithoutMayBegin = .invert
            let context = PolicyContext(
                naturalScrolling: true, hasExternalPointer: true, settings: settings
            )

            var actions: [ScrollAction] = []
            actions.append(
                pipeline.process(Fixture.touchSurfaceBegan(at: Fixture.t0), context: context).action
            )
            actions.append(
                pipeline.process(
                    ScrollFields(
                        scrollPhase: ScrollPhaseBits.changed,
                        isContinuous: true,
                        pointDeltaAxis1: 4,
                        timestamp: Fixture.t0 + 1
                    ),
                    context: context
                ).action
            )
            actions.append(
                pipeline.process(Fixture.ended(at: Fixture.t0 + 2), context: context).action
            )
            actions.append(
                pipeline.process(
                    Fixture.momentum(MomentumPhaseValue.begin, at: Fixture.t0 + 3), context: context
                ).action
            )
            actions.append(
                pipeline.process(
                    Fixture.momentum(2, v: 3, at: Fixture.t0 + 4), context: context
                ).action
            )
            actions.append(
                pipeline.process(
                    Fixture.momentum(MomentumPhaseValue.end, v: 1, at: Fixture.t0 + 5),
                    context: context
                ).action
            )

            Harness.expectEqual(actions.count, 6, "sequence length")
            for action in actions {
                Harness.expectEqual(action, .invert(.vertical), "one direction for the whole sequence")
            }
        }
    }
}
