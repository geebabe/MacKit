// SecureStorage/PayloadStore.swift
// Application-private storage for encrypted payload files (text, images).
// Uses opaque random filenames and atomic writes. Never stores unencrypted data.

import Foundation
import Diagnostics

/// Manages encrypted payload files on disk.
public actor PayloadStore {

    public let baseDirectory: URL
    private let encryptionService: EncryptionService
    private let logger = Logger(category: .storage)

    public init(baseDirectory: URL, encryptionService: EncryptionService) {
        self.baseDirectory = baseDirectory
        self.encryptionService = encryptionService
    }

    /// Ensure the payload directory exists with appropriate permissions.
    public func prepare() throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: baseDirectory.path) {
            try fm.createDirectory(at: baseDirectory, withIntermediateDirectories: true, attributes: [
                .posixPermissions: 0o700
            ])
            logger.info("Created payload store directory")
        }
    }

    /// Encrypt and atomically write a payload to disk.
    /// Returns the opaque relative filename.
    public func writePayload(_ data: Data, associatedID: UUID) async throws -> String {
        try prepare()

        // Authenticate with the item's UUID as associated data
        let assocData = associatedID.uuidString.data(using: .utf8) ?? Data()
        let encrypted = try await encryptionService.encrypt(data, associatedData: assocData)

        let filename = "\(UUID().uuidString).enc"
        let fileURL = baseDirectory.appendingPathComponent(filename)

        // Write atomically via temporary file
        let tempURL = baseDirectory.appendingPathComponent("\(UUID().uuidString).tmp")
        do {
            try encrypted.write(to: tempURL, options: .atomic)
            let fm = FileManager.default
            if fm.fileExists(atPath: fileURL.path) {
                try fm.removeItem(at: fileURL)
            }
            try fm.moveItem(at: tempURL, to: fileURL)
            return filename
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            throw AppError.storageFailed(.writeFailed(error.localizedDescription))
        }
    }

    /// Read and decrypt a payload from disk.
    public func readPayload(filename: String, associatedID: UUID) async throws -> Data {
        let fileURL = baseDirectory.appendingPathComponent(filename)
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path) else {
            throw AppError.storageFailed(.readFailed("Payload file missing: \(filename)"))
        }

        let encryptedData: Data
        do {
            encryptedData = try Data(contentsOf: fileURL)
        } catch {
            throw AppError.storageFailed(.readFailed("Failed reading payload: \(error.localizedDescription)"))
        }

        let assocData = associatedID.uuidString.data(using: .utf8) ?? Data()
        return try await encryptionService.decrypt(encryptedData, associatedData: assocData)
    }

    /// Delete an encrypted payload file from disk.
    public func deletePayload(filename: String) {
        let fileURL = baseDirectory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// Delete all files in the payload store.
    public func deleteAllPayloads() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: baseDirectory, includingPropertiesForKeys: nil) else { return }
        for file in files {
            try? fm.removeItem(at: file)
        }
    }
}

