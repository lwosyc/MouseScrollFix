import Foundation
import MouseScrollFixCore

/// Persists user settings in the app's own domain and publishes immutable snapshots.
///
/// Main-thread confined by contract (the app calls it from the main actor). It never
/// writes to any system domain: `com.apple.swipescrolldirection` is read-only for us.
public final class SettingsStore {
    private enum Key {
        static let mouseInversionEnabled = "msf.mouseInversionEnabled"
        static let invertVertical = "msf.invertVertical"
        static let invertHorizontal = "msf.invertHorizontal"
        static let automaticMouseDetection = "msf.automaticMouseDetection"
        static let ambiguousPixelPolicy = "msf.ambiguousPixelPolicy"
        static let touchSurfacePolicy = "msf.touchSurfaceWithoutMayBegin"
        static let injectedEventsPolicy = "msf.injectedEventsPolicy"
        static let launchAtLogin = "msf.launchAtLogin"
        static let showMenuBarIcon = "msf.showMenuBarIcon"
        static let diagnosticsTrace = "msf.diagnosticsTrace"
        static let language = "msf.language"
        static let hasSeenOnboarding = "msf.hasSeenOnboarding"
        static let schemaVersion = "msf.schemaVersion"
    }

    private static let currentSchemaVersion = 2

    private let defaults: UserDefaults
    public private(set) var snapshot: SettingsSnapshot

    /// Called after every change, with the new snapshot.
    public var onChange: ((SettingsSnapshot) -> Void)?

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.snapshot = SettingsSnapshot.default
        load()
    }

    // MARK: Mutation

    public func update(_ mutate: (inout SettingsSnapshot) -> Void) {
        var next = snapshot
        mutate(&next)
        guard next != snapshot else { return }
        snapshot = next
        persist()
        onChange?(next)
    }

    public func resetToDefaults() {
        snapshot = SettingsSnapshot.default
        persist()
        onChange?(snapshot)
    }

    // MARK: Persistence

    private func load() {
        if defaults.object(forKey: Key.schemaVersion) == nil {
            // First launch: keep the documented defaults and write them once.
            persist()
            return
        }

        var loaded = SettingsSnapshot.default
        if defaults.object(forKey: Key.mouseInversionEnabled) != nil {
            loaded.mouseInversionEnabled = defaults.bool(forKey: Key.mouseInversionEnabled)
        }
        if defaults.object(forKey: Key.invertVertical) != nil {
            loaded.invertVertical = defaults.bool(forKey: Key.invertVertical)
        }
        if defaults.object(forKey: Key.invertHorizontal) != nil {
            loaded.invertHorizontal = defaults.bool(forKey: Key.invertHorizontal)
        }
        if defaults.object(forKey: Key.automaticMouseDetection) != nil {
            loaded.automaticMouseDetection = defaults.bool(forKey: Key.automaticMouseDetection)
        }
        if let raw = defaults.string(forKey: Key.ambiguousPixelPolicy),
           let value = AmbiguousPixelPolicy(rawValue: raw) {
            loaded.ambiguousPixelPolicy = value
        }
        if let raw = defaults.string(forKey: Key.touchSurfacePolicy),
           let value = TouchSurfacePolicy(rawValue: raw) {
            loaded.touchSurfaceWithoutMayBegin = value
        }
        if let raw = defaults.string(forKey: Key.injectedEventsPolicy),
           let value = InjectedEventsPolicy(rawValue: raw) {
            loaded.injectedEventsPolicy = value
        }
        if defaults.object(forKey: Key.launchAtLogin) != nil {
            loaded.launchAtLogin = defaults.bool(forKey: Key.launchAtLogin)
        }
        if defaults.object(forKey: Key.showMenuBarIcon) != nil {
            loaded.showMenuBarIcon = defaults.bool(forKey: Key.showMenuBarIcon)
        }
        if defaults.object(forKey: Key.diagnosticsTrace) != nil {
            loaded.diagnosticsTrace = defaults.bool(forKey: Key.diagnosticsTrace)
        }
        if let raw = defaults.string(forKey: Key.language),
           let value = AppLanguage(rawValue: raw) {
            loaded.language = value
        }
        if defaults.object(forKey: Key.hasSeenOnboarding) != nil {
            loaded.hasSeenOnboarding = defaults.bool(forKey: Key.hasSeenOnboarding)
        }
        snapshot = loaded
        persist()
    }

    private func persist() {
        defaults.set(Self.currentSchemaVersion, forKey: Key.schemaVersion)
        defaults.set(snapshot.mouseInversionEnabled, forKey: Key.mouseInversionEnabled)
        defaults.set(snapshot.invertVertical, forKey: Key.invertVertical)
        defaults.set(snapshot.invertHorizontal, forKey: Key.invertHorizontal)
        defaults.set(snapshot.automaticMouseDetection, forKey: Key.automaticMouseDetection)
        defaults.set(snapshot.ambiguousPixelPolicy.rawValue, forKey: Key.ambiguousPixelPolicy)
        defaults.set(snapshot.touchSurfaceWithoutMayBegin.rawValue, forKey: Key.touchSurfacePolicy)
        defaults.set(snapshot.injectedEventsPolicy.rawValue, forKey: Key.injectedEventsPolicy)
        defaults.set(snapshot.launchAtLogin, forKey: Key.launchAtLogin)
        defaults.set(snapshot.showMenuBarIcon, forKey: Key.showMenuBarIcon)
        defaults.set(snapshot.diagnosticsTrace, forKey: Key.diagnosticsTrace)
        defaults.set(snapshot.language.rawValue, forKey: Key.language)
        defaults.set(snapshot.hasSeenOnboarding, forKey: Key.hasSeenOnboarding)
    }
}
