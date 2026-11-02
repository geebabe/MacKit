// SwitcherFeature/WindowEnumerator.swift
// Enumerates eligible windows across running applications using public macOS APIs.
// Runs off the main thread where appropriate to avoid blocking on unresponsive apps.

import Foundation
import AppKit
import ApplicationServices
import Diagnostics

/// Discovers open windows across running applications.
public struct WindowEnumerator: Sendable {

    private let logger = Logger(category: .switcher)

    public init() {}

    /// Discovers all eligible windows for the Window Switcher.
    public func enumerateWindows() async -> [SwitcherWindowItem] {
        var items: [SwitcherWindowItem] = []

        let runningApps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && !$0.isTerminated
        }

        for app in runningApps {
            let pid = app.processIdentifier
            let appName = app.localizedName ?? "Application"
            let bundleID = app.bundleIdentifier

            let appElement = AXUIElementCreateApplication(pid)

            // Set timeout so an unresponsive app does not hang enumeration (150ms timeout)
            AXUIElementSetAttributeValue(appElement, "AXTimeout" as CFString, 0.15 as CFTypeRef)

            var windowsRef: CFTypeRef?
            let status = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)

            if status == .success, let axWindows = windowsRef as? [AXUIElement] {
                for window in axWindows {
                    if let item = processWindowElement(window, pid: pid, appName: appName, bundleID: bundleID) {
                        items.append(item)
                    }
                }
            }
        }

        return items
    }

    private func processWindowElement(
        _ window: AXUIElement,
        pid: pid_t,
        appName: String,
        bundleID: String?
    ) -> SwitcherWindowItem? {
        // Verify role is standard window
        var roleRef: CFTypeRef?
        _ = AXUIElementCopyAttributeValue(window, kAXRoleAttribute as CFString, &roleRef)
        if let role = roleRef as? String, role != (kAXWindowRole as String) {
            return nil
        }

        // Subrole check: ignore utility popups, floating status items, tooltips
        var subroleRef: CFTypeRef?
        _ = AXUIElementCopyAttributeValue(window, kAXSubroleAttribute as CFString, &subroleRef)
        if let subrole = subroleRef as? String {
            // Ignore system alert sheets, menu bars, unknown floating panels
            if subrole == "AXSystemDialog" || subrole == "AXFloatingWindow" {
                return nil
            }
        }

        // Read title
        var titleRef: CFTypeRef?
        _ = AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef)
        let title = (titleRef as? String) ?? ""

        // Check minimized status
        var minimizedRef: CFTypeRef?
        _ = AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimizedRef)
        let isMinimized = (minimizedRef as? Bool) ?? false

        // Unique window ID based on PID, title, and pointer hash
        let pointerHash = CFHash(window)
        let windowID = "\(pid)-\(title)-\(pointerHash)"

        return SwitcherWindowItem(
            id: windowID,
            processIdentifier: pid,
            bundleIdentifier: bundleID,
            appName: appName,
            windowTitle: title,
            isMinimized: isMinimized
        )
    }
}
