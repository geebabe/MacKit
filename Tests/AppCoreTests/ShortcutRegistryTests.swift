// Tests/AppCoreTests/ShortcutRegistryTests.swift
// Unit tests for shortcut conflict detection and registration lifecycle.

import Testing
import AppKit
@testable import AppCore

@Suite("ShortcutRegistry")
@MainActor
struct ShortcutRegistryTests {

    private func makeRegistry() -> ShortcutRegistry {
        ShortcutRegistry()
    }

    @Test("Registering a new shortcut succeeds")
    func registerNew() {
        let registry = makeRegistry()
        let reg = ShortcutRegistration(
            id: "test.action",
            displayName: "Test Action",
            keyEquivalent: "t",
            modifierFlags: [.command, .shift]
        )
        let result = registry.register(reg)
        guard case .success = result else {
            Issue.record("Expected success, got \(result)")
            return
        }
        #expect(registry.registrations.count == 1)
        #expect(registry.conflicts.isEmpty)
    }

    @Test("Re-registering the same ID replaces it without conflict")
    func reregisterSameID() {
        let registry = makeRegistry()
        let reg1 = ShortcutRegistration(id: "test.action", displayName: "Test", keyEquivalent: "t", modifierFlags: [.command])
        let reg2 = ShortcutRegistration(id: "test.action", displayName: "Test Updated", keyEquivalent: "u", modifierFlags: [.command])

        _ = registry.register(reg1)
        let result = registry.register(reg2)

        guard case .success = result else {
            Issue.record("Expected success, got \(result)")
            return
        }
        #expect(registry.registrations.count == 1)
        #expect(registry.registrations.first?.keyEquivalent == "u")
        #expect(registry.conflicts.isEmpty)
    }

    @Test("Conflicting shortcut is detected and reported")
    func conflictDetection() {
        let registry = makeRegistry()
        let reg1 = ShortcutRegistration(id: "action.a", displayName: "Action A", keyEquivalent: "k", modifierFlags: [.control, .option])
        let reg2 = ShortcutRegistration(id: "action.b", displayName: "Action B", keyEquivalent: "k", modifierFlags: [.control, .option])

        _ = registry.register(reg1)
        let result = registry.register(reg2)

        guard case .failure(let error) = result else {
            Issue.record("Expected failure, got \(result)")
            return
        }
        guard case .shortcutConflict = error else {
            Issue.record("Expected shortcutConflict error, got \(error)")
            return
        }
        #expect(!registry.conflicts.isEmpty)
    }

    @Test("Unregistering removes the shortcut")
    func unregister() {
        let registry = makeRegistry()
        let reg = ShortcutRegistration(id: "test.action", displayName: "Test", keyEquivalent: "t", modifierFlags: [.command])
        _ = registry.register(reg)
        registry.unregister(id: "test.action")
        #expect(registry.registrations.isEmpty)
    }

    @Test("Different modifier flags do not conflict")
    func differentModifiersNoConflict() {
        let registry = makeRegistry()
        let reg1 = ShortcutRegistration(id: "action.a", displayName: "A", keyEquivalent: "k", modifierFlags: [.control])
        let reg2 = ShortcutRegistration(id: "action.b", displayName: "B", keyEquivalent: "k", modifierFlags: [.command])

        _ = registry.register(reg1)
        let result = registry.register(reg2)

        guard case .success = result else {
            Issue.record("Expected success, got \(result)")
            return
        }
        #expect(registry.conflicts.isEmpty)
        #expect(registry.registrations.count == 2)
    }

    @Test("Unregister by prefix removes module shortcuts")
    func unregisterByPrefix() {
        let registry = makeRegistry()
        _ = registry.register(ShortcutRegistration(id: "clipboard.open", displayName: "A", keyEquivalent: "v", modifierFlags: [.option]))
        _ = registry.register(ShortcutRegistration(id: "window.snapLeft", displayName: "B", keyEquivalent: "a", modifierFlags: [.control]))
        _ = registry.register(ShortcutRegistration(id: "window.snapRight", displayName: "C", keyEquivalent: "d", modifierFlags: [.control]))

        registry.unregisterAll(prefix: "window")
        #expect(registry.registrations.count == 1)
        #expect(registry.registrations.first?.id == "clipboard.open")
    }
}

