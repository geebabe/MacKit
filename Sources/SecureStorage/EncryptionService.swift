// SecureStorage/EncryptionService.swift
// AES-256-GCM encryption using CryptoKit.
// Key stored in Keychain — never in UserDefaults, files, logs or source code.

import Foundation
import CryptoKit
import Security
import Diagnostics

/// Versioned sealed-box format stored as binary data.
/// Layout: [version:1][nonce:12][ciphertext:N][tag:16]
/// Associated data (authenticated but not encrypted) is passed separately.
private enum SealedFormat {
    static let currentVersion: UInt8 = 1
    static let nonceLength = 12
    static let tagLength = 16
    static let headerLength = 1 + nonceLength // version byte + nonce
}

/// Thread-safe encryption service backed by a Keychain-stored AES-256-GCM key.
/// Conforms to Sendable because all mutable state is isolated to the actor.
public actor EncryptionService {

    // MARK: - Keychain constants

    private let keychainService = "com.mackit.app"
    private let keychainAccount = "clipboard-encryption-key-v1"

    // MARK: - State

    private var _key: SymmetricKey?

    // MARK: - Initialisation

    public init(inMemoryKey: SymmetricKey? = nil) {
        self._key = inMemoryKey
    }

    // MARK: - Public interface

    /// Loads or generates the encryption key.
    /// Returns an error rather than silently replacing an existing key.
    public func prepareKey() async throws {
        if _key != nil { return }
        _key = try loadOrCreateKey()
    }

    /// Encrypt `plaintext` and authenticate `associatedData`.
    /// Throws `AppError.cryptoFailed` on failure.
    public func encrypt(_ plaintext: Data, associatedData: Data = Data()) async throws -> Data {
        let key = try requireKey()
        do {
            let sealedBox = try AES.GCM.seal(plaintext, using: key, authenticating: associatedData)
            return try encode(sealedBox: sealedBox)
        } catch let e as AppError {
            throw e
        } catch {
            throw AppError.cryptoFailed(.encryptionFailed(error.localizedDescription))
        }
    }

    /// Decrypt data previously produced by `encrypt(_:associatedData:)`.
    /// Throws `AppError.cryptoFailed(.authenticationTagInvalid)` if tampered.
    public func decrypt(_ ciphertext: Data, associatedData: Data = Data()) async throws -> Data {
        let key = try requireKey()
        do {
            let sealedBox = try decode(data: ciphertext)
            return try AES.GCM.open(sealedBox, using: key, authenticating: associatedData)
        } catch let e as AppError {
            throw e
        } catch {
            // Distinguish authentication failure from other decryption errors
            if (error as NSError).domain == "CryptoKitError" {
                throw AppError.cryptoFailed(.authenticationTagInvalid)
            }
            throw AppError.cryptoFailed(.decryptionFailed(error.localizedDescription))
        }
    }

    /// True if the key is currently loaded and ready.
    public var isReady: Bool { _key != nil }

    // MARK: - Private helpers

    private func requireKey() throws -> SymmetricKey {
        guard let key = _key else {
            throw AppError.cryptoFailed(.keyLoadFailed("Encryption service not prepared — call prepareKey() first"))
        }
        return key
    }

    private func encode(sealedBox: AES.GCM.SealedBox) throws -> Data {
        guard sealedBox.nonce.withUnsafeBytes({ Data($0) }).count == SealedFormat.nonceLength else {
            throw AppError.cryptoFailed(.encryptionFailed("Unexpected nonce length"))
        }
        var result = Data()
        result.append(SealedFormat.currentVersion)
        result.append(contentsOf: sealedBox.nonce.withUnsafeBytes { Data($0) })
        result.append(contentsOf: sealedBox.ciphertext)
        result.append(contentsOf: sealedBox.tag)
        return result
    }

    private func decode(data: Data) throws -> AES.GCM.SealedBox {
        guard !data.isEmpty else {
            throw AppError.cryptoFailed(.decryptionFailed("Empty ciphertext"))
        }
        let version = data[data.startIndex]
        guard version == SealedFormat.currentVersion else {
            throw AppError.cryptoFailed(.unsupportedVersion(Int(version)))
        }
        let minLength = SealedFormat.headerLength + SealedFormat.tagLength
        guard data.count >= minLength else {
            throw AppError.cryptoFailed(.decryptionFailed("Ciphertext too short"))
        }
        let nonceStart = data.index(data.startIndex, offsetBy: 1)
        let nonceEnd = data.index(nonceStart, offsetBy: SealedFormat.nonceLength)
        let tagStart = data.index(data.endIndex, offsetBy: -SealedFormat.tagLength)

        let nonceData = data[nonceStart..<nonceEnd]
        let ciphertextData = data[nonceEnd..<tagStart]
        let tagData = data[tagStart...]

        do {
            let nonce = try AES.GCM.Nonce(data: nonceData)
            return try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertextData, tag: tagData)
        } catch {
            throw AppError.cryptoFailed(.decryptionFailed("Failed to reconstruct sealed box: \(error.localizedDescription)"))
        }
    }

    // MARK: - Keychain

    private func loadOrCreateKey() throws -> SymmetricKey {
        if let existing = try loadKeyFromKeychain() {
            return existing
        }
        return try generateAndStoreKey()
    }

    private func loadKeyFromKeychain() throws -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw AppError.cryptoFailed(.keyLoadFailed("Keychain returned non-data"))
            }
            guard data.count == 32 else {
                throw AppError.cryptoFailed(.keyLoadFailed("Keychain key has unexpected length \(data.count)"))
            }
            return SymmetricKey(data: data)
        case errSecItemNotFound:
            return nil
        default:
            throw AppError.cryptoFailed(.keyLoadFailed("Keychain read error: \(status)"))
        }
    }

    private func generateAndStoreKey() throws -> SymmetricKey {
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecValueData as String: keyData
        ]
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw AppError.cryptoFailed(.keyStoreFailed("Keychain write error: \(status)"))
        }
        return key
    }
}
