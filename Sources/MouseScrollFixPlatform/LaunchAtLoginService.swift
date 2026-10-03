import Foundation
import ServiceManagement

/// Launch at login through `SMAppService` (macOS 13+), which is why 13.0 is the
/// deployment target: `SMLoginItemSetEnabled` is deprecated as of 13.0.
///
/// `SMAppService` requires a code-signed app, so this only reports success for a
/// properly signed bundle.
public enum LaunchAtLoginService {
    public static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    public static var statusDescription: String {
        switch SMAppService.mainApp.status {
        case .enabled:
            return "Enabled"
        case .notRegistered:
            return "Not registered"
        case .requiresApproval:
            return "Requires approval in System Settings"
        case .notFound:
            return "Not found (app must be in a stable location)"
        @unknown default:
            return "Unknown"
        }
    }

    public static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
