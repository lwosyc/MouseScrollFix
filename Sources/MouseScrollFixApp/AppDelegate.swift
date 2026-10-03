import AppKit
import MouseScrollFixPlatform
import MouseScrollFixUI
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var model: AppStatusModel!
    private var menuBar: MenuBarController!
    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let statusModel = AppStatusModel()
        model = statusModel

        menuBar = MenuBarController(model: statusModel, appDelegate: self)
        statusModel.onStatusChanged = { [weak self] in
            self?.menuBar.refresh()
        }

        menuBar.install()
        statusModel.start()

        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceCenter.addObserver(
            self,
            selector: #selector(handleWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        workspaceCenter.addObserver(
            self,
            selector: #selector(handleSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        workspaceCenter.addObserver(
            self,
            selector: #selector(handleSessionActivation),
            name: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil
        )

        // Follow a change of the macOS language while we are running.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLocaleChange),
            name: NSLocale.currentLocaleDidChangeNotification,
            object: nil
        )

        if !statusModel.settings.hasSeenOnboarding {
            // Give the status item a moment to appear first, so the window is clearly
            // attached to something the user can see.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.showOnboarding()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        model?.shutdown()
    }

    // MARK: System events

    /// macOS is known to stop delivering events to taps after sleep. Rebuild the tap,
    /// and try again shortly after because the HID subsystem can lag behind wake.
    @objc private func handleWake() {
        model.refreshSystemState()
        model.tapWorker.requestRecreate(delay: 0.2)
        model.tapWorker.requestRecreate(delay: 1.5)
        model.refreshStatus()
    }

    @objc private func handleSleep() {
        // Drop stream state so a stale gesture cannot swallow a post-wake wheel tick.
        model.tapWorker.resetClassifier()
    }

    @objc private func handleSessionActivation() {
        model.refreshSystemState()
    }

    @objc private func handleLocaleChange() {
        model.refreshLocalization()
    }

    // MARK: Windows

    @objc func openSettings(_ sender: Any?) {
        showSettings(tab: nil)
    }

    @objc func openDiagnostics(_ sender: Any?) {
        showSettings(tab: .diagnostics)
    }

    func showSettings(tab: SettingsTab?) {
        if let tab {
            model.selectedTab = tab
        }
        if settingsWindow == nil {
            let hosting = NSHostingController(rootView: SettingsView(model: model))
            let window = NSWindow(contentViewController: hosting)
            window.title = model.text(.appName)
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    /// The permission window. Shown automatically on first launch and reachable at any
    /// time from the menu bar.
    func showOnboarding() {
        if onboardingWindow == nil {
            let hosting = NSHostingController(
                rootView: OnboardingView(model: model) { [weak self] in
                    self?.dismissOnboarding()
                }
            )
            let window = NSWindow(contentViewController: hosting)
            window.title = model.text(.appName)
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            onboardingWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow?.makeKeyAndOrderFront(nil)
    }

    private func dismissOnboarding() {
        model.markOnboardingSeen()
        onboardingWindow?.orderOut(nil)
    }
}
