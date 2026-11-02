// SwitcherFeature/WindowActivator.swift
// State machine activating and raising external application windows using public APIs.

import Foundation
import AppKit
import ApplicationServices
import Diagnostics

/// The phases of the window activation state machine.
public enum WindowActivationState: Sendable {
    case selected
    case validating
    case restoring
    case activatingApp
    case raisingWindow
    case completed
    case failed(WindowError)
}

/// Orchestrates activating, un-minimizing, and raising a window.
public struct WindowActivator: Sendable {

    private let logger = Logger(category: .switcher)

    public init() {}

    /// Executes the activation state machine for the given window item.
    public func activateWindow(item: SwitcherWindowItem) -> Result<Void, WindowError> {
        // 1. Validate: check if running application exists
        guard let app = NSRunningApplication(processIdentifier: item.processIdentifier), !app.isTerminated else {
            logger.warning("Activation failed: Target application PID \(item.processIdentifier) no longer running")
            return .failure(.activationFailed("Target application is not running"))
        }

        let appElement = AXUIElementCreateApplication(item.processIdentifier)

        // Find the matching window element
        var targetWindow: AXUIElement?
        var windowsRef: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)

        if status == .success, let windows = windowsRef as? [AXUIElement] {
            for window in windows {
                let pointerHash = CFHash(window)
                let calculatedID = "\(item.processIdentifier)-\(item.windowTitle)-\(pointerHash)"
                if calculatedID == item.id {
                    targetWindow = window
                    break
                }
            }
            // Fallback: match by title if pointer changed
            if targetWindow == nil {
                for window in windows {
                    var titleRef: CFTypeRef?
                    _ = AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef)
                    if let title = titleRef as? String, title == item.windowTitle {
                        targetWindow = window
                        break
                    }
                }
            }
            // Fallback: if single window, use it
            if targetWindow == nil && windows.count == 1 {
                targetWindow = windows.first
            }
        }

        // 2. Restore if needed (unminimize)
        if let targetWindow, item.isMinimized {
            _ = AXUIElementSetAttributeValue(targetWindow, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
            logger.info("Un-minimized window '\(item.displayTitle)'")
        }

        // 3. Activate app
        let activated = app.activate()
        guard activated else {
            logger.warning("Failed bringing app '\(item.appName)' to foreground")
            return .failure(.activationFailed("Failed activating application"))
        }

        // 4. Raise / focus window
        if let targetWindow {
            _ = AXUIElementPerformAction(targetWindow, kAXRaiseAction as CFString)
            _ = AXUIElementSetAttributeValue(targetWindow, kAXMainAttribute as CFString, kCFBooleanTrue)
            logger.info("Raised window '\(item.displayTitle)'")
        }

        return .success(())
    }
}
