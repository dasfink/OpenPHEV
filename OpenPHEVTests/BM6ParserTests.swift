import XCTest
@testable import OpenPHEV

final class BM6ParserTests: XCTestCase {

    /// Construct a fake 16-byte decrypted packet for testing.
    /// Header: d15507, sign, temp, charging, soc, voltage (2 bytes)
    private func makePacket(tempSign: UInt8 = 0x00, temp: UInt8 = 22,
                            charging: UInt8 = 0x00, soc: UInt8 = 94,
                            voltage: UInt16 = 1263) -> Data {
        var bytes: [UInt8] = [0xD1, 0x55, 0x07]       // header [0:3]
        bytes.append(tempSign)                          // [3] temp sign
        bytes.append(temp)                              // [4] temp value
        bytes.append(charging)                          // [5] charging flag
        bytes.append(soc)                               // [6] SOC
        bytes.append(UInt8(voltage >> 8))               // [7] voltage high byte
        bytes.append(UInt8(voltage & 0xFF))             // [8] voltage low byte
        // Pad to 16 bytes
        while bytes.count < 16 { bytes.append(0x00) }
        return Data(bytes)
    }

    func testParseValidPacket() {
        let packet = makePacket(temp: 22, soc: 94, voltage: 1263)
        let reading = BM6Parser.parse(packet)

        XCTAssertNotNil(reading)
        XCTAssertEqual(reading?.temperature, 22)
        XCTAssertEqual(reading?.soc, 94)
        XCTAssertEqual(reading?.voltage, 12.63, accuracy: 0.01)
        XCTAssertEqual(reading?.isCharging, false)
    }

    func testParseNegativeTemperature() {
        let packet = makePacket(tempSign: 0x01, temp: 5)
        let reading = BM6Parser.parse(packet)

        XCTAssertNotNil(reading)
        XCTAssertEqual(reading?.temperature, -5)
    }

    func testParseChargingFlag() {
        let packet = makePacket(charging: 0x01)
        let reading = BM6Parser.parse(packet)

        XCTAssertNotNil(reading)
        XCTAssertEqual(reading?.isCharging, true)
    }

    func testParseTooShort() {
        let short = Data([0xD1, 0x55, 0x07])
        XCTAssertNil(BM6Parser.parse(short))
    }

    func testParseWrongHeader() {
        var packet = makePacket()
        packet[0] = 0xAA  // corrupt header
        XCTAssertNil(BM6Parser.parse(packet))
    }

    func testBatteryStatusThresholds() {
        let full = BM6Reading(timestamp: Date(), voltage: 12.7, temperature: 22, soc: 100, isCharging: false)
        XCTAssertEqual(full.status, .full)

        let warning = BM6Reading(timestamp: Date(), voltage: 12.5, temperature: 22, soc: 80, isCharging: false)
        XCTAssertEqual(warning.status, .warning)

        let critical = BM6Reading(timestamp: Date(), voltage: 12.1, temperature: 22, soc: 50, isCharging: false)
        XCTAssertEqual(critical.status, .critical)

        let danger = BM6Reading(timestamp: Date(), voltage: 11.5, temperature: 22, soc: 20, isCharging: false)
        XCTAssertEqual(danger.status, .danger)
    }
}
