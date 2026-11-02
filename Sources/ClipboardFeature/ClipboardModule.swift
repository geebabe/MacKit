// ClipboardFeature/ClipboardModule.swift
// Clipboard Manager module coordinator.
// Milestone 1: Module shell, lifecycle, and state management.
// Clipboard capture and history UI are implemented in Milestone 2.

import Foundation
import AppCore
import SecureStorage
import Diagnostics

/// The operational state of the Clipboard module.
public enum ClipboardModuleState: Equatable, Sendable {
    case idle           // Module enabled but not yet started
    case monitoring     // Actively watching the clipboard
    case paused         // User-paused; no new entries recorded
    case disabled       // Module disabled in Settings
    case permissionRequired // Clipboard access not granted
    case error(String)  // Non-recoverable error description (no content)

    public var displayDescription: String {
        switch self {
        case .idle: return "Ready"
        case .monitoring: return "Monitoring clipboard"
        case .paused: return "Paused — not recording"
        case .disabled: return "Disabled"
        case .permissionRequired: return "Clipboard permission required"
        case .error(let msg): return "Error: \(msg)"
        }
    }
}

/// Actor-isolated clipboard module coordinator.
public actor ClipboardModule {

    public private(set) var state: ClipboardModuleState = .idle
    private let logger = Logger(category: .clipboard)

    public init() {}

    /// Start the module if enabled and permission is available.
    public func start(settings: AppSettings, permissionMonitor: PermissionMonitor) async {
        guard await settings.clipboardEnabled else {
            await setState(.disabled)
            return
        }

        // NOTE: Full clipboard permission check and NSPasteboard observation
        // are implemented in Milestone 2. For Milestone 1 we establish the state machine.
        await setState(.idle)
        logger.info("ClipboardModule started (capture implementation pending Milestone 2)")
    }

    /// Stop monitoring and release resources.
    public func stop() async {
        await setState(.idle)
        logger.info("ClipboardModule stopped")
    }

    // MARK: - Private

    private func setState(_ newState: ClipboardModuleState) async {
        state = newState
    }
}

// MARK: - MainActor bridge for settings access
extension ClipboardModule {
    @MainActor
    func start(settings: AppSettings, permissionMonitor: PermissionMonitor) {
        Task { await self.start(settings: settings, permissionMonitor: permissionMonitor) }
    }
}

