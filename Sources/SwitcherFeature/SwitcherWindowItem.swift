// SwitcherFeature/SwitcherWindowItem.swift
// Model representing an individual on-screen or minimized window.
// No thumbnails, no Screen Recording permission required.

import Foundation
import AppKit

/// Representation of an eligible window in the Window Switcher.
public struct SwitcherWindowItem: Identifiable, Sendable, Equatable {
    public let id: String
    public let processIdentifier: pid_t
    public let bundleIdentifier: String?
    public let appName: String
    public let windowTitle: String
    public let isMinimized: Bool
    public var lastFocusedAt: Date

    public init(
        id: String,
        processIdentifier: pid_t,
        bundleIdentifier: String? = nil,
        appName: String,
        windowTitle: String,
        isMinimized: Bool = false,
        lastFocusedAt: Date = Date()
    ) {
        self.id = id
        self.processIdentifier = processIdentifier
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
        self.windowTitle = windowTitle
        self.isMinimized = isMinimized
        self.lastFocusedAt = lastFocusedAt
    }

    /// User-visible title (falls back to app name if window has no title).
    public var displayTitle: String {
        let trimmed = windowTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? appName : trimmed
    }

    public static func == (lhs: SwitcherWindowItem, rhs: SwitcherWindowItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.processIdentifier == rhs.processIdentifier &&
        lhs.windowTitle == rhs.windowTitle &&
        lhs.isMinimized == rhs.isMinimized
    }
}

