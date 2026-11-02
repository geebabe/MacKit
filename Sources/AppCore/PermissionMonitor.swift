// AppCore/PermissionMonitor.swift
// Tracks macOS permission status for MacKit's required entitlements.
// Uses only public APIs. Never modifies TCC or permission databases.

import Foundation
import AppKit
@preconcurrency import ApplicationServices
import Diagnostics

/// The live status of a macOS permission from MacKit's perspective.
public enum PermissionStatus: Equatable, Sendable {
    case granted
    case denied
    case undetermined
    /// The permission check could not be completed (unusual state).
    case unknown(String)

    public var isGranted: Bool { self == .granted }

    /// User-visible label for this status.
    public var displayLabel: String {
        switch self {
        case .granted: return "Granted"
        case .denied: return "Denied"
        case .undetermined: return "Not Requested"
        case .unknown: return "Unknown"
        }
    }

    public var systemImageName: String {
        switch self {
        case .granted: return "checkmark.circle.fill"
        case .denied: return "xmark.circle.fill"
        case .undetermined: return "questionmark.circle.fill"
        case .unknown: return "exclamationmark.circle.fill"
        }
    }
}

/// Observable object that reports the current permission status for each
/// MacKit-required entitlement. Refreshed on demand and on app activation.
@MainActor
public final class PermissionMonitor: ObservableObject {

    @Published public private(set) var accessibilityStatus: PermissionStatus = .undetermined

    private let logger = Logger(category: .permissions)

    public init() {}

    /// Refresh all permission states. Call this on app activation and from Settings.
    public func refresh() {
        accessibilityStatus = checkAccessibility()
        logger.info("Permissions refreshed — Accessibility: \(accessibilityStatus.displayLabel)")
    }

    /// Request Accessibility permission by opening the system prompt.
    /// macOS shows the dialog only the first time; subsequent calls may be no-ops.
    public func requestAccessibility() {
        _ = requestAccessibilityPrompt()
        // Refresh after a short delay to pick up the result.
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            self.refresh()
        }
    }

    @MainActor
    private func requestAccessibilityPrompt() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue()
        let options = [key: kCFBooleanTrue] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Open System Settings at the correct Privacy pane for the given permission.
    public func openSystemSettings(for permission: Permission) {
        let urlString: String
        switch permission {
        case .accessibility:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        case .clipboard:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Pasteboard"
        }
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Private checks

    private func checkAccessibility() -> PermissionStatus {
        let trusted = AXIsProcessTrusted()
        return trusted ? .granted : .denied
    }
}
