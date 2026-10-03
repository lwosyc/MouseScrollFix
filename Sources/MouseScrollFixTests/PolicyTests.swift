import Foundation
import MouseScrollFixCore

enum PolicyTests {
    static func run() {
        Harness.suite("Scroll policy engine")

        Harness.test("trackpad is untouched while natural scrolling is on") {
            Harness.expectEqual(
                ScrollPolicyEngine.action(for: .trackpad, context: naturalOnMouseAttached()),
                .passThrough
            )
        }

        Harness.test("trackpad is inverted to restore natural scrolling when the system has it off") {
            let context = PolicyContext(naturalScrolling: false, hasExternalPointer: true)
            Harness.expectEqual(
                ScrollPolicyEngine.action(for: .trackpad, context: context), .invert(.vertical)
            )
        }

        Harness.test("wheel mouse is inverted while natural scrolling is on") {
            Harness.expectEqual(
                ScrollPolicyEngine.action(for: .wheelMouse, context: naturalOnMouseAttached()),
                .invert(.vertical)
            )
        }

        Harness.test("wheel mouse is untouched when the system already scrolls classically") {
            let context = PolicyContext(naturalScrolling: false, hasExternalPointer: true)
            Harness.expectEqual(
                ScrollPolicyEngine.action(for: .wheelMouse, context: context), .passThrough
            )
        }

        Harness.test("phase-free pixels are inverted when a mouse is attached") {
            Harness.expectEqual(
                ScrollPolicyEngine.action(for: .pixelMouse, context: naturalOnMouseAttached()),
                .invert(.vertical)
            )
        }

        Harness.test("phase-free pixels are protected when no mouse is attached") {
            let context = PolicyContext(naturalScrolling: true, hasExternalPointer: false)
            Harness.expectEqual(
                ScrollPolicyEngine.action(for: .pixelMouse, context: context), .passThrough
            )
        }

        Harness.test("conservative mode passes ambiguous pixels through") {
            let context = naturalOnMouseAttached { $0.ambiguousPixelPolicy = .passThrough }
            Harness.expectEqual(
                ScrollPolicyEngine.action(for: .pixelMouse, context: context), .passThrough
            )
        }

        Harness.test("manual detection overrides the device fast path") {
            let context = naturalOnMouseAttached {
                $0.automaticMouseDetection = false
                $0.ambiguousPixelPolicy = .treatAsMouse
            }
            Harness.expectEqual(
                ScrollPolicyEngine.action(for: .pixelMouse, context: context), .invert(.vertical)
            )
        }

        Harness.test("Magic Mouse stays natural by default") {
            Harness.expectEqual(
                ScrollPolicyEngine.action(for: .touchSurfaceOther, context: naturalOnMouseAttached()),
                .passThrough
            )
        }

        Harness.test("Magic Mouse can be inverted on request") {
            let context = naturalOnMouseAttached { $0.touchSurfaceWithoutMayBegin = .invert }
            Harness.expectEqual(
                ScrollPolicyEngine.action(for: .touchSurfaceOther, context: context),
                .invert(.vertical)
            )
        }

        Harness.test("injected events are treated as mouse by default") {
            Harness.expectEqual(
                ScrollPolicyEngine.action(for: .injected, context: naturalOnMouseAttached()),
                .invert(.vertical)
            )
        }

        Harness.test("injected events can pass through") {
            let context = naturalOnMouseAttached { $0.injectedEventsPolicy = .passThrough }
            Harness.expectEqual(
                ScrollPolicyEngine.action(for: .injected, context: context), .passThrough
            )
        }

        Harness.test("the master switch disables every class") {
            let context = naturalOnMouseAttached { $0.mouseInversionEnabled = false }
            for streamClass in StreamClass.allCases {
                Harness.expectEqual(
                    ScrollPolicyEngine.action(for: streamClass, context: context),
                    .passThrough,
                    "pass-through for \(streamClass.rawValue)"
                )
            }
        }

        Harness.test("unknown streams are never acted upon") {
            Harness.expectEqual(
                ScrollPolicyEngine.action(for: .unknown, context: naturalOnMouseAttached()),
                .passThrough
            )
        }

        Harness.test("axis toggles produce the expected inversions") {
            let both = naturalOnMouseAttached {
                $0.invertVertical = true
                $0.invertHorizontal = true
            }
            Harness.expectEqual(
                ScrollPolicyEngine.action(for: .wheelMouse, context: both), .invert(.both)
            )

            let horizontalOnly = naturalOnMouseAttached {
                $0.invertVertical = false
                $0.invertHorizontal = true
            }
            Harness.expectEqual(
                ScrollPolicyEngine.action(for: .wheelMouse, context: horizontalOnly),
                .invert(.horizontal)
            )

            let neither = naturalOnMouseAttached {
                $0.invertVertical = false
                $0.invertHorizontal = false
            }
            Harness.expectEqual(
                ScrollPolicyEngine.action(for: .wheelMouse, context: neither), .passThrough
            )
        }
    }
}
