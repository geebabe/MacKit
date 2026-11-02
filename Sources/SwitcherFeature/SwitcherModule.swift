// SwitcherFeature/SwitcherModule.swift
// Window Switcher module coordinator.
// Manages window discovery, MRU ordering, switcher overlay, and window activation.

import Foundation
import AppKit
import AppCore
import Diagnostics

/// MainActor coordinator for the Window Switcher module.
@MainActor
public final class SwitcherModule: ObservableObject {

    @Published public private(set) var isActive: Bool = false
    @Published public private(set) var windows: [SwitcherWindowItem] = []

    private let enumerator = WindowEnumerator()
    private let activator = WindowActivator()
    private var mruTracker = MRUTracker()
    private lazy var panel = SwitcherPanel()

    private let logger = Logger(category: .switcher)
    private var settings: AppSettings?
    private var workspaceObserver: Any?

    public init() {}

    /// Start the Window Switcher module.
    public func start(settings: AppSettings) {
        self.settings = settings
        guard settings.switcherEnabled else {
            isActive = false
            logger.info("SwitcherModule is disabled in settings")
            return
        }

        isActive = true
        setupPanelActions()
        setupWorkspaceObserver()
        logger.info("SwitcherModule started and active")
    }

    /// Stop the Window Switcher module.
    public func stop() {
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            workspaceObserver = nil
        }
        panel.dismiss()
        isActive = false
        logger.info("SwitcherModule stopped")
    }

    /// Toggle or present the window switcher overlay.
    public func toggleSwitcher() {
        guard isActive else { return }
        if panel.isVisible {
            panel.dismiss()
        } else {
            Task { @MainActor in
                await presentSwitcher()
            }
        }
    }

    /// Discover current windows, sort by MRU, and present overlay.
    public func presentSwitcher() async {
        guard isActive else { return }

        let discovered = await enumerator.enumerateWindows()
        let sorted = mruTracker.sortMRU(items: discovered)

        self.windows = sorted
        panel.updateWindows(sorted)
        panel.present()
        logger.info("Presented window switcher with \(sorted.count) windows")
    }

    // MARK: - Private Setup

    private func setupPanelActions() {
        panel.onSelectAndActivate = { [weak self] item in
            self?.activate(item: item)
        }
    }

    private func setupWorkspaceObserver() {
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                Task { @MainActor [weak self] in
                    self?.handleApplicationActivated(app)
                }
            }
        }
    }

    private func handleApplicationActivated(_ app: NSRunningApplication) {
        let pid = app.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        var focusedWindowRef: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindowRef)

        if status == .success, let window = focusedWindowRef {
            var titleRef: CFTypeRef?
            _ = AXUIElementCopyAttributeValue(window as! AXUIElement, kAXTitleAttribute as CFString, &titleRef)
            let title = (titleRef as? String) ?? ""
            let pointerHash = CFHash(window)
            let windowID = "\(pid)-\(title)-\(pointerHash)"

            mruTracker.recordFocus(windowID: windowID)
        }
    }

    private func activate(item: SwitcherWindowItem) {
        mruTracker.recordFocus(windowID: item.id)
        let result = activator.activateWindow(item: item)
        if case .failure(let error) = result {
            logger.warning("Failed activating window '\(item.displayTitle)': \(error)")
        } else {
            logger.info("Activated window '\(item.displayTitle)'")
        }
    }
}
