// Tests/SwitcherFeatureTests/MRUTrackerTests.swift
// Tests for Most Recently Used (MRU) window focus tracking and ordering.

import Testing
import Foundation
@testable import SwitcherFeature

@Suite("MRUTracker")
struct MRUTrackerTests {

    private func makeItem(id: String, appName: String, title: String, date: Date = Date()) -> SwitcherWindowItem {
        SwitcherWindowItem(
            id: id,
            processIdentifier: 1000,
            appName: appName,
            windowTitle: title,
            lastFocusedAt: date
        )
    }

    @Test("Focused window is ordered first in MRU list")
    func focusedWindowFirst() {
        var tracker = MRUTracker()
        let now = Date()

        let item1 = makeItem(id: "win-1", appName: "Safari", title: "Apple", date: now.addingTimeInterval(-100))
        let item2 = makeItem(id: "win-2", appName: "Terminal", title: "zsh", date: now.addingTimeInterval(-50))
        let item3 = makeItem(id: "win-3", appName: "Notes", title: "Ideas", date: now.addingTimeInterval(-10))

        let sortedInitial = tracker.sortMRU(items: [item1, item2, item3])
        #expect(sortedInitial.first?.id == "win-3")

        // Now record focus on item1
        tracker.recordFocus(windowID: "win-1", at: now.addingTimeInterval(10))

        let sortedAfterFocus = tracker.sortMRU(items: [item1, item2, item3])
        #expect(sortedAfterFocus.first?.id == "win-1")
    }

    @Test("Sequential focus operations update ordering dynamically")
    func sequentialFocusOrdering() {
        var tracker = MRUTracker()
        let t0 = Date()

        let w1 = makeItem(id: "w1", appName: "A", title: "1")
        let w2 = makeItem(id: "w2", appName: "B", title: "2")
        let w3 = makeItem(id: "w3", appName: "C", title: "3")

        tracker.recordFocus(windowID: "w1", at: t0.addingTimeInterval(1))
        tracker.recordFocus(windowID: "w2", at: t0.addingTimeInterval(2))
        tracker.recordFocus(windowID: "w3", at: t0.addingTimeInterval(3))

        let order1 = tracker.sortMRU(items: [w1, w2, w3]).map(\.id)
        #expect(order1 == ["w3", "w2", "w1"])

        // User switches back to w1
        tracker.recordFocus(windowID: "w1", at: t0.addingTimeInterval(4))
        let order2 = tracker.sortMRU(items: [w1, w2, w3]).map(\.id)
        #expect(order2 == ["w1", "w3", "w2"])
    }

    @Test("Pruning removes stale window records")
    func pruningStaleWindows() {
        var tracker = MRUTracker()
        tracker.recordFocus(windowID: "active-1")
        tracker.recordFocus(windowID: "closed-window")

        tracker.prune(activeIDs: ["active-1"])

        #expect(tracker.lastFocused(windowID: "active-1") != nil)
        #expect(tracker.lastFocused(windowID: "closed-window") == nil)
    }
}
