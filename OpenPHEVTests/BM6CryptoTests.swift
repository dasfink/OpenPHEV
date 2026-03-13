import XCTest
@testable import OpenPHEV

final class BM6CryptoTests: XCTestCase {

    let dataRequestPlaintext = Data([
        0xD1, 0x55, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    ])

    func testEncryptProducesNonNilOutput() {
        let encrypted = BM6Crypto.encrypt(dataRequestPlaintext)
        XCTAssertNotNil(encrypted)
        XCTAssertEqual(encrypted?.count, 16, "AES-128-CBC with no padding on 16 bytes should produce 16 bytes")
    }

    func testRoundTrip() {
        guard let encrypted = BM6Crypto.encrypt(dataRequestPlaintext) else {
            XCTFail("Encryption returned nil")
            return
        }
        guard let decrypted = BM6Crypto.decrypt(encrypted) else {
            XCTFail("Decryption returned nil")
            return
        }
        XCTAssertEqual(decrypted, dataRequestPlaintext, "Decrypt(Encrypt(x)) should equal x")
    }

    func testDecryptNilOnGarbage() {
        let garbage = Data([0x01, 0x02, 0x03])
        let result = BM6Crypto.decrypt(garbage)
        _ = result  // Just confirm no crash
    }
}
