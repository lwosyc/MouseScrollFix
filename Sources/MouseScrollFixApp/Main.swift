import AppKit
import Foundation
import MouseScrollFixCore
import MouseScrollFixPlatform

/// Entry point.
///
/// `@main` with an explicitly main-actor-isolated `main()` rather than top-level code,
/// so the app delegate and the status model stay inside the main actor from the first
/// line. Accessory activation policy means menu bar only — no Dock icon — and makes the
/// binary behave identically under `swift run` and from an .app bundle.
@main
struct MouseScrollFixMain {
    @MainActor private static var appDelegate: AppDelegate?

    @MainActor
    static func main() {
        // Headless diagnostics. Handy from a terminal and used to verify the device
        // inventory and permission state without touching the UI.
        if let mode = CommandLine.arguments.first(where: { $0.hasPrefix("--") }) {
            runDiagnostic(mode: mode)
            return
        }

        let application = NSApplication.shared
        let delegate = AppDelegate()
        appDelegate = delegate
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
    }

    private static func runDiagnostic(mode: String) {
        switch mode {
        case "--dump-devices":
            let service = PointerInventoryService()
            service.refresh()
            let snapshot = service.snapshot
            print("hasExternalPointer: \(snapshot.hasExternalPointer)")
            print("hasInternalTrackpad: \(snapshot.hasInternalTrackpad)")
            print("hasTouchSurface: \(snapshot.hasTouchSurface)")
            print("devices: \(snapshot.devices.count)")
            for device in snapshot.devices {
                let builtIn = device.isBuiltIn.map { $0 ? "yes" : "no" } ?? "?"
                print(
                    "  - \(device.name) | kind=\(device.kind.rawValue) | "
                        + String(format: "VID=0x%04X PID=0x%04X", device.vendorID, device.productID)
                        + " | transport=\(device.transport.isEmpty ? "?" : device.transport)"
                        + " | builtIn=\(builtIn) | virtual=\(device.isVirtual)"
                        + " | usages=\(device.usagePairs.map { String(format: "%02X/%02X", $0.page, $0.usage) }.joined(separator: ","))"
                )
            }
        case "--dump-status":
            print("accessibilityTrusted: \(PermissionCoordinator.isAccessibilityTrusted)")
            print("naturalScrolling: \(NaturalScrollingPreference.isEnabled())")
            print("launchAtLogin: \(LaunchAtLoginService.statusDescription)")
            let myPID = ProcessInfo.processInfo.processIdentifier
            let taps = DiagnosticsService.currentTaps()
            print("eventTaps(total): \(taps.count), ours: \(taps.filter { $0.pid == myPID }.count)")
            print("hasActiveScrollTap(ours): \(DiagnosticsService.hasActiveScrollTap(ownedBy: myPID))")

            let localization = Localization.resolve(
                preference: SettingsStore().snapshot.language,
                preferredLanguages: Locale.preferredLanguages
            )
            print("preferredLanguages: \(Locale.preferredLanguages.prefix(3).joined(separator: ", "))")
            print("language: \(localization.language.code) — \(localization.language.displayName)")
            print("sample[onboarding.title]: \(localization.text(.onboardingTitle))")
            print("sample[onboarding.openSettings]: \(localization.text(.onboardingButtonOpenSettings))")
            print("sample[status.permissionRequired]: \(localization.text(.statusPermissionRequired))")
            print("sample[lang]: \(localization.text(.pickerLanguage))")
        case "--dump-policy":
            let service = PointerInventoryService()
            service.refresh()
            let settings = SettingsSnapshot.default
            let context = PolicyContext(
                naturalScrolling: NaturalScrollingPreference.isEnabled(),
                hasExternalPointer: service.snapshot.hasExternalPointer,
                settings: settings
            )
            print("naturalScrolling: \(context.naturalScrolling)")
            print("hasExternalPointer: \(context.hasExternalPointer)")
            for streamClass in StreamClass.allCases {
                let action = ScrollPolicyEngine.action(for: streamClass, context: context)
                print("  \(streamClass.rawValue) -> \(action)")
            }
        case "--help", "--dump-help":
            print(
                """
                MouseScrollFix — natural trackpad, classic mouse scrolling.

                Usage:
                  MouseScrollFix                 run the menu bar app
                  MouseScrollFix --dump-devices  list pointing devices from the I/O Registry
                  MouseScrollFix --dump-status   show permissions, preference and event taps
                  MouseScrollFix --dump-policy   show the decision for every stream class
                  MouseScrollFix --help          this text
                """
            )
        default:
            FileHandle.standardError.write(
                Data("unknown option \(mode); try --help\n".utf8)
            )
            exit(2)
        }
        exit(0)
    }
}
