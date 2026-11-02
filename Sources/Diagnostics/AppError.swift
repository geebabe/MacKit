// Diagnostics/AppError.swift
// Structured, typed error classification for MacKit.
// Error messages must NOT contain clipboard content or secrets.

import Foundation

/// Top-level error domain for MacKit.
public enum AppError: Error, Sendable, CustomStringConvertible {

    // MARK: - Storage

    /// SQLite or file-system storage failure.
    case storageFailed(StorageError)

    /// Encryption or key management failure.
    case cryptoFailed(CryptoError)

    // MARK: - Permissions

    /// A required macOS permission is not granted.
    case permissionDenied(Permission)

    /// A required macOS permission is not yet determined.
    case permissionUndetermined(Permission)

    // MARK: - Clipboard

    /// A clipboard item was rejected for a non-sensitive reason.
    case clipboardItemRejected(ClipboardRejectionReason)

    // MARK: - Window

    /// A window operation could not be completed.
    case windowOperationFailed(WindowError)

    // MARK: - Shortcuts

    /// A global shortcut conflict was detected.
    case shortcutConflict(String)

    /// A global shortcut could not be registered.
    case shortcutRegistrationFailed(String)

    // MARK: - Generic

    /// An internal invariant was violated. Should never reach production.
    case internalInconsistency(String)

    /// An operation was attempted while the relevant module is disabled.
    case moduleDisabled(String)

    public var description: String {
        switch self {
        case .storageFailed(let e): return "Storage error: \(e)"
        case .cryptoFailed(let e): return "Crypto error: \(e)"
        case .permissionDenied(let p): return "Permission denied: \(p)"
        case .permissionUndetermined(let p): return "Permission undetermined: \(p)"
        case .clipboardItemRejected(let r): return "Clipboard item rejected: \(r)"
        case .windowOperationFailed(let e): return "Window operation failed: \(e)"
        case .shortcutConflict(let s): return "Shortcut conflict: \(s)"
        case .shortcutRegistrationFailed(let s): return "Shortcut registration failed: \(s)"
        case .internalInconsistency(let s): return "Internal inconsistency: \(s)"
        case .moduleDisabled(let s): return "Module disabled: \(s)"
        }
    }
}

public enum StorageError: Error, Sendable, CustomStringConvertible {
    case openFailed(String)
    case writeFailed(String)
    case readFailed(String)
    case migrationFailed(String)
    case diskFull
    case corruptedData(String)
    case orphanedFile(String)

    public var description: String {
        switch self {
        case .openFailed(let s): return "Open failed: \(s)"
        case .writeFailed(let s): return "Write failed: \(s)"
        case .readFailed(let s): return "Read failed: \(s)"
        case .migrationFailed(let s): return "Migration failed: \(s)"
        case .diskFull: return "Disk full"
        case .corruptedData(let s): return "Corrupted data: \(s)"
        case .orphanedFile(let s): return "Orphaned file: \(s)"
        }
    }
}

public enum CryptoError: Error, Sendable, CustomStringConvertible {
    case keyGenerationFailed
    case keyStoreFailed(String)
    case keyLoadFailed(String)
    case encryptionFailed(String)
    case decryptionFailed(String)
    case authenticationTagInvalid
    case unsupportedVersion(Int)

    public var description: String {
        switch self {
        case .keyGenerationFailed: return "Key generation failed"
        case .keyStoreFailed(let s): return "Key store failed: \(s)"
        case .keyLoadFailed(let s): return "Key load failed: \(s)"
        case .encryptionFailed(let s): return "Encryption failed: \(s)"
        case .decryptionFailed(let s): return "Decryption failed: \(s)"
        case .authenticationTagInvalid: return "Authentication tag invalid"
        case .unsupportedVersion(let v): return "Unsupported format version: \(v)"
        }
    }
}

public enum Permission: String, Sendable, CaseIterable, CustomStringConvertible {
    case accessibility = "Accessibility"
    case clipboard = "Clipboard"

    public var description: String { rawValue }

    /// User-facing explanation of why this permission is needed.
    public var usageDescription: String {
        switch self {
        case .accessibility:
            return "MacKit needs Accessibility access to move and resize windows and to track which window is focused."
        case .clipboard:
            return "MacKit needs access to the clipboard to record your copy history. You can pause or disable recording at any time."
        }
    }

    /// Instructions to guide the user to grant the permission in System Settings.
    public var recoveryInstructions: String {
        switch self {
        case .accessibility:
            return "Open System Settings → Privacy & Security → Accessibility, then enable MacKit."
        case .clipboard:
            return "Open System Settings → Privacy & Security → Clipboard, then enable MacKit. (macOS 26+)"
        }
    }
}

public enum ClipboardRejectionReason: Error, Sendable, Equatable, CustomStringConvertible {
    case payloadTooLarge(kind: String, sizeBytes: Int, limitBytes: Int)
    case unsupportedFormat(String)
    case concealed
    case transient
    case excludedApplication(String)
    case paused
    case duplicate
    case moduleDisabled

    public var description: String {
        switch self {
        case .payloadTooLarge(let kind, let size, let limit):
            return "\(kind) payload (\(size) bytes) exceeds limit (\(limit) bytes)"
        case .unsupportedFormat(let f): return "Unsupported format: \(f)"
        case .concealed: return "Concealed/transient clipboard content"
        case .transient: return "Transient clipboard content"
        case .excludedApplication(let app): return "Source application is excluded: \(app)"
        case .paused: return "Recording is paused"
        case .duplicate: return "Duplicate of active entry"
        case .moduleDisabled: return "Clipboard module is disabled"
        }
    }
}

public enum WindowError: Error, Sendable, Equatable, CustomStringConvertible {
    case windowNotFound
    case notResizable
    case accessibilityUnavailable(String)
    case frameOutOfBounds
    case activationFailed(String)

    public var description: String {
        switch self {
        case .windowNotFound: return "Window not found"
        case .notResizable: return "Window is not resizable"
        case .accessibilityUnavailable(let s): return "Accessibility unavailable: \(s)"
        case .frameOutOfBounds: return "Frame is out of usable screen bounds"
        case .activationFailed(let s): return "Activation failed: \(s)"
        }
    }
}

