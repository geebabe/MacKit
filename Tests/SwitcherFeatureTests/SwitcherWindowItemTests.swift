// Tests/SwitcherFeatureTests/SwitcherWindowItemTests.swift
// Tests for SwitcherWindowItem model invariants and display titles.

import Testing
import Foundation
@testable import SwitcherFeature

@Suite("SwitcherWindowItem")
struct SwitcherWindowItemTests {

    @Test("Display title returns window title when non-empty")
    func displayTitleNonEmpty() {
        let item = SwitcherWindowItem(
            id: "test-1",
            processIdentifier: 100,
            appName: "Safari",
            windowTitle: "Apple Developer Documentation"
        )
        #expect(item.displayTitle == "Apple Developer Documentation")
    }

    @Test("Display title falls back to app name when window title is empty")
    func displayTitleFallback() {
        let emptyTitleItem = SwitcherWindowItem(
            id: "test-2",
            processIdentifier: 200,
            appName: "Calculator",
            windowTitle: ""
        )
        #expect(emptyTitleItem.displayTitle == "Calculator")

        let whitespaceItem = SwitcherWindowItem(
            id: "test-3",
            processIdentifier: 200,
            appName: "Finder",
            windowTitle: "   \n  "
        )
        #expect(whitespaceItem.displayTitle == "Finder")
    }

    @Test("Window equality respects ID, PID, title, and minimized state")
    func equality() {
        let item1 = SwitcherWindowItem(id: "1", processIdentifier: 50, appName: "TextEdit", windowTitle: "Notes.txt", isMinimized: false)
        let item2 = SwitcherWindowItem(id: "1", processIdentifier: 50, appName: "TextEdit", windowTitle: "Notes.txt", isMinimized: false)
        let itemMinimized = SwitcherWindowItem(id: "1", processIdentifier: 50, appName: "TextEdit", windowTitle: "Notes.txt", isMinimized: true)

        #expect(item1 == item2)
        #expect(item1 != itemMinimized)
    }
}

