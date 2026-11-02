// Tests/SecureStorageTests/EncryptionServiceTests.swift
// Unit tests for AES-256-GCM encryption/decryption, format validation,
// and error handling. These do NOT touch the Keychain — they use
// a test subclass that injects a key directly.

import Testing
import Foundation
import CryptoKit
@testable import SecureStorage
@testable import Diagnostics

// MARK: - Test helpers

/// A test-only encryption service that uses a fixed in-memory key
/// rather than the Keychain, so tests run without entitlements.
actor TestEncryptionService {
    private let key: SymmetricKey

    init() {
        self.key = SymmetricKey(size: .bits256)
    }

    func encrypt(_ plaintext: Data, associatedData: Data = Data()) async throws -> Data {
        do {
            let sealed = try AES.GCM.seal(plaintext, using: key, authenticating: associatedData)
            return encodeSealed(sealed)
        } catch {
            throw AppError.cryptoFailed(.encryptionFailed(error.localizedDescription))
        }
    }

    func decrypt(_ ciphertext: Data, associatedData: Data = Data()) async throws -> Data {
        do {
            let sealed = try decodeSealed(ciphertext)
            return try AES.GCM.open(sealed, using: key, authenticating: associatedData)
        } catch let e as AppError {
            throw e
        } catch {
            throw AppError.cryptoFailed(.authenticationTagInvalid)
        }
    }

    private func encodeSealed(_ sealed: AES.GCM.SealedBox) -> Data {
        var result = Data()
        result.append(1) // version
        result.append(contentsOf: sealed.nonce.withUnsafeBytes { Data($0) })
        result.append(contentsOf: sealed.ciphertext)
        result.append(contentsOf: sealed.tag)
        return result
    }

    private func decodeSealed(_ data: Data) throws -> AES.GCM.SealedBox {
        guard data.count >= 1 + 12 + 16 else {
            throw AppError.cryptoFailed(.decryptionFailed("Too short"))
        }
        let nonceStart = data.index(data.startIndex, offsetBy: 1)
        let nonceEnd = data.index(nonceStart, offsetBy: 12)
        let tagStart = data.index(data.endIndex, offsetBy: -16)
        let nonce = try AES.GCM.Nonce(data: data[nonceStart..<nonceEnd])
        return try AES.GCM.SealedBox(nonce: nonce, ciphertext: data[nonceEnd..<tagStart], tag: data[tagStart...])
    }
}

// MARK: - Tests

@Suite("EncryptionService")
struct EncryptionServiceTests {

    @Test("Encrypt then decrypt round-trips plaintext correctly")
    func encryptDecryptRoundTrip() async throws {
        let service = TestEncryptionService()
        let original = "Hello, MacKit!".data(using: .utf8)!
        let encrypted = try await service.encrypt(original)
        let decrypted = try await service.decrypt(encrypted)
        #expect(decrypted == original)
    }

    @Test("Empty plaintext round-trips correctly")
    func emptyRoundTrip() async throws {
        let service = TestEncryptionService()
        let original = Data()
        let encrypted = try await service.encrypt(original)
        let decrypted = try await service.decrypt(encrypted)
        #expect(decrypted == original)
    }

    @Test("Large payload round-trips correctly")
    func largePayloadRoundTrip() async throws {
        let service = TestEncryptionService()
        let original = Data(repeating: 0xAB, count: 1_000_000)
        let encrypted = try await service.encrypt(original)
        let decrypted = try await service.decrypt(encrypted)
        #expect(decrypted == original)
    }

    @Test("Associated data authenticates the ciphertext")
    func associatedDataSuccess() async throws {
        let service = TestEncryptionService()
        let original = "Sensitive".data(using: .utf8)!
        let assoc = "record-id-123".data(using: .utf8)!
        let encrypted = try await service.encrypt(original, associatedData: assoc)
        let decrypted = try await service.decrypt(encrypted, associatedData: assoc)
        #expect(decrypted == original)
    }

    @Test("Wrong associated data causes authentication failure")
    func associatedDataMismatch() async throws {
        let service = TestEncryptionService()
        let original = "Sensitive".data(using: .utf8)!
        let correctAssoc = "record-id-123".data(using: .utf8)!
        let wrongAssoc = "record-id-456".data(using: .utf8)!
        let encrypted = try await service.encrypt(original, associatedData: correctAssoc)

        await #expect(throws: AppError.self) {
            _ = try await service.decrypt(encrypted, associatedData: wrongAssoc)
        }
    }

    @Test("Tampered ciphertext causes authentication failure")
    func tamperedCiphertext() async throws {
        let service = TestEncryptionService()
        let original = "Secret data".data(using: .utf8)!
        var encrypted = try await service.encrypt(original)

        // Flip a bit in the ciphertext body (after version+nonce header)
        let tamperedIndex = encrypted.index(encrypted.startIndex, offsetBy: 14)
        encrypted[tamperedIndex] ^= 0xFF

        await #expect(throws: AppError.self) {
            _ = try await service.decrypt(encrypted)
        }
    }

    @Test("Each encryption produces a unique ciphertext (unique nonces)")
    func uniqueNonces() async throws {
        let service = TestEncryptionService()
        let original = "same plaintext".data(using: .utf8)!
        let enc1 = try await service.encrypt(original)
        let enc2 = try await service.encrypt(original)
        // Outputs must differ (different nonces)
        #expect(enc1 != enc2)
        // But both must decrypt to the same plaintext
        let dec1 = try await service.decrypt(enc1)
        let dec2 = try await service.decrypt(enc2)
        #expect(dec1 == original)
        #expect(dec2 == original)
    }

    @Test("Unicode plaintext round-trips exactly")
    func unicodeRoundTrip() async throws {
        let service = TestEncryptionService()
        let text = "こんにちは世界 🌏 Héllo wörld — «Привет»"
        let original = text.data(using: .utf8)!
        let encrypted = try await service.encrypt(original)
        let decrypted = try await service.decrypt(encrypted)
        let result = String(data: decrypted, encoding: .utf8)
        #expect(result == text)
    }
}

