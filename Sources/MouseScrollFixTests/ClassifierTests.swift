import Foundation
import MouseScrollFixCore

enum ClassifierTests {
    static func run() {
        Harness.suite("Scroll stream classifier")
        classifierCases()
        Harness.suite("Momentum ownership")
        momentumCases()
    }

    private static func classifierCases() {
        Harness.test("mayBegin is documented trackpad evidence") {
            var classifier = ScrollStreamClassifier()
            let decision = classifier.classify(Fixture.trackpadMayBegin())
            Harness.expectEqual(decision.streamClass, .trackpad)
            Harness.expectEqual(decision.reason, .trackpadMayBegin)
        }

        Harness.test("a full trackpad gesture stays a trackpad") {
            var classifier = ScrollStreamClassifier()
            _ = classifier.classify(Fixture.trackpadMayBegin(at: Fixture.t0))
            Harness.expectEqual(
                classifier.classify(Fixture.trackpadBegan(pointV: 4, at: Fixture.t0 + 1)).streamClass,
                .trackpad
            )
            Harness.expectEqual(
                classifier.classify(Fixture.trackpadChanged(pointV: 6, at: Fixture.t0 + 2)).streamClass,
                .trackpad
            )
            Harness.expectEqual(
                classifier.classify(Fixture.ended(at: Fixture.t0 + 3)).streamClass, .trackpad
            )
        }

        Harness.test("phased without mayBegin is a touch surface, not a trackpad") {
            var classifier = ScrollStreamClassifier()
            let decision = classifier.classify(Fixture.touchSurfaceBegan())
            Harness.expectEqual(decision.streamClass, .touchSurfaceOther)
            Harness.expectEqual(decision.reason, .phaseBegan)
        }

        Harness.test("a notched wheel tick is a wheel") {
            var classifier = ScrollStreamClassifier()
            let decision = classifier.classify(Fixture.wheelTick())
            Harness.expectEqual(decision.streamClass, .wheelMouse)
            Harness.expectEqual(decision.reason, .discreteLineTick)
        }

        Harness.test("phase-free pixels are a pixel mouse") {
            var classifier = ScrollStreamClassifier()
            let decision = classifier.classify(Fixture.pixel(v: 12))
            Harness.expectEqual(decision.streamClass, .pixelMouse)
            Harness.expectEqual(decision.reason, .phaseFreePixel)
        }

        Harness.test("pixels inside an active gesture stay with the trackpad") {
            var classifier = ScrollStreamClassifier()
            _ = classifier.classify(Fixture.trackpadMayBegin(at: Fixture.t0))
            _ = classifier.classify(Fixture.trackpadBegan(pointV: 4, at: Fixture.t0 + 1))
            let decision = classifier.classify(Fixture.pixel(v: 9, at: Fixture.t0 + 2))
            Harness.expectEqual(decision.streamClass, .trackpad)
            Harness.expectEqual(decision.reason, .trackpadContinuation)
        }

        Harness.test("pixels inside the grace gap after a gesture stay with the trackpad") {
            var classifier = ScrollStreamClassifier()
            _ = classifier.classify(Fixture.trackpadMayBegin(at: Fixture.t0))
            _ = classifier.classify(Fixture.trackpadBegan(pointV: 4, at: Fixture.t0 + 1))
            _ = classifier.classify(Fixture.ended(at: Fixture.t0 + 2))
            let decision = classifier.classify(Fixture.pixel(v: 7, at: Fixture.t0 + 100_000_000))
            Harness.expectEqual(decision.streamClass, .trackpad)
            Harness.expectEqual(decision.reason, .graceContinuation)
        }

        Harness.test("pixels past the grace gap are a pixel mouse") {
            var classifier = ScrollStreamClassifier()
            _ = classifier.classify(Fixture.trackpadMayBegin(at: Fixture.t0))
            _ = classifier.classify(Fixture.trackpadBegan(pointV: 4, at: Fixture.t0 + 1))
            _ = classifier.classify(Fixture.ended(at: Fixture.t0 + 2))
            Harness.expectEqual(
                classifier.classify(Fixture.pixel(v: 7, at: Fixture.t0 + 900_000_000)).streamClass,
                .pixelMouse
            )
        }

        // Regression guard for the critical failure mode: a wheel tick right after a
        // trackpad gesture must never inherit the grace window.
        Harness.test("a wheel tick right after a gesture is still a wheel") {
            var classifier = ScrollStreamClassifier()
            _ = classifier.classify(Fixture.trackpadMayBegin(at: Fixture.t0))
            _ = classifier.classify(Fixture.trackpadBegan(pointV: 4, at: Fixture.t0 + 1))
            _ = classifier.classify(Fixture.ended(at: Fixture.t0 + 2))
            let decision = classifier.classify(Fixture.wheelTick(v: 1, at: Fixture.t0 + 10_000_000))
            Harness.expectEqual(decision.streamClass, .wheelMouse)
            Harness.expectEqual(decision.reason, .discreteLineTick)
        }

        Harness.test("an event posted by another process is classified as injected") {
            var classifier = ScrollStreamClassifier()
            var fields = Fixture.wheelTick()
            fields.sourcePID = 4242
            Harness.expectEqual(classifier.classify(fields).streamClass, .injected)
        }

        Harness.test("our own synthetic events are never classified") {
            var classifier = ScrollStreamClassifier()
            var fields = Fixture.pixel(v: 10)
            fields.userData = SyntheticEventMarker.autoScroll
            let decision = classifier.classify(fields)
            Harness.expectEqual(decision.streamClass, .unknown)
            Harness.expectEqual(decision.reason, .ownSyntheticEvent)
        }

        Harness.test("a long idle period resets ownership") {
            var classifier = ScrollStreamClassifier()
            _ = classifier.classify(Fixture.trackpadMayBegin(at: Fixture.t0))
            _ = classifier.classify(Fixture.trackpadBegan(pointV: 4, at: Fixture.t0 + 1))
            let decision = classifier.classify(Fixture.pixel(v: 5, at: Fixture.t0 + 10_000_000_000))
            Harness.expectEqual(decision.streamClass, .pixelMouse)
        }

        Harness.test("a cancelled gesture clears the pending momentum owner") {
            var classifier = ScrollStreamClassifier()
            _ = classifier.classify(Fixture.trackpadMayBegin(at: Fixture.t0))
            _ = classifier.classify(Fixture.trackpadBegan(pointV: 4, at: Fixture.t0 + 1))
            _ = classifier.classify(
                Fixture.ended(phase: ScrollPhaseBits.cancelled, at: Fixture.t0 + 2)
            )
            let owner = classifier.classify(
                Fixture.momentum(MomentumPhaseValue.begin, at: Fixture.t0 + 3)
            )
            Harness.expectEqual(owner.streamClass, .unknown)
            Harness.expectEqual(owner.reason, .momentumWithoutOwner)
        }
    }

    private static func momentumCases() {
        func gesture(_ classifier: inout ScrollStreamClassifier, endAt t: UInt64) {
            _ = classifier.classify(Fixture.trackpadMayBegin(at: Fixture.t0))
            _ = classifier.classify(Fixture.trackpadBegan(pointV: 4, at: Fixture.t0 + 1))
            _ = classifier.classify(Fixture.ended(at: t))
        }

        Harness.test("momentum follows the gesture that produced it") {
            var classifier = ScrollStreamClassifier()
            gesture(&classifier, endAt: Fixture.t0 + 2)
            let begin = classifier.classify(
                Fixture.momentum(MomentumPhaseValue.begin, at: Fixture.t0 + 3)
            )
            Harness.expectEqual(begin.streamClass, .trackpad)
            Harness.expectEqual(begin.reason, .momentum)
            Harness.expectEqual(
                classifier.classify(Fixture.momentum(2, v: 4, at: Fixture.t0 + 4)).streamClass,
                .trackpad
            )
            Harness.expectEqual(
                classifier.classify(
                    Fixture.momentum(MomentumPhaseValue.end, v: 1, at: Fixture.t0 + 5)
                ).streamClass,
                .trackpad
            )
        }

        Harness.test("a wheel tick between gesture end and momentum does not steal ownership") {
            var classifier = ScrollStreamClassifier()
            gesture(&classifier, endAt: Fixture.t0 + 2)
            _ = classifier.classify(Fixture.wheelTick(v: 1, at: Fixture.t0 + 3))
            let begin = classifier.classify(
                Fixture.momentum(MomentumPhaseValue.begin, at: Fixture.t0 + 4)
            )
            Harness.expectEqual(begin.streamClass, .trackpad)
        }

        Harness.test("a long pause inside the same momentum stream keeps the owner") {
            var classifier = ScrollStreamClassifier()
            gesture(&classifier, endAt: Fixture.t0 + 2)
            _ = classifier.classify(Fixture.momentum(MomentumPhaseValue.begin, at: Fixture.t0 + 3))
            let later = classifier.classify(
                Fixture.momentum(2, v: 3, at: Fixture.t0 + 3 + 2_000_000_000)
            )
            Harness.expectEqual(later.streamClass, .trackpad)
        }

        Harness.test("a stale pending owner does not seed momentum") {
            var classifier = ScrollStreamClassifier()
            gesture(&classifier, endAt: Fixture.t0 + 2)
            let begin = classifier.classify(
                Fixture.momentum(MomentumPhaseValue.begin, at: Fixture.t0 + 5_000_000_000)
            )
            Harness.expectEqual(begin.streamClass, .unknown)
        }

        Harness.test("reset clears all ownership") {
            var classifier = ScrollStreamClassifier()
            gesture(&classifier, endAt: Fixture.t0 + 2)
            _ = classifier.classify(Fixture.momentum(MomentumPhaseValue.begin, at: Fixture.t0 + 3))
            classifier.reset()
            Harness.expect(classifier.state.isIdle, "state should be idle after reset")
            Harness.expectEqual(
                classifier.classify(Fixture.wheelTick(at: Fixture.t0 + 4)).streamClass, .wheelMouse
            )
        }
    }
}
