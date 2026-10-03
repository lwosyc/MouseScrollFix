import AppKit
import ApplicationServices
import Foundation

/// Accessibility permission: check, request, and deep-link to the right pane.
///
/// Only Accessibility is required. Input Monitoring is deliberately not requested —
/// we never open a HID device for input, and macOS allows an app to request Input
/// Monitoring effectively once, so asking prematurely would be irreversible.
public enum PermissionCoordinator {
    public static var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Shows the system prompt that offers to open System Settings. Returns the
    /// current trust state (which is usually still false right after the prompt).
    @discardableResult
    public static func requestAccessibilityPrompt() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Deep link to Privacy & Security → Accessibility. On recent releases the pane is
    /// labelled "Device Control and Data Access"; the URL is unchanged.
    public static func openAccessibilitySettings() {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}
