// Tests/SecureStorageTests/DatabaseServiceTests.swift
// Integration tests for the SQLite DatabaseService.
// Uses a temporary file-based database to exercise real SQLite I/O.

import Testing
import Foundation
@testable import SecureStorage
@testable import Diagnostics

@Suite("DatabaseService")
struct DatabaseServiceTests {

    /// Create a DatabaseService backed by a unique temp file.
    private func makeDatabase() throws -> (DatabaseService, URL) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("mackit-test-\(UUID().uuidString).sqlite")
        let db = DatabaseService(databaseURL: url)
        return (db, url)
    }

    private func cleanup(url: URL) {
        try? FileManager.default.removeItem(at: url)
        // Also remove WAL/SHM files
        try? FileManager.default.removeItem(at: url.appendingPathExtension("wal"))
        try? FileManager.default.removeItem(at: url.appendingPathExtension("shm"))
    }

    @Test("Database opens without error")
    func openDatabase() async throws {
        let (db, url) = try makeDatabase()
        defer { Task { await db.close() }; cleanup(url: url) }
        try await db.open()
    }

    @Test("Schema version is 1 after opening")
    func schemaVersionAfterOpen() async throws {
        let (db, url) = try makeDatabase()
        defer { Task { await db.close() }; cleanup(url: url) }
        try await db.open()
        let rows = try await db.query("SELECT version FROM schema_version LIMIT 1", parameters: [])
        #expect(rows.count == 1)
        guard case .integer(let v) = rows[0]["version"] else {
            Issue.record("version column is not integer")
            return
        }
        #expect(v == 1)
    }

    @Test("clipboard_items table exists and has correct columns")
    func clipboardItemsTableExists() async throws {
        let (db, url) = try makeDatabase()
        defer { Task { await db.close() }; cleanup(url: url) }
        try await db.open()
        let rows = try await db.query("PRAGMA table_info(clipboard_items)", parameters: [])
        let columnNames = rows.compactMap { row -> String? in
            guard case .text(let name) = row["name"] else { return nil }
            return name
        }
        let required = ["id", "kind", "created_at", "last_used_at", "pinned",
                        "encrypted_payload_ref", "encrypted_metadata",
                        "payload_size_bytes", "payload_format_version", "encryption_version"]
        for col in required {
            #expect(columnNames.contains(col), "Missing column: \(col)")
        }
    }

    @Test("Insert and query a clipboard_items row")
    func insertAndQuery() async throws {
        let (db, url) = try makeDatabase()
        defer { Task { await db.close() }; cleanup(url: url) }
        try await db.open()

        let id = UUID().uuidString
        let now = Int64(Date().timeIntervalSince1970)
        try await db.execute("""
            INSERT INTO clipboard_items
              (id, kind, created_at, last_used_at, pinned, payload_size_bytes, payload_format_version, encryption_version)
            VALUES (?, ?, ?, ?, 0, 100, 1, 1)
        """, parameters: [.text(id), .text("text"), .integer(now), .integer(now)])

        let rows = try await db.query("SELECT * FROM clipboard_items WHERE id = ?", parameters: [.text(id)])
        #expect(rows.count == 1)
        guard case .text(let kind) = rows[0]["kind"] else {
            Issue.record("kind is not text")
            return
        }
        #expect(kind == "text")
    }

    @Test("Transaction rolls back on failure")
    func transactionRollback() async throws {
        let (db, url) = try makeDatabase()
        defer { Task { await db.close() }; cleanup(url: url) }
        try await db.open()

        let id = UUID().uuidString
        let now = Int64(Date().timeIntervalSince1970)

        // Transaction should fail due to duplicate PRIMARY KEY
        do {
            try await db.transaction { txDb in
                try txDb.execute("""
                    INSERT INTO clipboard_items
                      (id, kind, created_at, last_used_at, pinned, payload_size_bytes, payload_format_version, encryption_version)
                    VALUES (?, 'text', ?, ?, 0, 50, 1, 1)
                """, parameters: [.text(id), .integer(now), .integer(now)])

                // Second insert with same primary key — should fail
                try txDb.execute("""
                    INSERT INTO clipboard_items
                      (id, kind, created_at, last_used_at, pinned, payload_size_bytes, payload_format_version, encryption_version)
                    VALUES (?, 'url', ?, ?, 0, 50, 1, 1)
                """, parameters: [.text(id), .integer(now), .integer(now)])
            }
            Issue.record("Transaction should have thrown on duplicate key")
        } catch {
            // Expected — verify no row was inserted
            let rows = try await db.query("SELECT * FROM clipboard_items WHERE id = ?", parameters: [.text(id)])
            #expect(rows.isEmpty, "Row should not exist after rollback")
        }
    }

    @Test("Reopening the database preserves existing data")
    func persistenceAcrossReopen() async throws {
        let (db, url) = try makeDatabase()
        defer { cleanup(url: url) }

        try await db.open()
        let id = UUID().uuidString
        let now = Int64(Date().timeIntervalSince1970)
        try await db.execute("""
            INSERT INTO clipboard_items
              (id, kind, created_at, last_used_at, pinned, payload_size_bytes, payload_format_version, encryption_version)
            VALUES (?, 'text', ?, ?, 0, 10, 1, 1)
        """, parameters: [.text(id), .integer(now), .integer(now)])
        await db.close()

        // Reopen
        let db2 = DatabaseService(databaseURL: url)
        try await db2.open()
        defer { Task { await db2.close() } }
        let rows = try await db2.query("SELECT id FROM clipboard_items WHERE id = ?", parameters: [.text(id)])
        #expect(rows.count == 1)
    }
}

