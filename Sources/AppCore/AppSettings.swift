// AppCore/AppSettings.swift
// Persistent user-facing settings using UserDefaults.
// Security note: no clipboard content or secrets stored here.

import Foundation
import Diagnostics

/// All user-configurable application settings.
/// Each property has a documented default that matches the PRD specification.
@MainActor
public final class AppSettings: ObservableObject {

    // MARK: - Module enables

    /// Whether the Clipboard Manager module is active.
    @Published public var clipboardEnabled: Bool {
        didSet { store(.clipboardEnabled, value: clipboardEnabled) }
    }

    /// Whether the Window Manager module is active.
    @Published public var windowEnabled: Bool {
        didSet { store(.windowEnabled, value: windowEnabled) }
    }

    /// Whether the Window Switcher module is active.
    @Published public var switcherEnabled: Bool {
        didSet { store(.switcherEnabled, value: switcherEnabled) }
    }

    // MARK: - Clipboard settings

    /// Whether clipboard recording is currently paused by the user.
    @Published public var clipboardPaused: Bool {
        didSet { store(.clipboardPaused, value: clipboardPaused) }
    }

    /// Maximum number of unpinned clipboard entries to retain.
    @Published public var clipboardMaxEntries: Int {
        didSet { store(.clipboardMaxEntries, value: clipboardMaxEntries) }
    }

    /// Days after which unpinned entries expire. 0 = no expiry.
    @Published public var clipboardRetentionDays: Int {
        didSet { store(.clipboardRetentionDays, value: clipboardRetentionDays) }
    }

    /// Applications excluded from clipboard capture (bundle identifiers).
    @Published public var clipboardExcludedBundleIDs: Set<String> {
        didSet { store(.clipboardExcludedBundleIDs, value: Array(clipboardExcludedBundleIDs)) }
    }

    // MARK: - Shortcut settings

    /// Key combination used to open the clipboard history (stored as serialised representation).
    @Published public var clipboardShortcut: String {
        didSet { store(.clipboardShortcut, value: clipboardShortcut) }
    }

    /// Key combination used to open the window switcher.
    @Published public var switcherShortcut: String {
        didSet { store(.switcherShortcut, value: switcherShortcut) }
    }

    /// Keyboard shortcut to snap window left.
    @Published public var snapLeftShortcut: String {
        didSet { store(.snapLeftShortcut, value: snapLeftShortcut) }
    }

    /// Keyboard shortcut to snap window right.
    @Published public var snapRightShortcut: String {
        didSet { store(.snapRightShortcut, value: snapRightShortcut) }
    }

    /// Keyboard shortcut to maximize the current window.
    @Published public var maximizeShortcut: String {
        didSet { store(.maximizeShortcut, value: maximizeShortcut) }
    }

    /// Keyboard shortcut to center the current window.
    @Published public var centerShortcut: String {
        didSet { store(.centerShortcut, value: centerShortcut) }
    }

    /// Keyboard shortcut to restore the window frame.
    @Published public var restoreShortcut: String {
        didSet { store(.restoreShortcut, value: restoreShortcut) }
    }

    // MARK: - App shell

    /// Whether MacKit should launch at login.
    @Published public var launchAtLogin: Bool {
        didSet { store(.launchAtLogin, value: launchAtLogin) }
    }

    // MARK: - Private

    private let defaults: UserDefaults
    private let logger = Logger(category: .appCore)

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // Load values — fall back to PRD-specified defaults if not set.
        clipboardEnabled = defaults.bool(forKey: Key.clipboardEnabled.rawValue, defaultValue: true)
        windowEnabled = defaults.bool(forKey: Key.windowEnabled.rawValue, defaultValue: true)
        switcherEnabled = defaults.bool(forKey: Key.switcherEnabled.rawValue, defaultValue: true)
        clipboardPaused = defaults.bool(forKey: Key.clipboardPaused.rawValue, defaultValue: false)
        clipboardMaxEntries = defaults.integer(forKey: Key.clipboardMaxEntries.rawValue, defaultValue: 500)
        clipboardRetentionDays = defaults.integer(forKey: Key.clipboardRetentionDays.rawValue, defaultValue: 30)
        clipboardExcludedBundleIDs = Set(defaults.stringArray(forKey: Key.clipboardExcludedBundleIDs.rawValue) ?? [])
        clipboardShortcut = defaults.string(forKey: Key.clipboardShortcut.rawValue) ?? "⌥V"
        switcherShortcut = defaults.string(forKey: Key.switcherShortcut.rawValue) ?? "⌃⌥Space"
        snapLeftShortcut = defaults.string(forKey: Key.snapLeftShortcut.rawValue) ?? "⌃⌥←"
        snapRightShortcut = defaults.string(forKey: Key.snapRightShortcut.rawValue) ?? "⌃⌥→"
        maximizeShortcut = defaults.string(forKey: Key.maximizeShortcut.rawValue) ?? "⌃⌥↑"
        centerShortcut = defaults.string(forKey: Key.centerShortcut.rawValue) ?? "⌃⌥C"
        restoreShortcut = defaults.string(forKey: Key.restoreShortcut.rawValue) ?? "⌃⌥↓"
        launchAtLogin = defaults.bool(forKey: Key.launchAtLogin.rawValue, defaultValue: false)
    }

    private func store(_ key: Key, value: some Any) {
        defaults.set(value, forKey: key.rawValue)
    }

    private func store(_ key: Key, value: Bool) {
        defaults.set(value, forKey: key.rawValue)
    }

    private enum Key: String {
        case clipboardEnabled = "mackit.clipboard.enabled"
        case windowEnabled = "mackit.window.enabled"
        case switcherEnabled = "mackit.switcher.enabled"
        case clipboardPaused = "mackit.clipboard.paused"
        case clipboardMaxEntries = "mackit.clipboard.maxEntries"
        case clipboardRetentionDays = "mackit.clipboard.retentionDays"
        case clipboardExcludedBundleIDs = "mackit.clipboard.excludedBundleIDs"
        case clipboardShortcut = "mackit.shortcut.clipboard"
        case switcherShortcut = "mackit.shortcut.switcher"
        case snapLeftShortcut = "mackit.shortcut.snapLeft"
        case snapRightShortcut = "mackit.shortcut.snapRight"
        case maximizeShortcut = "mackit.shortcut.maximize"
        case centerShortcut = "mackit.shortcut.center"
        case restoreShortcut = "mackit.shortcut.restore"
        case launchAtLogin = "mackit.app.launchAtLogin"
    }
}

// MARK: - UserDefaults helpers

private extension UserDefaults {
    func bool(forKey key: String, defaultValue: Bool) -> Bool {
        return object(forKey: key) != nil ? bool(forKey: key) : defaultValue
    }

    func integer(forKey key: String, defaultValue: Int) -> Int {
        return object(forKey: key) != nil ? integer(forKey: key) : defaultValue
    }
}

