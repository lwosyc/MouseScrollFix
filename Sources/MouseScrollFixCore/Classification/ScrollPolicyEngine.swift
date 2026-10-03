import Foundation

/// Everything the policy needs besides the stream class.
public struct PolicyContext: Sendable, Equatable {
    /// `com.apple.swipescrolldirection`. Missing key means natural scrolling is ON.
    /// We only ever read it.
    public var naturalScrolling: Bool
    /// True when the IORegistry inventory shows a non-built-in pointing device.
    public var hasExternalPointer: Bool
    public var settings: SettingsSnapshot

    public init(
        naturalScrolling: Bool = true,
        hasExternalPointer: Bool = false,
        settings: SettingsSnapshot = .default
    ) {
        self.naturalScrolling = naturalScrolling
        self.hasExternalPointer = hasExternalPointer
        self.settings = settings
    }

    public static let `default` = PolicyContext()
}

/// Maps a stream class to an action.
///
/// The one thing this engine must never get wrong: Apple's Natural scrolling
/// preference is a *single* shared preference for mouse and trackpad, so we cannot
/// simply "invert the mouse". We invert whichever class is currently scrolling in
/// the direction the user does not want:
///
/// * Natural ON  → the trackpad is already natural, so the mouse must be inverted.
/// * Natural OFF → the mouse is already classic, so the trackpad must be inverted.
///
/// This mirrors what the user sees in System Settings and keeps both devices correct
/// under either baseline.
public enum ScrollPolicyEngine {
    public static func action(
        for streamClass: StreamClass,
        context: PolicyContext
    ) -> ScrollAction {
        let settings = context.settings
        guard settings.mouseInversionEnabled else { return .passThrough }

        switch streamClass {
        case .unknown:
            return .passThrough

        case .trackpad:
            return naturalSurfaceAction(context)

        case .touchSurfaceOther:
            if settings.touchSurfaceWithoutMayBegin == .invert {
                return invertAction(settings)
            }
            return naturalSurfaceAction(context)

        case .wheelMouse:
            return mouseAction(context)

        case .pixelMouse:
            // Fast path: with no external pointing device the ambiguous pixel stream is
            // far more likely to be the trackpad, so protect it.
            if settings.automaticMouseDetection && !context.hasExternalPointer {
                return naturalSurfaceAction(context)
            }
            if settings.ambiguousPixelPolicy == .passThrough {
                return .passThrough
            }
            return mouseAction(context)

        case .injected:
            if settings.injectedEventsPolicy == .passThrough {
                return .passThrough
            }
            return mouseAction(context)
        }
    }

    /// Trackpad / touch surface: leave as-is when the system already shows natural
    /// scrolling, otherwise invert it to restore natural behaviour.
    private static func naturalSurfaceAction(_ context: PolicyContext) -> ScrollAction {
        context.naturalScrolling ? .passThrough : invertAction(context.settings)
    }

    /// Mouse: invert when the system baseline currently makes it natural, otherwise it
    /// already scrolls classically.
    private static func mouseAction(_ context: PolicyContext) -> ScrollAction {
        context.naturalScrolling ? invertAction(context.settings) : .passThrough
    }

    private static func invertAction(_ settings: SettingsSnapshot) -> ScrollAction {
        switch (settings.invertVertical, settings.invertHorizontal) {
        case (true, true): return .invert(.both)
        case (true, false): return .invert(.vertical)
        case (false, true): return .invert(.horizontal)
        case (false, false): return .passThrough
        }
    }
}
