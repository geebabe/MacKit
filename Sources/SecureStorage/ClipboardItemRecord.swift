// SecureStorage/ClipboardItemRecord.swift
// Representation of a stored clipboard record metadata.
// Plaintext sensitive content is NEVER stored here.

import Foundation

/// Supported kinds of clipboard content.
public enum ClipboardItemKind: String, Sendable, Codable, CaseIterable {
    case text
    case url
    case image
    case screenshot

    public var displayLabel: String {
        switch self {
        case .text: return "Text"
        case .url: return "Link"
        case .image: return "Image"
        case .screenshot: return "Screenshot"
        }
    }

    public var systemImageName: String {
        switch self {
        case .text: return "doc.text"
        case .url: return "link"
        case .image: return "photo"
        case .screenshot: return "camera.viewfinder"
        }
    }
}

/// Encrypted metadata package stored in `encrypted_metadata` column.
public struct EncryptedItemMetadata: Codable, Sendable {
    public let previewText: String?
    public let sourceBundleID: String?
    public let sourceAppName: String?
    public let imageWidth: Int?
    public let imageHeight: Int?

    public init(
        previewText: String? = nil,
        sourceBundleID: String? = nil,
        sourceAppName: String? = nil,
        imageWidth: Int? = nil,
        imageHeight: Int? = nil
    ) {
        self.previewText = previewText
        self.sourceBundleID = sourceBundleID
        self.sourceAppName = sourceAppName
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
    }
}

/// Record representing a row in `clipboard_items` database.
public struct ClipboardItemRecord: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let kind: ClipboardItemKind
    public let createdAt: Date
    public var lastUsedAt: Date
    public var isPinned: Bool
    public let encryptedPayloadRef: String
    public let payloadSizeBytes: Int
    public let payloadFormatVersion: Int
    public let encryptionVersion: Int

    public init(
        id: UUID = UUID(),
        kind: ClipboardItemKind,
        createdAt: Date = Date(),
        lastUsedAt: Date = Date(),
        isPinned: Bool = false,
        encryptedPayloadRef: String,
        payloadSizeBytes: Int,
        payloadFormatVersion: Int = 1,
        encryptionVersion: Int = 1
    ) {
        self.id = id
        self.kind = kind
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.isPinned = isPinned
        self.encryptedPayloadRef = encryptedPayloadRef
        self.payloadSizeBytes = payloadSizeBytes
        self.payloadFormatVersion = payloadFormatVersion
        self.encryptionVersion = encryptionVersion
    }
}

