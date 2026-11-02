// Tests/ClipboardFeatureTests/ClipboardItemTests.swift
// Tests for in-memory model construction, preview generation, and equality.

import Testing
import Foundation
@testable import ClipboardFeature
@testable import SecureStorage

@Suite("ClipboardItem")
struct ClipboardItemTests {

    @Test("Short text preview is not truncated")
    func shortPreview() {
        let text = "Hello world"
        let preview = ClipboardItem.makePreview(from: text, maxLength: 50)
        #expect(preview == "Hello world")
    }

    @Test("Multiline text is collapsed into single line preview")
    func multilinePreview() {
        let text = "Line 1\nLine 2\nLine 3"
        let preview = ClipboardItem.makePreview(from: text, maxLength: 50)
        #expect(preview == "Line 1 Line 2 Line 3")
    }

    @Test("Long text is cleanly truncated with ellipsis without altering content")
    func longPreviewTruncation() {
        let text = String(repeating: "A", count: 200)
        let preview = ClipboardItem.makePreview(from: text, maxLength: 20)
        #expect(preview.count == 21) // 20 chars + ellipsis
        #expect(preview.hasSuffix("…"))
    }

    @Test("Items with same ID and pin state are equal")
    func itemEquality() {
        let id = UUID()
        let now = Date()
        let item1 = ClipboardItem(id: id, kind: .text, createdAt: now, lastUsedAt: now, isPinned: false, previewText: "Test", payloadSizeBytes: 4)
        let item2 = ClipboardItem(id: id, kind: .text, createdAt: now, lastUsedAt: now, isPinned: false, previewText: "Test", payloadSizeBytes: 4)
        #expect(item1 == item2)
    }
}

