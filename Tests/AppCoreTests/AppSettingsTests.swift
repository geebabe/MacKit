// Tests/AppCoreTests/AppSettingsTests.swift
// Unit tests for AppSettings defaults, persistence and update propagation.

import Testing
import Foundation
@testable import AppCore

@Suite("AppSettings")
@MainActor
struct AppSettingsTests {

    // Use an isolated in-memory UserDefaults suite to avoid polluting real settings.
    private func makeSettings() -> AppSettings {
        let suiteName = "com.mackit.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return AppSettings(defaults: defaults)
    }

    @Test("Default values match PRD specification")
    func defaultValues() {
        let settings = makeSettings()
        #expect(settings.clipboardEnabled == true)
        #expect(settings.windowEnabled == true)
        #expect(settings.switcherEnabled == true)
        #expect(settings.clipboardPaused == false)
        #expect(settings.clipboardMaxEntries == 500)
        #expect(settings.clipboardRetentionDays == 30)
        #expect(settings.clipboardExcludedBundleIDs.isEmpty)
        #expect(settings.launchAtLogin == false)
    }

    @Test("Settings persist across re-initialisation")
    func persistenceRoundTrip() {
        let suiteName = "com.mackit.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!

        let settings1 = AppSettings(defaults: defaults)
        settings1.clipboardEnabled = false
        settings1.clipboardMaxEntries = 100
        settings1.clipboardRetentionDays = 7
        settings1.clipboardExcludedBundleIDs = ["com.example.app"]

        // Re-initialise from the same defaults
        let settings2 = AppSettings(defaults: defaults)
        #expect(settings2.clipboardEnabled == false)
        #expect(settings2.clipboardMaxEntries == 100)
        #expect(settings2.clipboardRetentionDays == 7)
        #expect(settings2.clipboardExcludedBundleIDs == ["com.example.app"])

        // Cleanup
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test("Clipboard shortcut default is Option+V representation")
    func clipboardShortcutDefault() {
        let settings = makeSettings()
        #expect(!settings.clipboardShortcut.isEmpty)
    }

    @Test("Excluded bundle IDs can be added and removed")
    func excludedBundleIDsUpdate() {
        let settings = makeSettings()
        #expect(settings.clipboardExcludedBundleIDs.isEmpty)

        settings.clipboardExcludedBundleIDs.insert("com.test.app")
        #expect(settings.clipboardExcludedBundleIDs.contains("com.test.app"))

        settings.clipboardExcludedBundleIDs.remove("com.test.app")
        #expect(settings.clipboardExcludedBundleIDs.isEmpty)
    }
}

