// WindowFeature/ScreenGeometry.swift
// Pure geometry calculations for macOS window positioning and coordinate conversion.
// AppKit (bottom-left origin) to Accessibility / Carbon (top-left origin).

import Foundation
import CoreGraphics
import AppKit

/// Pure geometric helper functions for window placement calculations.
public struct ScreenGeometry: Sendable {

    public init() {}

    /// Converts a Cocoa screen visible frame (bottom-left origin) into Accessibility
    /// screen coordinates (top-left origin, relative to the primary display).
    public static func cocoaToAccessibility(
        cocoaRect: CGRect,
        primaryScreenHeight: CGFloat
    ) -> CGRect {
        let x = cocoaRect.origin.x
        let y = primaryScreenHeight - (cocoaRect.origin.y + cocoaRect.size.height)
        return CGRect(x: x, y: y, width: cocoaRect.size.width, height: cocoaRect.size.height)
    }

    /// Computes the target frame in Accessibility coordinates for a specified action.
    public static func targetFrame(
        action: WindowAction,
        currentFrame: CGRect,
        usableScreenBounds: CGRect
    ) -> CGRect {
        switch action {
        case .snapLeft:
            let halfWidth = floor(usableScreenBounds.width / 2.0)
            return CGRect(
                x: usableScreenBounds.minX,
                y: usableScreenBounds.minY,
                width: halfWidth,
                height: usableScreenBounds.height
            )

        case .snapRight:
            let halfWidth = floor(usableScreenBounds.width / 2.0)
            return CGRect(
                x: usableScreenBounds.minX + halfWidth,
                y: usableScreenBounds.minY,
                width: usableScreenBounds.width - halfWidth,
                height: usableScreenBounds.height
            )

        case .maximize:
            return usableScreenBounds

        case .center:
            let targetWidth = min(currentFrame.width, usableScreenBounds.width)
            let targetHeight = min(currentFrame.height, usableScreenBounds.height)
            let x = usableScreenBounds.minX + floor((usableScreenBounds.width - targetWidth) / 2.0)
            let y = usableScreenBounds.minY + floor((usableScreenBounds.height - targetHeight) / 2.0)
            return CGRect(
                x: x,
                y: y,
                width: targetWidth,
                height: targetHeight
            )

        case .restore:
            // Handled separately using stored original frame
            return currentFrame
        }
    }

    /// Calculates the intersection area between two rectangles.
    public static func intersectionArea(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let intersection = a.intersection(b)
        if intersection.isNull || intersection.isEmpty {
            return 0
        }
        return intersection.width * intersection.height
    }

    /// Determines which screen currently contains the window by selecting
    /// the screen with the largest overlap area.
    public static func bestScreen(
        for windowFrame: CGRect,
        screens: [NSScreen],
        primaryScreenHeight: CGFloat
    ) -> (screen: NSScreen, usableBoundsAX: CGRect)? {
        guard !screens.isEmpty else { return nil }

        var bestScreen = screens[0]
        var maxArea: CGFloat = -1

        for screen in screens {
            let screenAX = cocoaToAccessibility(cocoaRect: screen.frame, primaryScreenHeight: primaryScreenHeight)
            let area = intersectionArea(windowFrame, screenAX)
            if area > maxArea {
                maxArea = area
                bestScreen = screen
            }
        }

        let usableAX = cocoaToAccessibility(cocoaRect: bestScreen.visibleFrame, primaryScreenHeight: primaryScreenHeight)
        return (bestScreen, usableAX)
    }

    /// Ensures a rect is clamped within the usable screen bounds.
    public static func clamp(rect: CGRect, within bounds: CGRect) -> CGRect {
        var clamped = rect
        if clamped.width > bounds.width {
            clamped.size.width = bounds.width
        }
        if clamped.height > bounds.height {
            clamped.size.height = bounds.height
        }
        if clamped.minX < bounds.minX {
            clamped.origin.x = bounds.minX
        }
        if clamped.maxX > bounds.maxX {
            clamped.origin.x = bounds.maxX - clamped.width
        }
        if clamped.minY < bounds.minY {
            clamped.origin.y = bounds.minY
        }
        if clamped.maxY > bounds.maxY {
            clamped.origin.y = bounds.maxY - clamped.height
        }
        return clamped
    }
}

