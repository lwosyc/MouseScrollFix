import AppKit
import MouseScrollFixCore
import MouseScrollFixUI

/// The menu bar item and its menu.
///
/// The menu is rebuilt every time it opens, so the labels, checkmarks and status line
/// are always current — including right after a language change — without any polling.
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let model: AppStatusModel
    private weak var appDelegate: AppDelegate?
    private let menu = NSMenu()
    private var statusItem: NSStatusItem?

    init(model: AppStatusModel, appDelegate: AppDelegate) {
        self.model = model
        self.appDelegate = appDelegate
        super.init()
    }

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = icon(for: model)
        item.button?.toolTip = model.text(.menuTooltip)
        menu.delegate = self
        item.menu = menu
        statusItem = item
        updateVisibility()
    }

    func refresh() {
        statusItem?.button?.image = icon(for: model)
        statusItem?.button?.toolTip = model.text(.menuTooltip)
        updateVisibility()
    }

    private func updateVisibility() {
        statusItem?.isVisible = model.settings.showMenuBarIcon
    }

    private func icon(for model: AppStatusModel) -> NSImage? {
        let symbol: String
        if !model.settings.mouseInversionEnabled {
            symbol = "computermouse"
        } else if model.isActive {
            symbol = "computermouse.fill"
        } else {
            symbol = "exclamationmark.triangle"
        }
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: model.text(.appName))
        image?.isTemplate = true
        return image
    }

    // MARK: Menu

    func menuWillOpen(_ menu: NSMenu) {
        model.refreshStatus()
        rebuild()
    }

    private func rebuild() {
        menu.removeAllItems()

        menu.addItem(disabled(model.text(.menuStatusFormat, "\(model.text(.appName)) — \(model.statusHeadline)")))
        menu.addItem(
            disabled(
                model.text(
                    .menuMouseScrollingFormat,
                    model.settings.mouseInversionEnabled ? model.text(.valueOn) : model.text(.valueOff)
                )
            )
        )
        menu.addItem(
            disabled(
                model.text(
                    .menuTrackpadNaturalFormat,
                    model.naturalScrolling ? model.text(.valueOn) : model.text(.valueOff)
                )
            )
        )
        menu.addItem(disabled(model.text(.menuDetectedFormat, model.deviceSummary)))
        menu.addItem(.separator())

        if !model.isAccessibilityTrusted {
            menu.addItem(item(model.text(.menuGrantPermission), #selector(grantPermission)))
            menu.addItem(.separator())
        } else if case .failed = model.tapState {
            menu.addItem(item(model.text(.menuRetryFilter), #selector(retryTap)))
            menu.addItem(.separator())
        }

        menu.addItem(
            item(
                model.settings.mouseInversionEnabled ? model.text(.menuDisable) : model.text(.menuEnable),
                #selector(toggleEnabled)
            )
        )
        menu.addItem(.separator())

        menu.addItem(
            checkable(
                model.text(.menuInvertVertical),
                #selector(toggleVertical),
                state: model.settings.invertVertical
            )
        )
        menu.addItem(
            checkable(
                model.text(.menuInvertHorizontal),
                #selector(toggleHorizontal),
                state: model.settings.invertHorizontal
            )
        )
        menu.addItem(.separator())

        menu.addItem(
            checkable(
                model.text(.menuLaunchAtLogin),
                #selector(toggleLaunchAtLogin),
                state: model.settings.launchAtLogin
            )
        )
        menu.addItem(item(model.text(.menuOpenSettings), #selector(openSettings), keyEquivalent: ","))
        menu.addItem(item(model.text(.menuPermissions), #selector(openPermissions)))
        menu.addItem(item(model.text(.menuDiagnostics), #selector(openDiagnostics)))
        menu.addItem(.separator())
        menu.addItem(
            item(model.text(.menuQuit, model.text(.appName)), #selector(quit), keyEquivalent: "q")
        )
    }

    private func disabled(_ title: String) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        menuItem.isEnabled = false
        return menuItem
    }

    private func item(
        _ title: String,
        _ action: Selector,
        keyEquivalent: String = ""
    ) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        menuItem.target = self
        return menuItem
    }

    private func checkable(_ title: String, _ action: Selector, state: Bool) -> NSMenuItem {
        let menuItem = item(title, action)
        menuItem.state = state ? .on : .off
        return menuItem
    }

    // MARK: Actions

    @objc private func toggleEnabled() {
        model.toggleEnabled()
    }

    @objc private func toggleVertical() {
        model.setInvertVertical(!model.settings.invertVertical)
    }

    @objc private func toggleHorizontal() {
        model.setInvertHorizontal(!model.settings.invertHorizontal)
    }

    @objc private func toggleLaunchAtLogin() {
        model.setLaunchAtLogin(!model.settings.launchAtLogin)
    }

    @objc private func grantPermission() {
        appDelegate?.showOnboarding()
    }

    @objc private func retryTap() {
        model.retryTap()
    }

    @objc private func openSettings() {
        appDelegate?.openSettings(nil)
    }

    @objc private func openPermissions() {
        appDelegate?.showOnboarding()
    }

    @objc private func openDiagnostics() {
        appDelegate?.openDiagnostics(nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
