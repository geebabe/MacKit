// WindowFeature/WindowManager.swift
// High-level coordinator executing window layout actions on the active window.

import Foundation
import CoreGraphics
import AppKit
import Diagnostics

/// Coordinates active window identification, geometry calculations, and frame application.
@MainActor
public final class WindowManager {

    private let wrapper = AccessibilityWindowWrapper()
    public let restoreStore = WindowRestoreStore()
    private let logger = Logger(category: .window)

    public init() {}

    /// Performs the requested window action on the currently focused application window.
    @discardableResult
    public func performAction(_ action: WindowAction) -> Result<CGRect, AppError> {
        // 1. Verify Accessibility permission
        guard AXIsProcessTrusted() else {
            logger.warning("Window operation failed: Accessibility not trusted")
            return .failure(.permissionDenied(.accessibility))
        }

        // 2. Identify frontmost application
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            logger.warning("Window operation failed: No frontmost application")
            return .failure(.windowOperationFailed(.windowNotFound))
        }

        let pid = frontApp.processIdentifier

        // 3. Obtain active window element
        let windowResult = wrapper.getFocusedWindow(processIdentifier: pid)
        guard case .success(let window) = windowResult else {
            if case .failure(let err) = windowResult {
                logger.warning("Window lookup failed: \(err)")
                return .failure(.windowOperationFailed(err))
            }
            return .failure(.windowOperationFailed(.windowNotFound))
        }

        // 4. Verify window is resizable
        guard wrapper.isResizable(window: window) else {
            logger.warning("Window operation aborted: Window is not resizable")
            return .failure(.windowOperationFailed(.notResizable))
        }

        // 5. Read current window frame
        let frameResult = wrapper.getFrame(window: window)
        guard case .success(let currentFrame) = frameResult else {
            return .failure(.windowOperationFailed(.accessibilityUnavailable("Could not read current frame")))
        }

        let title = wrapper.getTitle(window: window)
        let identity = WindowIdentity(processIdentifier: pid, windowTitle: title)

        // 6. Resolve containing screen and usable bounds
        let screens = NSScreen.screens
        let primaryHeight = screens.first?.frame.height ?? 0

        guard let screenInfo = ScreenGeometry.bestScreen(
            for: currentFrame,
            screens: screens,
            primaryScreenHeight: primaryHeight
        ) else {
            return .failure(.windowOperationFailed(.frameOutOfBounds))
        }

        let usableBounds = screenInfo.usableBoundsAX

        // 7. Calculate new frame based on requested action
        let targetFrame: CGRect

        if action == .restore {
            guard let previousFrame = restoreStore.popFrame(for: identity) else {
                logger.info("No saved restore frame for window '\(title)'")
                return .failure(.windowOperationFailed(.frameOutOfBounds))
            }
            targetFrame = ScreenGeometry.clamp(rect: previousFrame, within: usableBounds)
        } else {
            // Save current frame for future restoration
            restoreStore.saveFrame(currentFrame, for: identity)

            let computed = ScreenGeometry.targetFrame(
                action: action,
                currentFrame: currentFrame,
                usableScreenBounds: usableBounds
            )
            targetFrame = ScreenGeometry.clamp(rect: computed, within: usableBounds)
        }

        // 8. Apply target frame
        let setResult = wrapper.setFrame(window: window, newFrame: targetFrame)
        guard case .success = setResult else {
            if case .failure(let err) = setResult {
                logger.error("Failed applying window frame: \(err)")
                return .failure(.windowOperationFailed(err))
            }
            return .failure(.windowOperationFailed(.accessibilityUnavailable("Set frame failed")))
        }

        logger.info("Executed \(action.displayTitle) on window '\(title)'")
        return .success(targetFrame)
    }
}

