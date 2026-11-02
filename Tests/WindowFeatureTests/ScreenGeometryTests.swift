// Tests/WindowFeatureTests/ScreenGeometryTests.swift
// Tests for macOS window geometry, coordinate conversion, and layout calculations.

import Testing
import CoreGraphics
import AppKit
@testable import WindowFeature

@Suite("ScreenGeometry")
struct ScreenGeometryTests {

    let primaryScreenHeight: CGFloat = 1080

    @Test("Cocoa to Accessibility coordinate conversion on primary display")
    func cocoaToAccessibilityPrimary() {
        // Suppose screen visibleFrame is 1920x1056, menu bar 24px at top, dock hidden
        let cocoaVisible = CGRect(x: 0, y: 0, width: 1920, height: 1056)
        let axRect = ScreenGeometry.cocoaToAccessibility(
            cocoaRect: cocoaVisible,
            primaryScreenHeight: primaryScreenHeight
        )

        #expect(axRect.origin.x == 0)
        #expect(axRect.origin.y == 24) // 1080 - (0 + 1056) = 24
        #expect(axRect.size.width == 1920)
        #expect(axRect.size.height == 1056)
    }

    @Test("Cocoa to Accessibility coordinate conversion with bottom Dock")
    func cocoaToAccessibilityBottomDock() {
        // Dock height 50px at bottom: y starts at 50, height is 1006
        let cocoaVisible = CGRect(x: 0, y: 50, width: 1920, height: 1006)
        let axRect = ScreenGeometry.cocoaToAccessibility(
            cocoaRect: cocoaVisible,
            primaryScreenHeight: primaryScreenHeight
        )

        #expect(axRect.origin.x == 0)
        #expect(axRect.origin.y == 24) // 1080 - (50 + 1006) = 24
        #expect(axRect.size.width == 1920)
        #expect(axRect.size.height == 1006)
        // Bottom edge in AX: 24 + 1006 = 1030 (leaves 50px at bottom for Dock)
        #expect(axRect.maxY == 1030)
    }

    @Test("Snap Left calculates exact left half of usable bounds")
    func snapLeftCalculation() {
        let usable = CGRect(x: 0, y: 24, width: 1920, height: 1056)
        let current = CGRect(x: 100, y: 100, width: 800, height: 600)

        let target = ScreenGeometry.targetFrame(action: .snapLeft, currentFrame: current, usableScreenBounds: usable)

        #expect(target.origin.x == 0)
        #expect(target.origin.y == 24)
        #expect(target.size.width == 960) // 1920 / 2
        #expect(target.size.height == 1056)
    }

    @Test("Snap Right calculates exact right half of usable bounds")
    func snapRightCalculation() {
        let usable = CGRect(x: 0, y: 24, width: 1920, height: 1056)
        let current = CGRect(x: 100, y: 100, width: 800, height: 600)

        let target = ScreenGeometry.targetFrame(action: .snapRight, currentFrame: current, usableScreenBounds: usable)

        #expect(target.origin.x == 960)
        #expect(target.origin.y == 24)
        #expect(target.size.width == 960)
        #expect(target.size.height == 1056)
    }

    @Test("Snap Right handles odd widths cleanly without pixel gap")
    func snapRightOddWidth() {
        let usable = CGRect(x: 0, y: 24, width: 1921, height: 1056)
        let current = CGRect(x: 0, y: 0, width: 500, height: 500)

        let left = ScreenGeometry.targetFrame(action: .snapLeft, currentFrame: current, usableScreenBounds: usable)
        let right = ScreenGeometry.targetFrame(action: .snapRight, currentFrame: current, usableScreenBounds: usable)

        #expect(left.size.width == 960)
        #expect(right.origin.x == 960)
        #expect(right.size.width == 961)
        #expect(left.size.width + right.size.width == usable.size.width)
    }

    @Test("Maximize fills exact usable screen bounds")
    func maximizeCalculation() {
        let usable = CGRect(x: 0, y: 24, width: 1920, height: 1006)
        let current = CGRect(x: 200, y: 200, width: 500, height: 400)

        let target = ScreenGeometry.targetFrame(action: .maximize, currentFrame: current, usableScreenBounds: usable)

        #expect(target == usable)
    }

    @Test("Center places window in center of usable screen bounds")
    func centerCalculation() {
        let usable = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let current = CGRect(x: 0, y: 0, width: 600, height: 400)

        let target = ScreenGeometry.targetFrame(action: .center, currentFrame: current, usableScreenBounds: usable)

        #expect(target.origin.x == 200) // (1000 - 600) / 2
        #expect(target.origin.y == 200) // (800 - 400) / 2
        #expect(target.size.width == 600)
        #expect(target.size.height == 400)
    }

    @Test("Center clamps oversized window to fit screen bounds")
    func centerOversizedWindow() {
        let usable = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let current = CGRect(x: 0, y: 0, width: 1500, height: 1200)

        let target = ScreenGeometry.targetFrame(action: .center, currentFrame: current, usableScreenBounds: usable)

        #expect(target.origin.x == 0)
        #expect(target.origin.y == 0)
        #expect(target.size.width == 1000)
        #expect(target.size.height == 800)
    }

    @Test("Intersection area calculates correctly")
    func intersectionArea() {
        let a = CGRect(x: 0, y: 0, width: 100, height: 100)
        let b = CGRect(x: 50, y: 50, width: 100, height: 100)
        let area = ScreenGeometry.intersectionArea(a, b)
        #expect(area == 2500) // 50 * 50

        let c = CGRect(x: 200, y: 200, width: 50, height: 50)
        let noOverlap = ScreenGeometry.intersectionArea(a, c)
        #expect(noOverlap == 0)
    }

    @Test("Clamp keeps window entirely inside screen bounds")
    func clampOutOfBounds() {
        let usable = CGRect(x: 0, y: 24, width: 1920, height: 1056)
        let outOfBounds = CGRect(x: -200, y: 0, width: 800, height: 600)

        let clamped = ScreenGeometry.clamp(rect: outOfBounds, within: usable)

        #expect(clamped.minX >= usable.minX)
        #expect(clamped.maxX <= usable.maxX)
        #expect(clamped.minY >= usable.minY)
        #expect(clamped.maxY <= usable.maxY)
    }
}

