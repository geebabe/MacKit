// MacKitApp/AppDelegate.swift
// NSApplicationDelegate: menu bar status item, module lifecycle,
// and app-wide dependency wiring.

import AppKit
import SwiftUI
import Carbon
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
    private var payloadStore: PayloadStore?
    private var clipboardRepository: ClipboardRepository?

    // MARK: - Menu bar & Global Hotkeys

    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private var settingsWindow: NSWindow?
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?

    private let logger = Logger(category: .appCore)

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        // MacKit is a menu bar application — no Dock icon.
        NSApp.setActivationPolicy(.accessory)

        setupMenuBar()
        setupGlobalHotkeys()
        permissionMonitor.refresh()
        launchAtLogin.refresh()

        Task {
            await startModules()
        }

        // On launch, if Accessibility is not granted, request prompt and open Settings
        // so the user immediately receives visual feedback and clear onboarding.
        if !permissionMonitor.accessibilityStatus.isGranted {
            permissionMonitor.requestAccessibility()
            openSettings()
        }

        logger.info("MacKit started")
    }

    func applicationWillTerminate(_ notification: Notification) {
        GlobalHotkeyManager.shared.unregisterAll()
        if let globalEventMonitor {
            NSEvent.removeMonitor(globalEventMonitor)
        }
        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
        }
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

        updateMenu()
    }

    public func updateMenu() {
        menu = buildMenu()
        statusItem?.menu = menu
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu(title: "MacKit")

        // Clipboard quick actions
        let historyItem = NSMenuItem(title: "Show Clipboard History", action: #selector(toggleClipboardPanel), keyEquivalent: "v")
        historyItem.keyEquivalentModifierMask = [.option]
        historyItem.target = self
        menu.addItem(historyItem)

        let switcherMenuItem = NSMenuItem(title: "Show Window Switcher", action: #selector(toggleSwitcher), keyEquivalent: " ")
        switcherMenuItem.keyEquivalentModifierMask = [.control, .option]
        switcherMenuItem.target = self
        menu.addItem(switcherMenuItem)

        let pauseTitle = settings.clipboardPaused ? "Resume Clipboard Recording" : "Pause Clipboard Recording"
        let pauseItem = NSMenuItem(title: pauseTitle, action: #selector(togglePauseRecording), keyEquivalent: "")
        pauseItem.target = self
        menu.addItem(pauseItem)

        menu.addItem(NSMenuItem.separator())

        // Window Manager submenu
        let windowMenu = NSMenu(title: "Window Manager")
        let snapLeftItem = NSMenuItem(title: "Snap Left (⌃⌥←)", action: #selector(snapLeft), keyEquivalent: "")
        snapLeftItem.target = self
        windowMenu.addItem(snapLeftItem)

        let snapRightItem = NSMenuItem(title: "Snap Right (⌃⌥→)", action: #selector(snapRight), keyEquivalent: "")
        snapRightItem.target = self
        windowMenu.addItem(snapRightItem)

        let maximizeItem = NSMenuItem(title: "Maximize (⌃⌥↑)", action: #selector(maximizeWindow), keyEquivalent: "")
        maximizeItem.target = self
        windowMenu.addItem(maximizeItem)

        let centerItem = NSMenuItem(title: "Center (⌃⌥C)", action: #selector(centerWindow), keyEquivalent: "")
        centerItem.target = self
        windowMenu.addItem(centerItem)

        let restoreItem = NSMenuItem(title: "Restore (⌃⌥↓)", action: #selector(restoreWindow), keyEquivalent: "")
        restoreItem.target = self
        windowMenu.addItem(restoreItem)

        let windowParentItem = NSMenuItem(title: "Window Actions", action: nil, keyEquivalent: "")
        windowParentItem.submenu = windowMenu
        menu.addItem(windowParentItem)

        menu.addItem(NSMenuItem.separator())

        // Module status section
        let clipboardItem = NSMenuItem(title: moduleStatusTitle(for: "Clipboard", enabled: settings.clipboardEnabled && !settings.clipboardPaused), action: nil, keyEquivalent: "")
        clipboardItem.isEnabled = false
        menu.addItem(clipboardItem)

        let windowStatusItem = NSMenuItem(title: moduleStatusTitle(for: "Window Manager", enabled: settings.windowEnabled), action: nil, keyEquivalent: "")
        windowStatusItem.isEnabled = false
        menu.addItem(windowStatusItem)

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

    // MARK: - Actions

    @objc private func toggleClipboardPanel() {
        clipboardModule.togglePanel()
    }

    @objc private func toggleSwitcher() {
        switcherModule.toggleSwitcher()
    }

    @objc private func togglePauseRecording() {
        settings.clipboardPaused.toggle()
        clipboardModule.updatePauseState(isPaused: settings.clipboardPaused)
        updateMenu()
    }

    @objc private func snapLeft() {
        windowModule.performAction(.snapLeft)
    }

    @objc private func snapRight() {
        windowModule.performAction(.snapRight)
    }

    @objc private func maximizeWindow() {
        windowModule.performAction(.maximize)
    }

    @objc private func centerWindow() {
        windowModule.performAction(.center)
    }

    @objc private func restoreWindow() {
        windowModule.performAction(.restore)
    }

    @objc public func openSettings() {
        if settingsWindow == nil {
            let view = SettingsView()
                .environmentObject(settings)
                .environmentObject(permissionMonitor)
                .environmentObject(shortcutRegistry)
                .environmentObject(launchAtLogin)
            let hosting = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: hosting)
            window.title = "MacKit Settings"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.setContentSize(NSSize(width: 580, height: 440))
            window.center()
            window.isReleasedWhenClosed = false
            self.settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - Global Hotkeys

    private func setupGlobalHotkeys() {
        // 1. Register in ShortcutRegistry for UI display and conflict tracking
        shortcutRegistry.register(ShortcutRegistration(
            id: "clipboard.toggle",
            displayName: "Open Clipboard History",
            keyEquivalent: "⌥V",
            modifierFlags: [.option]
        ))
        shortcutRegistry.register(ShortcutRegistration(
            id: "window.snapLeft",
            displayName: "Snap Left",
            keyEquivalent: "⌃⌥←",
            modifierFlags: [.control, .option]
        ))
        shortcutRegistry.register(ShortcutRegistration(
            id: "window.snapRight",
            displayName: "Snap Right",
            keyEquivalent: "⌃⌥→",
            modifierFlags: [.control, .option]
        ))
        shortcutRegistry.register(ShortcutRegistration(
            id: "window.maximize",
            displayName: "Maximize",
            keyEquivalent: "⌃⌥↑",
            modifierFlags: [.control, .option]
        ))
        shortcutRegistry.register(ShortcutRegistration(
            id: "window.center",
            displayName: "Center",
            keyEquivalent: "⌃⌥C",
            modifierFlags: [.control, .option]
        ))
        shortcutRegistry.register(ShortcutRegistration(
            id: "window.restore",
            displayName: "Restore",
            keyEquivalent: "⌃⌥↓",
            modifierFlags: [.control, .option]
        ))
        shortcutRegistry.register(ShortcutRegistration(
            id: "switcher.toggle",
            displayName: "Open Window Switcher",
            keyEquivalent: "⌃⌥Space",
            modifierFlags: [.control, .option]
        ))

        // 2. Register Carbon global hotkeys (intercepts globally without requiring Accessibility)
        let hotkeyManager = GlobalHotkeyManager.shared

        // Option+V: Clipboard history
        hotkeyManager.register(
            id: MacKitHotkeyID.clipboardToggle.rawValue,
            keyCode: UInt32(kVK_ANSI_V),
            modifiers: UInt32(optionKey)
        ) { [weak self] in
            self?.clipboardModule.togglePanel()
        }

        // Control+Option+Space: Window Switcher
        hotkeyManager.register(
            id: MacKitHotkeyID.switcherToggle.rawValue,
            keyCode: UInt32(kVK_Space),
            modifiers: UInt32(controlKey | optionKey)
        ) { [weak self] in
            self?.switcherModule.toggleSwitcher()
        }

        // Control+Option+Left: Snap Left
        hotkeyManager.register(
            id: MacKitHotkeyID.windowSnapLeft.rawValue,
            keyCode: UInt32(kVK_LeftArrow),
            modifiers: UInt32(controlKey | optionKey)
        ) { [weak self] in
            self?.windowModule.performAction(.snapLeft)
        }

        // Control+Option+Right: Snap Right
        hotkeyManager.register(
            id: MacKitHotkeyID.windowSnapRight.rawValue,
            keyCode: UInt32(kVK_RightArrow),
            modifiers: UInt32(controlKey | optionKey)
        ) { [weak self] in
            self?.windowModule.performAction(.snapRight)
        }

        // Control+Option+Up: Maximize
        hotkeyManager.register(
            id: MacKitHotkeyID.windowMaximize.rawValue,
            keyCode: UInt32(kVK_UpArrow),
            modifiers: UInt32(controlKey | optionKey)
        ) { [weak self] in
            self?.windowModule.performAction(.maximize)
        }

        // Control+Option+Down: Restore
        hotkeyManager.register(
            id: MacKitHotkeyID.windowRestore.rawValue,
            keyCode: UInt32(kVK_DownArrow),
            modifiers: UInt32(controlKey | optionKey)
        ) { [weak self] in
            self?.windowModule.performAction(.restore)
        }

        // Control+Option+C: Center
        hotkeyManager.register(
            id: MacKitHotkeyID.windowCenter.rawValue,
            keyCode: UInt32(kVK_ANSI_C),
            modifiers: UInt32(controlKey | optionKey)
        ) { [weak self] in
            self?.windowModule.performAction(.center)
        }

        // 3. Monitor local key down events when MacKit windows are active
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleKeyEvent(event) == true {
                return nil // Consumed
            }
            return event
        }
    }

    @discardableResult
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Option+V (keyCode 9 = 'v')
        if flags == .option && event.keyCode == 9 {
            clipboardModule.togglePanel()
            return true
        }

        // Control+Option combinations for Window Manager
        if flags == [.control, .option] {
            switch event.keyCode {
            case 123: // Left Arrow
                windowModule.performAction(.snapLeft)
                return true
            case 124: // Right Arrow
                windowModule.performAction(.snapRight)
                return true
            case 126: // Up Arrow
                windowModule.performAction(.maximize)
                return true
            case 125: // Down Arrow
                windowModule.performAction(.restore)
                return true
            case 8: // 'C' key
                windowModule.performAction(.center)
                return true
            case 49: // Space key (Window Switcher)
                switcherModule.toggleSwitcher()
                return true
            default:
                break
            }
        }

        return false
    }

    // MARK: - Module lifecycle

    private func startModules() async {
        // 1. Prepare application support directories for storage
        let fm = FileManager.default
        let appSupportDir: URL
        if let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            appSupportDir = base.appendingPathComponent("com.mackit.app")
        } else {
            appSupportDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("com.mackit.app")
        }
        try? fm.createDirectory(at: appSupportDir, withIntermediateDirectories: true)

        let dbURL = appSupportDir.appendingPathComponent("mackit.sqlite")
        let payloadsURL = appSupportDir.appendingPathComponent("payloads")

        // 2. Prepare Encryption and Database services
        do {
            try await encryptionService.prepareKey()
            logger.info("Encryption service ready")
        } catch {
            logger.error("Encryption service failed to prepare: \(error)")
        }

        let db = DatabaseService(databaseURL: dbURL)
        do {
            try await db.open()
            self.databaseService = db
            logger.info("Database service opened")
        } catch {
            logger.error("Database service failed to open: \(error)")
        }

        let store = PayloadStore(baseDirectory: payloadsURL, encryptionService: encryptionService)
        self.payloadStore = store

        if let db = self.databaseService {
            let repo = ClipboardRepository(
                database: db,
                encryptionService: encryptionService,
                payloadStore: store
            )
            self.clipboardRepository = repo

            // 3. Start feature modules
            await clipboardModule.start(settings: settings, repository: repo)
        }

        windowModule.start(settings: settings)
        switcherModule.start(settings: settings)

        logger.info("All modules initialized")
    }

    private func stopModules() async {
        clipboardModule.stop()
        windowModule.stop()
        switcherModule.stop()
        if let db = databaseService {
            await db.close()
        }
    }
}
