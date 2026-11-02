// SwitcherFeature/SwitcherModule.swift
// Window Switcher module coordinator.
// Milestone 1: Module shell and lifecycle.
// MRU tracking and switcher UI implemented in Milestone 4.

import Foundation
import AppCore
import Diagnostics

/// Actor-isolated Window Switcher module coordinator.
public actor SwitcherModule {

    public private(set) var isActive: Bool = false
    private let logger = Logger(category: .switcher)

    public init() {}

    public func start(settings: AppSettings) async {
        guard await settings.switcherEnabled else {
            logger.info("SwitcherModule is disabled")
            return
        }
        isActive = true
        logger.info("SwitcherModule started (switcher UI implemented in Milestone 4)")
    }

    public func stop() async {
        isActive = false
        logger.info("SwitcherModule stopped")
    }
}

// MARK: - MainActor bridge
extension SwitcherModule {
    @MainActor
    func start(settings: AppSettings) {
        Task { await self.start(settings: settings) }
    }
}

