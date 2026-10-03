import Foundation

/// Policy for pixel-based, phase-free streams (high-resolution and free-spinning
/// wheels, and mice whose vendor driver emits pixel deltas).
public enum AmbiguousPixelPolicy: String, Sendable, Equatable, CaseIterable {
    /// Treat as mouse and invert. This is what makes "any mouse macOS recognises"
    /// work, including high-resolution wheels.
    case treatAsMouse
    /// Leave untouched. Conservative: never risks touching a trackpad, but such a
    /// mouse will not be inverted.
    case passThrough
}

/// Policy for phased streams that never emitted `mayBegin` (Magic Mouse).
public enum TouchSurfacePolicy: String, Sendable, Equatable, CaseIterable {
    /// Keep natural scrolling, like a trackpad. Magic Mouse has no notched wheel.
    case keepNatural
    /// Treat as a mouse and invert.
    case invert
}

/// Policy for events posted by another user-space process.
public enum InjectedEventsPolicy: String, Sendable, Equatable, CaseIterable {
    case treatAsMouse
    case passThrough
}

/// Immutable snapshot of user settings, handed to the tap thread.
public struct SettingsSnapshot: Sendable, Equatable {
    public var mouseInversionEnabled: Bool
    public var invertVertical: Bool
    public var invertHorizontal: Bool
    public var automaticMouseDetection: Bool
    public var ambiguousPixelPolicy: AmbiguousPixelPolicy
    public var touchSurfaceWithoutMayBegin: TouchSurfacePolicy
    public var injectedEventsPolicy: InjectedEventsPolicy
    public var launchAtLogin: Bool
    public var showMenuBarIcon: Bool
    public var diagnosticsTrace: Bool
    /// `.system` follows the macOS language list.
    public var language: AppLanguage
    /// True once the permission/onboarding window has been shown at least once.
    public var hasSeenOnboarding: Bool

    public init(
        mouseInversionEnabled: Bool = true,
        invertVertical: Bool = true,
        invertHorizontal: Bool = false,
        automaticMouseDetection: Bool = true,
        ambiguousPixelPolicy: AmbiguousPixelPolicy = .treatAsMouse,
        touchSurfaceWithoutMayBegin: TouchSurfacePolicy = .keepNatural,
        injectedEventsPolicy: InjectedEventsPolicy = .treatAsMouse,
        launchAtLogin: Bool = false,
        showMenuBarIcon: Bool = true,
        diagnosticsTrace: Bool = false,
        language: AppLanguage = .system,
        hasSeenOnboarding: Bool = false
    ) {
        self.mouseInversionEnabled = mouseInversionEnabled
        self.invertVertical = invertVertical
        self.invertHorizontal = invertHorizontal
        self.automaticMouseDetection = automaticMouseDetection
        self.ambiguousPixelPolicy = ambiguousPixelPolicy
        self.touchSurfaceWithoutMayBegin = touchSurfaceWithoutMayBegin
        self.injectedEventsPolicy = injectedEventsPolicy
        self.launchAtLogin = launchAtLogin
        self.showMenuBarIcon = showMenuBarIcon
        self.diagnosticsTrace = diagnosticsTrace
        self.language = language
        self.hasSeenOnboarding = hasSeenOnboarding
    }

    public static let `default` = SettingsSnapshot()
}
