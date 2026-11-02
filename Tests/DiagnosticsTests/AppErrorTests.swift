// Tests/DiagnosticsTests/AppErrorTests.swift
// Tests for error classification and descriptions.

import Testing
@testable import Diagnostics

@Suite("AppError")
struct AppErrorTests {

    @Test("Storage error descriptions are non-empty and non-sensitive")
    func storageErrorDescriptions() {
        let errors: [StorageError] = [
            .openFailed("reason"),
            .writeFailed("reason"),
            .readFailed("reason"),
            .migrationFailed("reason"),
            .diskFull,
            .corruptedData("detail"),
            .orphanedFile("path")
        ]
        for e in errors {
            #expect(!e.description.isEmpty)
        }
    }

    @Test("CryptoError descriptions are non-empty and non-sensitive")
    func cryptoErrorDescriptions() {
        let errors: [CryptoError] = [
            .keyGenerationFailed,
            .keyStoreFailed("reason"),
            .keyLoadFailed("reason"),
            .encryptionFailed("reason"),
            .decryptionFailed("reason"),
            .authenticationTagInvalid,
            .unsupportedVersion(99)
        ]
        for e in errors {
            #expect(!e.description.isEmpty)
        }
    }

    @Test("ClipboardRejectionReason descriptions are non-empty")
    func rejectionReasonDescriptions() {
        let reasons: [ClipboardRejectionReason] = [
            .payloadTooLarge(kind: "text", sizeBytes: 1_000_000, limitBytes: 500_000),
            .unsupportedFormat("application/pdf"),
            .concealed,
            .transient,
            .excludedApplication("com.example.app"),
            .paused,
            .duplicate,
            .moduleDisabled
        ]
        for r in reasons {
            #expect(!r.description.isEmpty)
            // Rejection reasons must not contain payload data (we only describe the format/source)
        }
    }

    @Test("Permission usage descriptions are non-empty")
    func permissionDescriptions() {
        for permission in Permission.allCases {
            #expect(!permission.usageDescription.isEmpty)
            #expect(!permission.recoveryInstructions.isEmpty)
            #expect(!permission.rawValue.isEmpty)
        }
    }

    @Test("WindowError descriptions are non-empty")
    func windowErrorDescriptions() {
        let errors: [WindowError] = [
            .windowNotFound,
            .notResizable,
            .accessibilityUnavailable("reason"),
            .frameOutOfBounds,
            .activationFailed("reason")
        ]
        for e in errors {
            #expect(!e.description.isEmpty)
        }
    }

    @Test("AppError top-level descriptions are non-empty")
    func appErrorDescriptions() {
        let errors: [AppError] = [
            .storageFailed(.diskFull),
            .cryptoFailed(.keyGenerationFailed),
            .permissionDenied(.accessibility),
            .permissionUndetermined(.clipboard),
            .clipboardItemRejected(.paused),
            .windowOperationFailed(.windowNotFound),
            .shortcutConflict("test conflict"),
            .shortcutRegistrationFailed("test"),
            .internalInconsistency("test"),
            .moduleDisabled("clipboard")
        ]
        for e in errors {
            #expect(!e.description.isEmpty)
        }
    }
}

