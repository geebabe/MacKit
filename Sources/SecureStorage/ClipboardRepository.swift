// SecureStorage/ClipboardRepository.swift
// Repository coordinating SQLite records and encrypted payload files for clipboard history.
// Ensures transactional consistency and safe retention cleanup.

import Foundation
import Diagnostics

/// High-level repository for persisting, retrieving, and pruning clipboard history.
public actor ClipboardRepository {

    private let database: DatabaseService
    private let encryptionService: EncryptionService
    private let payloadStore: PayloadStore
    private let logger = Logger(category: .storage)

    public init(
        database: DatabaseService,
        encryptionService: EncryptionService,
        payloadStore: PayloadStore
    ) {
        self.database = database
        self.encryptionService = encryptionService
        self.payloadStore = payloadStore
    }

    /// Store a new clipboard item with its raw payload and optional metadata.
    public func saveItem(
        id: UUID = UUID(),
        kind: ClipboardItemKind,
        payload: Data,
        metadata: EncryptedItemMetadata? = nil,
        isPinned: Bool = false
    ) async throws -> ClipboardItemRecord {
        // 1. Write encrypted payload file
        let filename = try await payloadStore.writePayload(payload, associatedID: id)

        // 2. Encrypt metadata if provided
        var encryptedMetadataBlob = Data()
        if let metadata {
            let metadataData = try JSONEncoder().encode(metadata)
            let assoc = id.uuidString.data(using: .utf8) ?? Data()
            encryptedMetadataBlob = try await encryptionService.encrypt(metadataData, associatedData: assoc)
        }

        let now = Int64(Date().timeIntervalSince1970)
        let record = ClipboardItemRecord(
            id: id,
            kind: kind,
            createdAt: Date(timeIntervalSince1970: TimeInterval(now)),
            lastUsedAt: Date(timeIntervalSince1970: TimeInterval(now)),
            isPinned: isPinned,
            encryptedPayloadRef: filename,
            payloadSizeBytes: payload.count
        )

        // 3. Insert SQLite row
        try await database.execute("""
            INSERT INTO clipboard_items (
                id, kind, created_at, last_used_at, pinned,
                encrypted_payload_ref, encrypted_metadata,
                payload_size_bytes, payload_format_version, encryption_version
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, parameters: [
            .text(id.uuidString),
            .text(kind.rawValue),
            .integer(now),
            .integer(now),
            .integer(isPinned ? 1 : 0),
            .text(filename),
            encryptedMetadataBlob.isEmpty ? .null : .blob(encryptedMetadataBlob),
            .integer(Int64(payload.count)),
            .integer(1),
            .integer(1)
        ])

        logger.info("Saved clipboard item \(id.uuidString) (\(kind.rawValue), \(payload.count) bytes)")
        return record
    }

    /// Fetch stored records sorted by `created_at DESC`.
    public func fetchItems(limit: Int = 500, offset: Int = 0) async throws -> [ClipboardItemRecord] {
        let rows = try await database.query("""
            SELECT id, kind, created_at, last_used_at, pinned,
                   encrypted_payload_ref, payload_size_bytes,
                   payload_format_version, encryption_version
            FROM clipboard_items
            ORDER BY pinned DESC, created_at DESC, rowid DESC
            LIMIT ? OFFSET ?
        """, parameters: [.integer(Int64(limit)), .integer(Int64(offset))])

        return rows.compactMap { row -> ClipboardItemRecord? in
            guard case .text(let idStr) = row["id"],
                  let id = UUID(uuidString: idStr),
                  case .text(let kindStr) = row["kind"],
                  let kind = ClipboardItemKind(rawValue: kindStr),
                  case .integer(let createdAtInt) = row["created_at"],
                  case .integer(let lastUsedAtInt) = row["last_used_at"],
                  case .integer(let pinnedInt) = row["pinned"],
                  case .text(let payloadRef) = row["encrypted_payload_ref"],
                  case .integer(let sizeBytesInt) = row["payload_size_bytes"]
            else { return nil }

            return ClipboardItemRecord(
                id: id,
                kind: kind,
                createdAt: Date(timeIntervalSince1970: TimeInterval(createdAtInt)),
                lastUsedAt: Date(timeIntervalSince1970: TimeInterval(lastUsedAtInt)),
                isPinned: pinnedInt == 1,
                encryptedPayloadRef: payloadRef,
                payloadSizeBytes: Int(sizeBytesInt)
            )
        }
    }

    /// Read and decrypt the payload data for an item.
    public func fetchPayload(for record: ClipboardItemRecord) async throws -> Data {
        return try await payloadStore.readPayload(
            filename: record.encryptedPayloadRef,
            associatedID: record.id
        )
    }

    /// Read and decrypt metadata for an item.
    public func fetchMetadata(for record: ClipboardItemRecord) async throws -> EncryptedItemMetadata? {
        let rows = try await database.query(
            "SELECT encrypted_metadata FROM clipboard_items WHERE id = ? LIMIT 1",
            parameters: [.text(record.id.uuidString)]
        )
        guard let row = rows.first, case .blob(let encryptedData) = row["encrypted_metadata"], !encryptedData.isEmpty else {
            return nil
        }

        let assoc = record.id.uuidString.data(using: .utf8) ?? Data()
        let decrypted = try await encryptionService.decrypt(encryptedData, associatedData: assoc)
        return try? JSONDecoder().decode(EncryptedItemMetadata.self, from: decrypted)
    }

    /// Toggle or set pin status.
    public func setPinned(id: UUID, isPinned: Bool) async throws {
        try await database.execute(
            "UPDATE clipboard_items SET pinned = ? WHERE id = ?",
            parameters: [.integer(isPinned ? 1 : 0), .text(id.uuidString)]
        )
    }

    /// Update `last_used_at` timestamp.
    public func markUsed(id: UUID) async throws {
        let now = Int64(Date().timeIntervalSince1970)
        try await database.execute(
            "UPDATE clipboard_items SET last_used_at = ? WHERE id = ?",
            parameters: [.integer(now), .text(id.uuidString)]
        )
    }

    /// Delete a single record and its backing payload file.
    public func deleteItem(id: UUID) async throws {
        let rows = try await database.query(
            "SELECT encrypted_payload_ref FROM clipboard_items WHERE id = ? LIMIT 1",
            parameters: [.text(id.uuidString)]
        )
        if let row = rows.first, case .text(let ref) = row["encrypted_payload_ref"] {
            await payloadStore.deletePayload(filename: ref)
        }
        try await database.execute(
            "DELETE FROM clipboard_items WHERE id = ?",
            parameters: [.text(id.uuidString)]
        )
    }

    /// Clear all unpinned items. Pinned items are strictly preserved.
    public func clearUnpinned() async throws {
        let rows = try await database.query(
            "SELECT encrypted_payload_ref FROM clipboard_items WHERE pinned = 0",
            parameters: []
        )
        for row in rows {
            if case .text(let ref) = row["encrypted_payload_ref"] {
                await payloadStore.deletePayload(filename: ref)
            }
        }
        try await database.execute(
            "DELETE FROM clipboard_items WHERE pinned = 0",
            parameters: []
        )
    }

    /// Enforce retention policies:
    /// 1. Evict unpinned items exceeding `maxEntries`.
    /// 2. Evict unpinned items older than `retentionDays`.
    /// Pinned items are exempt.
    public func enforceRetention(maxEntries: Int, retentionDays: Int) async throws {
        // 1. Expiration by age
        if retentionDays > 0 {
            let cutoff = Int64(Date().addingTimeInterval(-Double(retentionDays * 86400)).timeIntervalSince1970)
            let expiredRows = try await database.query("""
                SELECT id, encrypted_payload_ref FROM clipboard_items
                WHERE pinned = 0 AND created_at < ?
            """, parameters: [.integer(cutoff)])

            for row in expiredRows {
                if case .text(let ref) = row["encrypted_payload_ref"] {
                    await payloadStore.deletePayload(filename: ref)
                }
            }
            try await database.execute("""
                DELETE FROM clipboard_items
                WHERE pinned = 0 AND created_at < ?
            """, parameters: [.integer(cutoff)])
        }

        // 2. Count-based eviction for unpinned items
        if maxEntries > 0 {
            let unpinnedRows = try await database.query("""
                SELECT id, encrypted_payload_ref FROM clipboard_items
                WHERE pinned = 0
                ORDER BY created_at DESC, rowid DESC
                LIMIT -1 OFFSET ?
            """, parameters: [.integer(Int64(maxEntries))])

            for row in unpinnedRows {
                if case .text(let idStr) = row["id"],
                   case .text(let ref) = row["encrypted_payload_ref"] {
                    await payloadStore.deletePayload(filename: ref)
                    try await database.execute(
                        "DELETE FROM clipboard_items WHERE id = ?",
                        parameters: [.text(idStr)]
                    )
                }
            }
        }
    }

    /// Return total item count and pinned count.
    public func counts() async throws -> (total: Int, pinned: Int) {
        let totalRows = try await database.query("SELECT COUNT(*) AS c FROM clipboard_items", parameters: [])
        let pinnedRows = try await database.query("SELECT COUNT(*) AS c FROM clipboard_items WHERE pinned = 1", parameters: [])

        let total: Int
        if let row = totalRows.first, case .integer(let c) = row["c"] {
            total = Int(c)
        } else { total = 0 }

        let pinned: Int
        if let row = pinnedRows.first, case .integer(let c) = row["c"] {
            pinned = Int(c)
        } else { pinned = 0 }

        return (total, pinned)
    }
}
