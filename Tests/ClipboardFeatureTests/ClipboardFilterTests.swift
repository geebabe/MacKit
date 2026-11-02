// Tests/ClipboardFeatureTests/ClipboardFilterTests.swift
// Tests for privacy filters, concealed markers, exclusions, and payload limits.

import Testing
import AppKit
@testable import ClipboardFeature
@testable import Diagnostics

@Suite("ClipboardFilter")
struct ClipboardFilterTests {

    let filter = ClipboardFilter()

    @Test("Concealed type is detected and rejected")
    func concealedTypeDetected() {
        let types: [NSPasteboard.PasteboardType] = [
            .string,
            SensitivePasteboardType.concealed
        ]
        #expect(filter.isConcealedOrTransient(types: types))
    }

    @Test("Transient type is detected and rejected")
    func transientTypeDetected() {
        let types: [NSPasteboard.PasteboardType] = [
            .string,
            SensitivePasteboardType.transient
        ]
        #expect(filter.isConcealedOrTransient(types: types))
    }

    @Test("1Password marker is detected and rejected")
    func onePasswordMarkerDetected() {
        let types: [NSPasteboard.PasteboardType] = [
            .string,
            SensitivePasteboardType.onePassword
        ]
        #expect(filter.isConcealedOrTransient(types: types))
    }

    @Test("Standard non-sensitive types are accepted")
    func standardTypesAccepted() {
        let types: [NSPasteboard.PasteboardType] = [
            .string,
            .URL,
            .png
        ]
        #expect(!filter.isConcealedOrTransient(types: types))
    }

    @Test("Excluded app bundle identifier is rejected")
    func excludedAppRejected() {
        let exclusions: Set<String> = ["com.agilebits.onepassword7", "org.keepassxc.keepassxc"]
        #expect(filter.isAppExcluded(bundleID: "com.agilebits.onepassword7", excludedBundleIDs: exclusions))
        #expect(!filter.isAppExcluded(bundleID: "com.apple.Safari", excludedBundleIDs: exclusions))
        #expect(!filter.isAppExcluded(bundleID: nil, excludedBundleIDs: exclusions))
    }

    @Test("Text size within 10 MiB limit is accepted")
    func textSizeWithinLimit() {
        let result = filter.validateTextSize(byteCount: 5 * 1024 * 1024)
        guard case .success = result else {
            Issue.record("Expected success for valid text size")
            return
        }
    }

    @Test("Text size exceeding 10 MiB limit is rejected")
    func textSizeExceedingLimit() {
        let result = filter.validateTextSize(byteCount: 11 * 1024 * 1024)
        guard case .failure(let reason) = result else {
            Issue.record("Expected failure for oversized text")
            return
        }
        guard case .payloadTooLarge = reason else {
            Issue.record("Expected payloadTooLarge error, got \(reason)")
            return
        }
    }

    @Test("Image size within 25 MiB limit is accepted")
    func imageSizeWithinLimit() {
        let result = filter.validateImageSize(byteCount: 20 * 1024 * 1024)
        guard case .success = result else {
            Issue.record("Expected success for valid image size")
            return
        }
    }

    @Test("Image size exceeding 25 MiB limit is rejected")
    func imageSizeExceedingLimit() {
        let result = filter.validateImageSize(byteCount: 26 * 1024 * 1024)
        guard case .failure(let reason) = result else {
            Issue.record("Expected failure for oversized image")
            return
        }
        guard case .payloadTooLarge = reason else {
            Issue.record("Expected payloadTooLarge error, got \(reason)")
            return
        }
    }
}
