// Tests/AppCoreTests/PermissionMonitorTests.swift
// Unit tests for PermissionStatus and PermissionMonitor.

import Testing
@testable import AppCore

@Suite("PermissionMonitor")
struct PermissionMonitorTests {

    @Test("PermissionStatus display labels and system images cover all cases")
    func permissionStatusLabels() {
        let statuses: [PermissionStatus] = [.granted, .denied, .undetermined, .unknown("test")]
        for s in statuses {
            #expect(!s.displayLabel.isEmpty)
            #expect(!s.systemImageName.isEmpty)
        }
        #expect(PermissionStatus.granted.isGranted)
        #expect(!PermissionStatus.denied.isGranted)
        #expect(!PermissionStatus.undetermined.isGranted)
        #expect(!PermissionStatus.unknown("test").isGranted)
    }

    @Test("PermissionMonitor initializes with undetermined state before refresh")
    @MainActor
    func initialStatus() {
        let monitor = PermissionMonitor()
        #expect(monitor.accessibilityStatus == .undetermined)
    }
}
