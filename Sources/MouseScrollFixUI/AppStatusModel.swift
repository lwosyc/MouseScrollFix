import AppKit
import Combine
import Foundation
import MouseScrollFixCore
import MouseScrollFixPlatform

public enum SettingsTab: String, Hashable, CaseIterable {
    case general
    case devices
    case diagnostics
    case about

    public func title(_ localization: Localization) -> String {
        switch self {
        case .general: return localization.text(.tabGeneral)
        case .devices: return localization.text(.tabDevices)
        case .diagnostics: return localization.text(.tabDiagnostics)
        case .about: return localization.text(.tabAbout)
        }
    }

    public func iconName() -> String {
        switch self {
        case .general: return "slider.horizontal.3"
        case .devices: return "computermouse"
        case .diagnostics: return "stethoscope"
        case .about: return "info.circle"
        }
    }
}

/// Single source of truth for the UI.
///
/// Owns the platform objects, keeps their state in sync, and republishes everything
/// SwiftUI needs. All mutation happens on the main actor; the event-tap thread only
/// ever touches `SharedRuntimeState`.
@MainActor
public final class AppStatusModel: ObservableObject {
    @Published public private(set) var tapState: ScrollEventTapWorker.State = .stopped
    @Published public private(set) var isAccessibilityTrusted = false
    @Published public private(set) var naturalScrolling = true
    @Published public private(set) var inventory: InventorySnapshot = .empty
    @Published public private(set) var counters = ScrollCounters()
    @Published public private(set) var settings: SettingsSnapshot = .default
    @Published public private(set) var launchAtLoginStatus = ""
    @Published public private(set) var tapLatencySummary: String?
    @Published public private(set) var otherTaps: [EventTapInfo] = []
    @Published public private(set) var localization: Localization
    @Published public var selectedTab: SettingsTab = .general

    public let runtime = SharedRuntimeState()
    public let settingsStore: SettingsStore
    public let tapWorker: ScrollEventTapWorker
    public let inventoryService: PointerInventoryService

    /// Invoked whenever something the menu bar displays may have changed.
    public var onStatusChanged: (() -> Void)?

    private var statusTimer: Timer?
    private var permissionTimer: Timer?

    public init(
        settingsStore: SettingsStore = SettingsStore(),
        inventoryService: PointerInventoryService = PointerInventoryService()
    ) {
        self.settingsStore = settingsStore
        self.inventoryService = inventoryService
        self.tapWorker = ScrollEventTapWorker(runtime: runtime)
        self.settings = settingsStore.snapshot
        self.localization = Localization.resolve(
            preference: settingsStore.snapshot.language,
            preferredLanguages: Locale.preferredLanguages
        )

        settingsStore.onChange = { [weak self] snapshot in
            guard let self else { return }
            self.settings = snapshot
            self.localization = Localization.resolve(
                preference: snapshot.language,
                preferredLanguages: Locale.preferredLanguages
            )
            self.runtime.setTraceEnabled(snapshot.diagnosticsTrace)
            self.pushPolicy()
            self.onStatusChanged?()
        }

        inventoryService.onChange = { [weak self] snapshot in
            guard let self else { return }
            self.inventory = snapshot
            self.pushPolicy()
            self.onStatusChanged?()
        }

        tapWorker.setStateHandler { [weak self] state in
            // The worker hands state changes over from its own thread; hop to the
            // main actor explicitly instead of assuming the caller's isolation.
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.tapState = state
                self.onStatusChanged?()
            }
        }
    }

    // MARK: Localization

    public func text(_ key: TextKey) -> String {
        localization.text(key)
    }

    public func text(_ key: TextKey, _ arguments: String...) -> String {
        localization.text(key, arguments: arguments)
    }

    // MARK: Lifecycle

    public func start() {
        runtime.setTraceEnabled(settingsStore.snapshot.diagnosticsTrace)
        pushPolicy()
        refreshSystemState()

        inventoryService.start()

        if PermissionCoordinator.isAccessibilityTrusted {
            tapWorker.start()
        } else {
            // No modal alert on launch: land in "permission required" and let the
            // onboarding window (or the menu) guide the user.
            tapState = .failed("accessibility")
        }

        inventoryService.refresh()
        startTimers()
    }

    public func shutdown() {
        statusTimer?.invalidate()
        permissionTimer?.invalidate()
        statusTimer = nil
        permissionTimer = nil
        tapWorker.stop()
        inventoryService.stop()
    }

    private func startTimers() {
        // Permission preflight values lag after a change, and a live tap is the real
        // signal. Two seconds of two boolean reads is not an input-path cost.
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pollPermission() }
        }
        statusTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshStatus() }
        }
    }

    // MARK: Actions

    public func setEnabled(_ enabled: Bool) {
        settingsStore.update { $0.mouseInversionEnabled = enabled }
        if !enabled {
            tapWorker.resetClassifier()
        }
    }

    public func toggleEnabled() {
        setEnabled(!settings.mouseInversionEnabled)
    }

    public func setInvertVertical(_ value: Bool) {
        settingsStore.update { $0.invertVertical = value }
    }

    public func setInvertHorizontal(_ value: Bool) {
        settingsStore.update { $0.invertHorizontal = value }
    }

    public func setAutomaticMouseDetection(_ value: Bool) {
        settingsStore.update { $0.automaticMouseDetection = value }
    }

    public func setAmbiguousPixelPolicy(_ value: AmbiguousPixelPolicy) {
        settingsStore.update { $0.ambiguousPixelPolicy = value }
    }

    public func setTouchSurfacePolicy(_ value: TouchSurfacePolicy) {
        settingsStore.update { $0.touchSurfaceWithoutMayBegin = value }
    }

    public func setInjectedEventsPolicy(_ value: InjectedEventsPolicy) {
        settingsStore.update { $0.injectedEventsPolicy = value }
    }

    public func setDiagnosticsTrace(_ value: Bool) {
        settingsStore.update { $0.diagnosticsTrace = value }
    }

    public func setShowMenuBarIcon(_ value: Bool) {
        settingsStore.update { $0.showMenuBarIcon = value }
    }

    public func setLanguage(_ value: AppLanguage) {
        settingsStore.update { $0.language = value }
    }

    public func markOnboardingSeen() {
        settingsStore.update { $0.hasSeenOnboarding = true }
    }

    public func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLoginService.setEnabled(enabled)
            settingsStore.update { $0.launchAtLogin = enabled }
            launchAtLoginStatus = ""
        } catch {
            launchAtLoginStatus = text(.launchAtLoginFailedFormat, error.localizedDescription)
        }
        refreshSystemState()
    }

    public func requestAccessibilityPermission() {
        PermissionCoordinator.requestAccessibilityPrompt()
    }

    public func openAccessibilitySettings() {
        PermissionCoordinator.openAccessibilitySettings()
    }

    /// Tears the tap down and builds it again from scratch.
    public func retryTap() {
        tapWorker.stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self else { return }
            self.pollPermission()
            self.tapWorker.start()
        }
    }

    public func resetCounters() {
        runtime.resetCounters()
        counters = runtime.snapshotCounters()
    }

    public func clearTrace() {
        runtime.clearTrace()
    }

    public func saveTrace(to url: URL) throws {
        try DiagnosticsService.write(trace: runtime.snapshotTrace(), to: url)
    }

    public var traceCount: Int {
        runtime.snapshotTrace().count
    }

    // MARK: Derived status

    public var isActive: Bool {
        settings.mouseInversionEnabled && tapState.isRunning
    }

    public var statusHeadline: String {
        if !settings.mouseInversionEnabled { return text(.statusOff) }
        switch tapState {
        case .running:
            return text(.statusActive)
        case .pausedByUserInput:
            return text(.statusPausedByMac)
        case .failed:
            return isAccessibilityTrusted ? text(.statusNeedsAttention) : text(.statusPermissionRequired)
        case .stopped:
            return text(.statusStarting)
        }
    }

    public var statusDetail: String {
        switch tapState {
        case .failed:
            return isAccessibilityTrusted ? text(.statusDetailTapFailed) : text(.statusDetailPermission)
        case .pausedByUserInput:
            return text(.statusDetailPaused)
        case .running:
            return text(.statusDetailFiltering)
        case .stopped:
            return text(.statusDetailStarting)
        }
    }

    public var naturalScrollingDescription: String {
        naturalScrolling ? text(.valueNaturalOn) : text(.valueNaturalOff)
    }

    public var deviceSummary: String {
        let pointers = inventory.devices.filter { $0.kind != .unknown && !$0.isVirtual }
        if pointers.isEmpty { return text(.devicesEmpty) }
        return pointers.map { describe($0).name }.joined(separator: " · ")
    }

    public var tapsDescription: String {
        tapLatencySummary ?? text(.noTapRegistered)
    }

    /// Human-readable device name plus kind, used by the menu and the device list.
    public func describe(_ device: PointerDevice) -> (name: String, kind: String) {
        let kind: String
        switch device.kind {
        case .mouse: kind = text(.kindMouse)
        case .builtInTrackpad: kind = text(.kindBuiltInTrackpad)
        case .externalTrackpad: kind = text(.kindTrackpad)
        case .touchSurface: kind = text(.kindTouchSurface)
        case .unknown: kind = text(.kindUnknown)
        }
        return (device.name, kind)
    }

    // MARK: Refresh

    public func refreshSystemState() {
        naturalScrolling = NaturalScrollingPreference.isEnabled()
        isAccessibilityTrusted = PermissionCoordinator.isAccessibilityTrusted
        launchAtLoginStatus = LaunchAtLoginService.statusDescription
        pushPolicy()
    }

    public func refreshStatus() {
        counters = runtime.snapshotCounters()
        let myPID = ProcessInfo.processInfo.processIdentifier
        let allTaps = DiagnosticsService.currentTaps()
        let taps = allTaps.filter { $0.pid == myPID }
        if let tap = taps.first {
            tapLatencySummary = text(
                .tapSummaryFormat,
                String(taps.count),
                String(format: "%.1f", tap.averageUsecLatency),
                String(format: "%.1f", tap.maximumUsecLatency)
            )
        } else {
            tapLatencySummary = nil
        }
        otherTaps = allTaps.filter { $0.pid != myPID && $0.isActiveFilter }
    }

    /// Re-resolves the language, e.g. after the user changes the macOS language.
    public func refreshLocalization() {
        localization = Localization.resolve(
            preference: settingsStore.snapshot.language,
            preferredLanguages: Locale.preferredLanguages
        )
    }

    private func pollPermission() {
        let trusted = PermissionCoordinator.isAccessibilityTrusted
        let changed = trusted != isAccessibilityTrusted
        isAccessibilityTrusted = trusted

        if !trusted, tapState.isRunning {
            // Revoking Accessibility while a tap is live is documented to be able to
            // hang input system-wide, so tear down immediately.
            tapWorker.stop()
            tapState = .failed("revoked")
            onStatusChanged?()
            return
        }
        if trusted, case .failed = tapState {
            tapWorker.start()
        }
        if changed {
            refreshSystemState()
            onStatusChanged?()
        }
    }

    private func pushPolicy() {
        runtime.updatePolicy(
            PolicyContext(
                naturalScrolling: NaturalScrollingPreference.isEnabled(),
                hasExternalPointer: inventoryService.snapshot.hasExternalPointer,
                settings: settingsStore.snapshot
            )
        )
    }
}
