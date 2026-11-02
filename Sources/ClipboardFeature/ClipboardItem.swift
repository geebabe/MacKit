// ClipboardFeature/ClipboardItem.swift
// In-memory model of an active clipboard history item.
// Used for display, keyboard navigation, and in-memory search.

import Foundation
import AppKit
import SecureStorage

/// In-memory representation of an item for the UI.
public struct ClipboardItem: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let kind: ClipboardItemKind
    public let createdAt: Date
    public var lastUsedAt: Date
    public var isPinned: Bool
    public let previewText: String
    public let fullText: String?
    public let imageData: Data?
    public let sourceAppName: String?
    public let payloadSizeBytes: Int

    public init(
        id: UUID = UUID(),
        kind: ClipboardItemKind,
        createdAt: Date = Date(),
        lastUsedAt: Date = Date(),
        isPinned: Bool = false,
        previewText: String,
        fullText: String? = nil,
        imageData: Data? = nil,
        sourceAppName: String? = nil,
        payloadSizeBytes: Int
    ) {
        self.id = id
        self.kind = kind
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.isPinned = isPinned
        self.previewText = previewText
        self.fullText = fullText
        self.imageData = imageData
        self.sourceAppName = sourceAppName
        self.payloadSizeBytes = payloadSizeBytes
    }

    /// Helper to produce a clean preview string without mutating full content.
    public static func makePreview(from text: String, maxLength: Int = 120) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let singleLine = trimmed.replacingOccurrences(of: "\n", with: " ")
        if singleLine.count <= maxLength {
            return singleLine
        }
        let index = singleLine.index(singleLine.startIndex, offsetBy: maxLength)
        return String(singleLine[..<index]) + "…"
    }

    public static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.isPinned == rhs.isPinned &&
        lhs.lastUsedAt == rhs.lastUsedAt
    }
}
