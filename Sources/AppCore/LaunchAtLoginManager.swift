// AppCore/LaunchAtLoginManager.swift
// Manages Launch at Login using ServiceManagement (public API, no privileged helper).

import Foundation
import ServiceManagement
import Diagnostics

/// Manages the macOS Launch at Login state using SMAppService.
@MainActor
public final class LaunchAtLoginManager: ObservableObject {

    @Published public private(set) var isRegistered: Bool = false

    private let logger = Logger(category: .appCore)

    public init() {
        refresh()
    }

    /// Refresh the actual system-registered state.
    public func refresh() {
        isRegistered = SMAppService.mainApp.status == .enabled
    }

    /// Enable or disable launch at login, then verify the resulting state.
    public func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            refresh()
            logger.info("Launch at login set to \(enabled), verified: \(isRegistered)")
        } catch {
            logger.error("Failed to \(enabled ? "enable" : "disable") launch at login: \(error.localizedDescription)")
            refresh() // Reflect actual state after failure
        }
    }
}

