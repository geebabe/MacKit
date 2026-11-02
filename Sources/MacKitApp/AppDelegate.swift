// MacKitApp/AppDelegate.swift
// NSApplicationDelegate: menu bar status item, module lifecycle,
// and app-wide dependency wiring.

import AppKit
import SwiftUI
import AppCore
import ClipboardFeature
import WindowFeature
import SwitcherFeature
import SecureStorage
import Diagnostics

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Shared dependencies (owned here, passed into scenes via environmentObject)

    let settings = AppSettings()
    let permissionMonitor = PermissionMonitor()
    let shortcutRegistry = ShortcutRegistry()
    let launchAtLogin = LaunchAtLoginManager()

    // MARK: - Module coordinators

    private let clipboardModule = ClipboardModule()
    private let windowModule = WindowModule()
    private let switcherModule = SwitcherModule()

    // MARK: - Secure storage

    private let encryptionService = EncryptionService()
    private var databaseService: DatabaseService?

    // MARK: - Menu bar

    private var statusItem: NSStatusItem?
    private var menu: NSMenu?

    private let logger = Logger(category: .appCore)

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        // MacKit is a menu bar application — no Dock icon.
        NSApp.setActivationPolicy(.accessory)

        setupMenuBar()
        permissionMonitor.refresh()
        launchAtLogin.refresh()

        Task {
            await startModules()
        }

        logger.info("MacKit started")
    }

    func applicationWillTerminate(_ notification: Notification) {
        Task {
            await stopModules()
        }
        databaseService = nil
        logger.info("MacKit terminating")
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        permissionMonitor.refresh()
    }

    // MARK: - Menu bar setup

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "MacKit")
            button.image?.isTemplate = true
            button.toolTip = "MacKit"
        }

        menu = buildMenu()
        statusItem?.menu = menu
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu(title: "MacKit")

        // Module status section
        let clipboardItem = NSMenuItem(title: moduleStatusTitle(for: "Clipboard", enabled: settings.clipboardEnabled), action: nil, keyEquivalent: "")
        clipboardItem.isEnabled = false
        menu.addItem(clipboardItem)

        let windowItem = NSMenuItem(title: moduleStatusTitle(for: "Window Manager", enabled: settings.windowEnabled), action: nil, keyEquivalent: "")
        windowItem.isEnabled = false
        menu.addItem(windowItem)

        let switcherItem = NSMenuItem(title: moduleStatusTitle(for: "Window Switcher", enabled: settings.switcherEnabled), action: nil, keyEquivalent: "")
        switcherItem.isEnabled = false
        menu.addItem(switcherItem)

        menu.addItem(NSMenuItem.separator())

        // Settings
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit MacKit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    private func moduleStatusTitle(for name: String, enabled: Bool) -> String {
        "\(name): \(enabled ? "On" : "Off")"
    }

    @objc private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - Module lifecycle

    private func startModules() async {
        // Start SecureStorage first (encryption key must be available before clipboard writes)
        do {
            try await encryptionService.prepareKey()
            logger.info("Encryption key ready")
        } catch {
            logger.error("Encryption service failed to prepare: \(error)")
            // Non-fatal for Milestone 1 — clipboard capture is Milestone 2.
        }

        // Start feature modules
        await clipboardModule.start(settings: settings, permissionMonitor: permissionMonitor)
        await windowModule.start(settings: settings)
        await switcherModule.start(settings: settings)

        logger.info("All modules started")
    }

    private func stopModules() async {
        await clipboardModule.stop()
        await windowModule.stop()
        await switcherModule.stop()
    }
}

