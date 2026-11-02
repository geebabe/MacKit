// Tests/WindowFeatureTests/WindowActionTests.swift
// Tests for WindowAction enumeration, titles, and system images.

import Testing
@testable import WindowFeature

@Suite("WindowAction")
struct WindowActionTests {

    @Test("All window actions have non-empty titles and system images")
    func actionMetadata() {
        for action in WindowAction.allCases {
            #expect(!action.displayTitle.isEmpty)
            #expect(!action.systemImageName.isEmpty)
            #expect(!action.rawValue.isEmpty)
        }
    }

    @Test("All required actions are present in WindowAction")
    func requiredActionsPresent() {
        let cases = WindowAction.allCases
        #expect(cases.contains(.snapLeft))
        #expect(cases.contains(.snapRight))
        #expect(cases.contains(.maximize))
        #expect(cases.contains(.center))
        #expect(cases.contains(.restore))
    }
}
