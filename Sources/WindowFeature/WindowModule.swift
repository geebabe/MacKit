// WindowFeature/WindowModule.swift
// Window Manager module coordinator.
// Milestone 1: Module shell and lifecycle.
// Snap/center/maximize operations implemented in Milestone 3.

import Foundation
import AppCore
import Diagnostics

/// Actor-isolated Window Manager module coordinator.
public actor WindowModule {

    public private(set) var isActive: Bool = false
    private let logger = Logger(category: .window)

    public init() {}

    public func start(settings: AppSettings) async {
        guard await settings.windowEnabled else {
            logger.info("WindowModule is disabled")
            return
        }
        isActive = true
        logger.info("WindowModule started (operations implemented in Milestone 3)")
    }

    public func stop() async {
        isActive = false
        logger.info("WindowModule stopped")
    }
}

// MARK: - MainActor bridge
extension WindowModule {
    @MainActor
    func start(settings: AppSettings) {
        Task { await self.start(settings: settings) }
    }
}

