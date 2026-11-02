// SecureStorage/DatabaseService.swift
// SQLite wrapper using libsqlite3 (system-provided, no third-party deps).
// Provides a safe actor-isolated interface for schema creation and CRUD.

import Foundation
import SQLite3
import Diagnostics
import Darwin

/// A type-safe SQLite column binding.
public enum SQLiteValue: Sendable {
    case integer(Int64)
    case real(Double)
    case text(String)
    case blob(Data)
    case null
}

/// Lightweight result row from a SQLite query.
public typealias SQLiteRow = [String: SQLiteValue]

/// Actor-isolated SQLite database service.
/// All access to the database connection is serialized through this actor.
public actor DatabaseService {

    private var db: OpaquePointer?
    private let logger = Logger(category: .storage)
    private let databaseURL: URL

    // MARK: - Initialisation

    public init(databaseURL: URL) {
        self.databaseURL = databaseURL
    }

    // MARK: - Lifecycle

    /// Open (or create) the database and run migrations.
    public func open() throws {
        let path = databaseURL.path(percentEncoded: false)
        var dbPointer: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        let result = sqlite3_open_v2(path, &dbPointer, flags, nil)
        guard result == SQLITE_OK, let pointer = dbPointer else {
            let msg = dbPointer.map { String(cString: sqlite3_errmsg($0)) } ?? "Unknown error"
            sqlite3_close(dbPointer)
            throw AppError.storageFailed(.openFailed(msg))
        }
        db = pointer

        // Enable WAL mode for better concurrency and crash safety.
        try execute("PRAGMA journal_mode = WAL")
        // Enforce referential integrity.
        try execute("PRAGMA foreign_keys = ON")

        try runMigrations()
        logger.info("Database opened at \(databaseURL.lastPathComponent)")
    }

    /// Close the database connection.
    public func close() {
        if let db {
            sqlite3_close(db)
            self.db = nil
            logger.info("Database closed")
        }
    }

    // MARK: - DDL migrations

    private func runMigrations() throws {
        // Version tracking table
        try execute("""
            CREATE TABLE IF NOT EXISTS schema_version (
                version INTEGER NOT NULL
            )
        """)

        let current = try schemaVersion()
        logger.info("Schema version: \(current)")

        if current < 1 {
            try migrate_v1()
            try setSchemaVersion(1)
        }
        // Future migrations append here as: if current < N { try migrate_vN() }
    }

    private func schemaVersion() throws -> Int {
        let rows = try query("SELECT version FROM schema_version LIMIT 1", parameters: [])
        guard let row = rows.first, case .integer(let v) = row["version"] else { return 0 }
        return Int(v)
    }

    private func setSchemaVersion(_ version: Int) throws {
        let current = try schemaVersion()
        if current == 0 {
            try execute("INSERT INTO schema_version (version) VALUES (?)", parameters: [.integer(Int64(version))])
        } else {
            try execute("UPDATE schema_version SET version = ?", parameters: [.integer(Int64(version))])
        }
    }

    /// Schema v1: clipboard items metadata table.
    private func migrate_v1() throws {
        try execute("""
            CREATE TABLE IF NOT EXISTS clipboard_items (
                id TEXT PRIMARY KEY NOT NULL,
                kind TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                last_used_at INTEGER NOT NULL,
                pinned INTEGER NOT NULL DEFAULT 0,
                encrypted_payload_ref TEXT,
                encrypted_metadata BLOB,
                payload_size_bytes INTEGER NOT NULL DEFAULT 0,
                payload_format_version INTEGER NOT NULL DEFAULT 1,
                encryption_version INTEGER NOT NULL DEFAULT 1
            )
        """)
        try execute("""
            CREATE INDEX IF NOT EXISTS idx_clipboard_items_created_at
            ON clipboard_items(created_at DESC)
        """)
        try execute("""
            CREATE INDEX IF NOT EXISTS idx_clipboard_items_pinned
            ON clipboard_items(pinned)
        """)
        logger.info("Migration v1 applied: clipboard_items table created")
    }

    // MARK: - Query execution

    /// Execute a statement that produces no result rows.
    public func execute(_ sql: String, parameters: [SQLiteValue] = []) throws {
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        try bind(parameters, to: stmt)
        let result = sqlite3_step(stmt)
        guard result == SQLITE_DONE || result == SQLITE_ROW else {
            throw AppError.storageFailed(.writeFailed(lastError()))
        }
    }

    /// Execute a query and return all result rows.
    public func query(_ sql: String, parameters: [SQLiteValue] = []) throws -> [SQLiteRow] {
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        try bind(parameters, to: stmt)

        var rows: [SQLiteRow] = []
        while true {
            let result = sqlite3_step(stmt)
            if result == SQLITE_ROW {
                rows.append(readRow(from: stmt))
            } else if result == SQLITE_DONE {
                break
            } else {
                throw AppError.storageFailed(.readFailed(lastError()))
            }
        }
        return rows
    }

    /// Execute a block within a SQLite transaction. Rolls back on failure.
    public func transaction(_ block: @Sendable (_ db: isolated DatabaseService) throws -> Void) throws {
        try execute("BEGIN")
        do {
            try block(self)
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    // MARK: - Private helpers

    private func prepare(_ sql: String) throws -> OpaquePointer {
        guard let db else {
            throw AppError.storageFailed(.openFailed("Database is not open"))
        }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let s = stmt else {
            throw AppError.storageFailed(.writeFailed("Prepare failed: \(lastError())"))
        }
        return s
    }

    private func bind(_ parameters: [SQLiteValue], to stmt: OpaquePointer) throws {
        for (index, param) in parameters.enumerated() {
            let col = Int32(index + 1)
            let result: Int32
            switch param {
            case .integer(let v): result = sqlite3_bind_int64(stmt, col, v)
            case .real(let v): result = sqlite3_bind_double(stmt, col, v)
            case .text(let v): result = sqlite3_bind_text(stmt, col, v, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            case .blob(let v): result = v.withUnsafeBytes { sqlite3_bind_blob(stmt, col, $0.baseAddress, Int32($0.count), unsafeBitCast(-1, to: sqlite3_destructor_type.self)) }
            case .null: result = sqlite3_bind_null(stmt, col)
            }
            guard result == SQLITE_OK else {
                throw AppError.storageFailed(.writeFailed("Bind failed at index \(index): \(lastError())"))
            }
        }
    }

    private func readRow(from stmt: OpaquePointer) -> SQLiteRow {
        var row: SQLiteRow = [:]
        let count = sqlite3_column_count(stmt)
        for i in 0..<count {
            let name = String(cString: sqlite3_column_name(stmt, i))
            let type = sqlite3_column_type(stmt, i)
            let value: SQLiteValue
            switch type {
            case SQLITE_INTEGER: value = .integer(sqlite3_column_int64(stmt, i))
            case SQLITE_FLOAT: value = .real(sqlite3_column_double(stmt, i))
            case SQLITE_TEXT: value = .text(String(cString: sqlite3_column_text(stmt, i)))
            case SQLITE_BLOB:
                if let ptr = sqlite3_column_blob(stmt, i) {
                    let length = sqlite3_column_bytes(stmt, i)
                    value = .blob(Data(bytes: ptr, count: Int(length)))
                } else {
                    value = .null
                }
            default: value = .null
            }
            row[name] = value
        }
        return row
    }

    private func lastError() -> String {
        guard let db else { return "No database connection" }
        return String(cString: sqlite3_errmsg(db))
    }
}
