// SwitcherFeature/MRUTracker.swift
// Tracks Most Recently Used (MRU) order of windows based on focus observations.

import Foundation

/// Thread-safe tracker maintaining approximate Most Recently Used order for windows.
public struct MRUTracker: Sendable {

    private var focusTimestamps: [String: Date] = [:]

    public init() {}

    /// Records focus for a given window identifier at the specified date.
    public mutating func recordFocus(windowID: String, at date: Date = Date()) {
        focusTimestamps[windowID] = date
    }

    /// Retrieve the last focused timestamp for a given window.
    public func lastFocused(windowID: String) -> Date? {
        focusTimestamps[windowID]
    }

    /// Sorts a collection of windows by MRU:
    /// 1. Windows with recorded focus ordered by timestamp DESC.
    /// 2. Windows with no recorded focus ordered by their original order or lastFocusedAt.
    public func sortMRU(items: [SwitcherWindowItem]) -> [SwitcherWindowItem] {
        return items.sorted { a, b in
            let dateA = focusTimestamps[a.id] ?? a.lastFocusedAt
            let dateB = focusTimestamps[b.id] ?? b.lastFocusedAt
            if dateA != dateB {
                return dateA > dateB
            }
            return a.appName < b.appName
        }
    }

    /// Removes stale tracking entries for windows that no longer exist.
    public mutating func prune(activeIDs: Set<String>) {
        focusTimestamps = focusTimestamps.filter { activeIDs.contains($0.key) }
    }
}

