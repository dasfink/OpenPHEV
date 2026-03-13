import Foundation
import CommonCrypto

/// AES-128-CBC encryption/decryption for BM6 protocol.
/// Key extracted from Quicklynks APK reverse engineering.
struct BM6Crypto {

    // AES key: "leagend" + 0xFF 0xFE + "0100009"
    static let key: [UInt8] = [
        0x6C, 0x65, 0x61, 0x67, 0x65, 0x6E, 0x64, 0xFF,
        0xFE, 0x30, 0x31, 0x30, 0x30, 0x30, 0x30, 0x39
    ]

    // IV is 16 zero bytes
    static let iv: [UInt8] = Array(repeating: 0x00, count: 16)

    static func decrypt(_ data: Data) -> Data? {
        return crypt(data, operation: CCOperation(kCCDecrypt))
    }

    static func encrypt(_ data: Data) -> Data? {
        return crypt(data, operation: CCOperation(kCCEncrypt))
    }

    private static func crypt(_ data: Data, operation: CCOperation) -> Data? {
        let keyData = Data(key)
        let ivData = Data(iv)

        let bufferSize = data.count + kCCBlockSizeAES128
        var buffer = Data(count: bufferSize)
        var numBytesProcessed: size_t = 0

        let status = buffer.withUnsafeMutableBytes { bufferPtr in
            data.withUnsafeBytes { dataPtr in
                keyData.withUnsafeBytes { keyPtr in
                    ivData.withUnsafeBytes { ivPtr in
                        CCCrypt(
                            operation,
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(0), // No padding — BM6 packets are always 16 bytes
                            keyPtr.baseAddress, kCCKeySizeAES128,
                            ivPtr.baseAddress,
                            dataPtr.baseAddress, data.count,
                            bufferPtr.baseAddress, bufferSize,
                            &numBytesProcessed
                        )
                    }
                }
            }
        }

        guard status == kCCSuccess else { return nil }
        return buffer.prefix(numBytesProcessed)
    }
}
