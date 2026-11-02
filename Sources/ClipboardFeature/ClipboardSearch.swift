// ClipboardFeature/ClipboardSearch.swift
// In-memory search ranking for decrypted clipboard text and URL entries.
// Plaintext search queries and indexes are strictly kept in memory.

import Foundation

/// Fast in-memory search engine with relevance ranking.
public struct ClipboardSearch: Sendable {

    public init() {}

    /// Search items by query string, ranking exact and prefix matches highest.
    /// Returns sorted matching items. If query is empty, returns all items in original order.
    public func filter(items: [ClipboardItem], query: String) -> [ClipboardItem] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return items }

        let normalizedQuery = trimmedQuery.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)

        var scored: [(item: ClipboardItem, score: Int)] = []

        for item in items {
            let searchableText: String
            if let full = item.fullText {
                searchableText = full
            } else {
                searchableText = item.previewText
            }

            let normalizedTarget = searchableText.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)

            if let score = calculateScore(target: normalizedTarget, query: normalizedQuery) {
                // Boost pinned items slightly to preserve user priority
                let finalScore = item.isPinned ? score + 10 : score
                scored.append((item, finalScore))
            }
        }

        // Sort descending by score, tie-breaking with createdAt
        scored.sort { a, b in
            if a.score != b.score {
                return a.score > b.score
            }
            return a.item.createdAt > b.item.createdAt
        }

        return scored.map(\.item)
    }

    private func calculateScore(target: String, query: String) -> Int? {
        // 1. Exact match
        if target == query {
            return 100
        }

        // 2. Prefix match
        if target.hasPrefix(query) {
            return 80
        }

        // 3. Word-boundary prefix match (e.g. searching "mac" in "Apple MacKit")
        let words = target.split(whereSeparator: { $0.isWhitespace || $0.isPunctuation })
        for word in words {
            if word.hasPrefix(query) {
                return 60
            }
        }

        // 4. Substring match
        if target.contains(query) {
            return 40
        }

        return nil
    }
}
