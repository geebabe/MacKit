// AppCore/ShortcutRegistry.swift
// Centralized shortcut registry. Detects intra-MacKit conflicts.
// Global hotkey registration uses CGEventTap (public API).
// NOTE: For Milestone 1, registration plumbing is wired but hotkeys fire in Milestone 2.

import Foundation
import AppKit
import Diagnostics

/// A registered shortcut entry within MacKit.
public struct ShortcutRegistration: Identifiable, Sendable {
    public let id: String          // Unique name, e.g. "clipboard.open"
    public let displayName: String // Human-readable name shown in Settings
    public let keyEquivalent: String
    public let modifierFlags: NSEvent.ModifierFlags

    public init(id: String, displayName: String, keyEquivalent: String, modifierFlags: NSEvent.ModifierFlags) {
        self.id = id
        self.displayName = displayName
        self.keyEquivalent = keyEquivalent
        self.modifierFlags = modifierFlags
    }
}

/// Thread-safe registry of MacKit global shortcuts.
/// Detects duplicate registrations within MacKit; reports them explicitly.
@MainActor
public final class ShortcutRegistry: ObservableObject {

    @Published public private(set) var registrations: [ShortcutRegistration] = []
    @Published public private(set) var conflicts: [String] = []  // human-readable descriptions

    private let logger = Logger(category: .shortcuts)

    public init() {}

    /// Register a shortcut. Returns an error if it conflicts with an existing MacKit registration.
    /// Does not throw; conflicts are surfaced through `conflicts` publisher.
    @discardableResult
    public func register(_ registration: ShortcutRegistration) -> Result<Void, AppError> {
        // Check for intra-MacKit conflict
        if let existing = registrations.first(where: { conflictsWithExisting($0, candidate: registration) }) {
            let description = "'\(registration.displayName)' conflicts with '\(existing.displayName)' — both use \(registration.keyEquivalent)"
            logger.warning(description)
            if !conflicts.contains(description) {
                conflicts.append(description)
            }
            return .failure(.shortcutConflict(description))
        }

        // Remove any previous registration for the same ID
        registrations.removeAll { $0.id == registration.id }
        registrations.append(registration)
        logger.info("Shortcut registered: \(registration.id) = \(registration.keyEquivalent)")
        return .success(())
    }

    /// Unregister a shortcut by ID.
    public func unregister(id: String) {
        registrations.removeAll { $0.id == id }
        // Clear any conflicts that mentioned this ID
        conflicts.removeAll { $0.contains(id) }
        logger.info("Shortcut unregistered: \(id)")
    }

    /// Unregister all shortcuts for a given module prefix (e.g. "clipboard").
    public func unregisterAll(prefix: String) {
        let toRemove = registrations.filter { $0.id.hasPrefix(prefix) }
        for r in toRemove { unregister(id: r.id) }
    }

    // MARK: - Private helpers

    private func conflictsWithExisting(_ existing: ShortcutRegistration, candidate: ShortcutRegistration) -> Bool {
        guard existing.id != candidate.id else { return false }
        return existing.keyEquivalent == candidate.keyEquivalent &&
               existing.modifierFlags == candidate.modifierFlags
    }
}

