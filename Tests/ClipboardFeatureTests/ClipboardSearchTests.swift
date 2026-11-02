// Tests/ClipboardFeatureTests/ClipboardSearchTests.swift
// Tests for in-memory search ranking, case-insensitivity, and diacritics.

import Testing
import Foundation
@testable import ClipboardFeature
@testable import SecureStorage

@Suite("ClipboardSearch")
struct ClipboardSearchTests {

    let search = ClipboardSearch()

    private func makeItem(
        preview: String,
        fullText: String? = nil,
        isPinned: Bool = false,
        createdAt: Date = Date()
    ) -> ClipboardItem {
        ClipboardItem(
            id: UUID(),
            kind: .text,
            createdAt: createdAt,
            isPinned: isPinned,
            previewText: preview,
            fullText: fullText ?? preview,
            payloadSizeBytes: 50
        )
    }

    @Test("Empty search query returns all items in original order")
    func emptyQueryReturnsAll() {
        let items = [
            makeItem(preview: "First"),
            makeItem(preview: "Second"),
            makeItem(preview: "Third")
        ]
        let results = search.filter(items: items, query: "")
        #expect(results == items)
    }

    @Test("Exact match ranks higher than prefix or substring match")
    func exactMatchRanking() {
        let substringItem = makeItem(preview: "Prefix macbook suffix")
        let prefixItem = makeItem(preview: "macbook pro 16-inch")
        let exactItem = makeItem(preview: "macbook")

        let items = [substringItem, prefixItem, exactItem]
        let results = search.filter(items: items, query: "macbook")

        #expect(results.count == 3)
        #expect(results[0].previewText == "macbook")
        #expect(results[1].previewText == "macbook pro 16-inch")
        #expect(results[2].previewText == "Prefix macbook suffix")
    }

    @Test("Search is case-insensitive")
    func caseInsensitivity() {
        let item = makeItem(preview: "Swift Native macOS Application")
        let results = search.filter(items: [item], query: "swift native")
        #expect(results.count == 1)
    }

    @Test("Search is diacritic-insensitive")
    func diacriticInsensitivity() {
        let item = makeItem(preview: "Café au lait à Paris")
        let results = search.filter(items: [item], query: "cafe")
        #expect(results.count == 1)
    }

    @Test("Search matches within full text when preview is truncated")
    func searchFullText() {
        let item = makeItem(
            preview: "Short preview…",
            fullText: "Hidden inside long content is a secret token XYZ-999"
        )
        let results = search.filter(items: [item], query: "XYZ-999")
        #expect(results.count == 1)
    }

    @Test("Non-matching items are excluded")
    func nonMatchingExcluded() {
        let items = [
            makeItem(preview: "Alpha"),
            makeItem(preview: "Beta"),
            makeItem(preview: "Gamma")
        ]
        let results = search.filter(items: items, query: "Delta")
        #expect(results.isEmpty)
    }

    @Test("Pinned items receive relevance boost")
    func pinnedItemBoost() {
        let unpinnedPrefix = makeItem(preview: "macOS Ventura", isPinned: false)
        let pinnedPrefix = makeItem(preview: "macOS Sonoma", isPinned: true)

        let items = [unpinnedPrefix, pinnedPrefix]
        let results = search.filter(items: items, query: "macOS")

        #expect(results.first?.previewText == "macOS Sonoma")
    }
}

