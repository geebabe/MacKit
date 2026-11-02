// WindowFeature/WindowModule.swift
// Window Manager module coordinator.
// Orchestrates window snapping, maximization, centering, and restoration.

import Foundation
import CoreGraphics
import AppCore
import Diagnostics

/// MainActor coordinator for the Window Manager module.
@MainActor
public final class WindowModule: ObservableObject {

    @Published public private(set) var isActive: Bool = false
    public let manager = WindowManager()
    private let logger = Logger(category: .window)
    private var settings: AppSettings?

    public init() {}

    /// Start the Window Manager module.
    public func start(settings: AppSettings) {
        self.settings = settings
        guard settings.windowEnabled else {
            isActive = false
            logger.info("WindowModule is disabled in settings")
            return
        }
        isActive = true
        logger.info("WindowModule started and active")
    }

    /// Stop the Window Manager module.
    public func stop() {
        isActive = false
        manager.restoreStore.clearAll()
        logger.info("WindowModule stopped")
    }

    /// Execute a window action if the module is active.
    @discardableResult
    public func performAction(_ action: WindowAction) -> Result<CGRect, AppError> {
        guard isActive else {
            logger.info("Window action '\(action.displayTitle)' ignored: module disabled")
            return .failure(.moduleDisabled("Window Manager"))
        }
        return manager.performAction(action)
    }
}
