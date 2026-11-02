// WindowFeature/WindowRestoreStore.swift
// In-memory store for saving and restoring window frames before snap operations.

import Foundation
import CoreGraphics

/// Unique key identifying a window across snap operations without using private SPIs.
public struct WindowIdentity: Hashable, Sendable {
    public let processIdentifier: pid_t
    public let windowTitle: String

    public init(processIdentifier: pid_t, windowTitle: String) {
        self.processIdentifier = processIdentifier
        self.windowTitle = windowTitle
    }
}

/// Stores previous frames of windows to enable the "Restore" operation.
@MainActor
public final class WindowRestoreStore {

    private var frames: [WindowIdentity: CGRect] = [:]

    public init() {}

    /// Save the original frame for a window before applying a new layout.
    public func saveFrame(_ frame: CGRect, for identity: WindowIdentity) {
        frames[identity] = frame
    }

    /// Retrieve the saved frame for a window.
    public func getFrame(for identity: WindowIdentity) -> CGRect? {
        return frames[identity]
    }

    /// Retrieve and remove the saved frame.
    public func popFrame(for identity: WindowIdentity) -> CGRect? {
        return frames.removeValue(forKey: identity)
    }

    /// Clear all stored frames (e.g. on display changes).
    public func clearAll() {
        frames.removeAll()
    }
}

