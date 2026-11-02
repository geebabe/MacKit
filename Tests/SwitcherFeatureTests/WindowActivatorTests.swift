// Tests/SwitcherFeatureTests/WindowActivatorTests.swift
// Tests for WindowActivator error handling and state validation.

import Testing
import Foundation
@testable import SwitcherFeature
@testable import Diagnostics

@Suite("WindowActivator")
struct WindowActivatorTests {

    let activator = WindowActivator()

    @Test("Activating a dead or invalid PID returns activationFailed failure")
    func invalidPIDFailsGracefully() {
        // PID 999999 is nonexistent
        let item = SwitcherWindowItem(
            id: "dead-pid-test",
            processIdentifier: 999_999,
            appName: "NonExistentApp",
            windowTitle: "Ghost Window"
        )

        let result = activator.activateWindow(item: item)
        guard case .failure(let error) = result else {
            Issue.record("Expected failure for non-existent PID")
            return
        }
        guard case .activationFailed = error else {
            Issue.record("Expected activationFailed error, got \(error)")
            return
        }
    }
}
