// Tests/SecureStorageTests/ClipboardRepositoryTests.swift
// Integration tests for ClipboardRepository:
// SQLite metadata, encrypted payload files, retention, pinning, and deletion.

import Testing
import Foundation
import CryptoKit
@testable import SecureStorage
@testable import Diagnostics

@Suite("ClipboardRepository")
struct ClipboardRepositoryTests {

    private func makeRepository() async throws -> (ClipboardRepository, URL, URL) {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("mackit-repo-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let dbURL = tempDir.appendingPathComponent("test.sqlite")
        let payloadsURL = tempDir.appendingPathComponent("payloads")

        let key = SymmetricKey(size: .bits256)
        let encryptionService = EncryptionService(inMemoryKey: key)

        let db = DatabaseService(databaseURL: dbURL)
        try await db.open()

        let payloadStore = PayloadStore(baseDirectory: payloadsURL, encryptionService: encryptionService)
        try await payloadStore.prepare()

        let repo = ClipboardRepository(
            database: db,
            encryptionService: encryptionService,
            payloadStore: payloadStore
        )

        return (repo, dbURL, payloadsURL)
    }

    private func cleanup(dbURL: URL, payloadsURL: URL) {
        let parent = dbURL.deletingLastPathComponent()
        try? FileManager.default.removeItem(at: parent)
    }

    @Test("Save text item creates SQLite record and encrypted payload file")
    func saveTextItem() async throws {
        let (repo, dbURL, payloadsURL) = try await makeRepository()
        defer { cleanup(dbURL: dbURL, payloadsURL: payloadsURL) }

        let originalText = "MacKit native macOS toolkit"
        let payload = originalText.data(using: .utf8)!
        let metadata = EncryptedItemMetadata(previewText: originalText, sourceAppName: "Terminal")

        let record = try await repo.saveItem(
            kind: .text,
            payload: payload,
            metadata: metadata
        )

        #expect(record.kind == .text)
        #expect(record.payloadSizeBytes == payload.count)
        #expect(!record.isPinned)

        // Verify SQLite row exists
        let items = try await repo.fetchItems()
        #expect(items.count == 1)
        #expect(items[0].id == record.id)

        // Verify decrypted payload matches original text
        let fetchedPayload = try await repo.fetchPayload(for: items[0])
        let fetchedString = String(data: fetchedPayload, encoding: .utf8)
        #expect(fetchedString == originalText)

        // Verify decrypted metadata
        let fetchedMetadata = try await repo.fetchMetadata(for: items[0])
        #expect(fetchedMetadata?.sourceAppName == "Terminal")
        #expect(fetchedMetadata?.previewText == originalText)
    }

    @Test("Save and retrieve exact Unicode content with whitespace and emojis")
    func unicodePreservation() async throws {
        let (repo, dbURL, payloadsURL) = try await makeRepository()
        defer { cleanup(dbURL: dbURL, payloadsURL: payloadsURL) }

        let text = """
        🚀 Special Unicode Test:
        - Arabic: مرحباً بالعالم
        - Japanese: こんにちは世界 🗾
        - Russian: Привет, мир!
        - Whitespace: \t\t   Tabs and \n Newlines \r\n preserved exactly.
        """
        let payload = text.data(using: .utf8)!

        let record = try await repo.saveItem(kind: .text, payload: payload)
        let retrieved = try await repo.fetchPayload(for: record)
        let result = String(data: retrieved, encoding: .utf8)

        #expect(result == text)
    }

    @Test("Binary image payload round-trips without corruption")
    func binaryImageRoundTrip() async throws {
        let (repo, dbURL, payloadsURL) = try await makeRepository()
        defer { cleanup(dbURL: dbURL, payloadsURL: payloadsURL) }

        // Simulated PNG bytes
        var pngBytes = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        pngBytes.append(contentsOf: (0..<5000).map { UInt8($0 % 256) })

        let record = try await repo.saveItem(kind: .image, payload: pngBytes)
        let retrieved = try await repo.fetchPayload(for: record)

        #expect(retrieved == pngBytes)
    }

    @Test("Toggling pin status persists in SQLite")
    func pinToggle() async throws {
        let (repo, dbURL, payloadsURL) = try await makeRepository()
        defer { cleanup(dbURL: dbURL, payloadsURL: payloadsURL) }

        let record = try await repo.saveItem(kind: .text, payload: "Pinned Item".data(using: .utf8)!)
        #expect(!record.isPinned)

        try await repo.setPinned(id: record.id, isPinned: true)
        let items = try await repo.fetchItems()
        #expect(items[0].isPinned == true)

        try await repo.setPinned(id: record.id, isPinned: false)
        let unpinnedItems = try await repo.fetchItems()
        #expect(unpinnedItems[0].isPinned == false)
    }

    @Test("Deleting an item removes both SQLite record and encrypted payload file")
    func deleteItem() async throws {
        let (repo, dbURL, payloadsURL) = try await makeRepository()
        defer { cleanup(dbURL: dbURL, payloadsURL: payloadsURL) }

        let record = try await repo.saveItem(kind: .text, payload: "To be deleted".data(using: .utf8)!)
        let payloadFile = payloadsURL.appendingPathComponent(record.encryptedPayloadRef)
        #expect(FileManager.default.fileExists(atPath: payloadFile.path))

        try await repo.deleteItem(id: record.id)

        let items = try await repo.fetchItems()
        #expect(items.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: payloadFile.path))
    }

    @Test("Clearing unpinned items preserves pinned items and deletes files")
    func clearUnpinned() async throws {
        let (repo, dbURL, payloadsURL) = try await makeRepository()
        defer { cleanup(dbURL: dbURL, payloadsURL: payloadsURL) }

        let unpinned1 = try await repo.saveItem(kind: .text, payload: "Unpinned 1".data(using: .utf8)!)
        let pinned = try await repo.saveItem(kind: .text, payload: "Pinned".data(using: .utf8)!, isPinned: true)
        let unpinned2 = try await repo.saveItem(kind: .text, payload: "Unpinned 2".data(using: .utf8)!)

        let unpinnedFile1 = payloadsURL.appendingPathComponent(unpinned1.encryptedPayloadRef)
        let pinnedFile = payloadsURL.appendingPathComponent(pinned.encryptedPayloadRef)
        let unpinnedFile2 = payloadsURL.appendingPathComponent(unpinned2.encryptedPayloadRef)

        try await repo.clearUnpinned()

        let remaining = try await repo.fetchItems()
        #expect(remaining.count == 1)
        #expect(remaining[0].id == pinned.id)

        #expect(!FileManager.default.fileExists(atPath: unpinnedFile1.path))
        #expect(FileManager.default.fileExists(atPath: pinnedFile.path))
        #expect(!FileManager.default.fileExists(atPath: unpinnedFile2.path))
    }

    @Test("Retention enforcement by maxEntries evicts oldest unpinned and preserves pinned")
    func retentionByCount() async throws {
        let (repo, dbURL, payloadsURL) = try await makeRepository()
        defer { cleanup(dbURL: dbURL, payloadsURL: payloadsURL) }

        // Create 1 pinned item and 5 unpinned items
        let pinned = try await repo.saveItem(kind: .text, payload: "Pinned".data(using: .utf8)!, isPinned: true)
        var unpinnedRecords: [ClipboardItemRecord] = []
        for i in 1...5 {
            let r = try await repo.saveItem(kind: .text, payload: "Unpinned \(i)".data(using: .utf8)!)
            unpinnedRecords.append(r)
        }

        // Limit to max 2 unpinned entries
        try await repo.enforceRetention(maxEntries: 2, retentionDays: 0)

        let remaining = try await repo.fetchItems()
        // Pinned is always preserved + 2 newest unpinned = 3 items total
        #expect(remaining.count == 3)
        #expect(remaining.contains(where: { $0.id == pinned.id }))
        #expect(remaining.contains(where: { $0.id == unpinnedRecords[4].id }))
        #expect(remaining.contains(where: { $0.id == unpinnedRecords[3].id }))
    }

    @Test("Counts returns correct total and pinned counts")
    func itemCounts() async throws {
        let (repo, dbURL, payloadsURL) = try await makeRepository()
        defer { cleanup(dbURL: dbURL, payloadsURL: payloadsURL) }

        _ = try await repo.saveItem(kind: .text, payload: "Item 1".data(using: .utf8)!, isPinned: true)
        _ = try await repo.saveItem(kind: .text, payload: "Item 2".data(using: .utf8)!, isPinned: false)
        _ = try await repo.saveItem(kind: .text, payload: "Item 3".data(using: .utf8)!, isPinned: true)

        let counts = try await repo.counts()
        #expect(counts.total == 3)
        #expect(counts.pinned == 2)
    }
}

