// WindowFeature/AccessibilityWindowWrapper.swift
// Encapsulates macOS Accessibility (AXUIElement) APIs for window inspection and manipulation.
// Uses only public interfaces.

import Foundation
import CoreGraphics
import ApplicationServices
import Diagnostics

/// Low-level wrapper around AXUIElement for manipulating an external application window.
public struct AccessibilityWindowWrapper: Sendable {

    public init() {}

    /// Obtain the focused window for a given process identifier.
    public func getFocusedWindow(processIdentifier: pid_t) -> Result<AXUIElement, WindowError> {
        guard AXIsProcessTrusted() else {
            return .failure(.accessibilityUnavailable("Accessibility permission not granted"))
        }

        let appElement = AXUIElementCreateApplication(processIdentifier)

        var focusedWindowRef: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindowRef)

        if status == .success, let window = focusedWindowRef {
            return .success(window as! AXUIElement)
        }

        // Fall back to main window if focused window is not reported
        var mainWindowRef: CFTypeRef?
        let mainStatus = AXUIElementCopyAttributeValue(appElement, kAXMainWindowAttribute as CFString, &mainWindowRef)
        if mainStatus == .success, let window = mainWindowRef {
            return .success(window as! AXUIElement)
        }

        return .failure(.windowNotFound)
    }

    /// Read the window's current title.
    public func getTitle(window: AXUIElement) -> String {
        var titleRef: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef)
        if status == .success, let title = titleRef as? String {
            return title
        }
        return ""
    }

    /// Read the window's current frame in Accessibility coordinates.
    public func getFrame(window: AXUIElement) -> Result<CGRect, WindowError> {
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?

        let posStatus = AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posRef)
        let sizeStatus = AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef)

        guard posStatus == .success, let posVal = posRef,
              sizeStatus == .success, let sizeVal = sizeRef
        else {
            return .failure(.accessibilityUnavailable("Failed reading window position or size"))
        }

        var point = CGPoint.zero
        var size = CGSize.zero

        AXValueGetValue(posVal as! AXValue, .cgPoint, &point)
        AXValueGetValue(sizeVal as! AXValue, .cgSize, &size)

        return .success(CGRect(origin: point, size: size))
    }

    /// Check if the window's size attribute can be modified.
    public func isResizable(window: AXUIElement) -> Bool {
        var isSettable: DarwinBoolean = false
        let status = AXUIElementIsAttributeSettable(window, kAXSizeAttribute as CFString, &isSettable)
        return status == .success && isSettable.boolValue
    }

    /// Apply new position and size to the window.
    public func setFrame(window: AXUIElement, newFrame: CGRect) -> Result<Void, WindowError> {
        guard isResizable(window: window) else {
            return .failure(.notResizable)
        }

        var newPoint = newFrame.origin
        var newSize = newFrame.size

        guard let posVal = AXValueCreate(.cgPoint, &newPoint),
              let sizeVal = AXValueCreate(.cgSize, &newSize)
        else {
            return .failure(.accessibilityUnavailable("Failed creating AXValue coordinates"))
        }

        // Apply position first, then size, then verify position
        let setPosStatus = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posVal)
        let setSizeStatus = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeVal)

        // Retry position in case resizing pushed the window against a screen edge
        _ = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posVal)

        if setPosStatus != .success && setSizeStatus != .success {
            return .failure(.accessibilityUnavailable("Accessibility API refused window frame update"))
        }

        return .success(())
    }
}
