import XCTest
@testable import OpenPHEV

final class VehicleProfileTests: XCTestCase {

    func testPID2101PackVoltageParsing() {
        // 356.4V = 3564 decimal = 0x0DEC
        let raw: UInt16 = 0x0DEC
        let voltage = Double(raw) / 10.0
        XCTAssertEqual(voltage, 356.4, accuracy: 0.1)
    }

    func testPID2105SOHParsing() {
        // 962 = 96.2%
        let raw: Int16 = 962
        let soh = Double(raw) / 10.0
        XCTAssertEqual(soh, 96.2, accuracy: 0.1)
    }

    func testCellVoltageParsing() {
        // Min cell voltage: x/50 where x = 186 → 3.72V
        let raw: UInt8 = 186
        let voltage = Double(raw) / 50.0
        XCTAssertEqual(voltage, 3.72, accuracy: 0.01)
    }

    func testTemperatureParsing() {
        let raw: Int8 = 24
        XCTAssertEqual(Int(raw), 24)

        let negative: Int8 = -5
        XCTAssertEqual(Int(negative), -5)
    }

    func testBMS2101ParseValidBytes() {
        // Create a 32-byte mock response
        var bytes = [UInt8](repeating: 0, count: 32)
        bytes[6] = 78   // SOC = 78%
        bytes[8] = 186  // maxCellV = 186/50 = 3.72V
        bytes[10] = 185 // minCellV = 185/50 = 3.70V
        // Pack voltage: 3564 = 0x0DEC → bytes[13]=0x0D, bytes[14]=0xEC
        bytes[11] = 0x00 // pack current high
        bytes[12] = 0x7B // pack current low (123 → 12.3A)
        bytes[13] = 0x0D // pack voltage high
        bytes[14] = 0xEC // pack voltage low
        bytes[15] = 27   // maxTemp
        bytes[16] = 24   // minTemp

        let result = TucsonPHEV2023.BMS2101.parse(bytes)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.packVoltage, 356.4, accuracy: 0.1)
        XCTAssertEqual(result?.soc, 78)
        XCTAssertEqual(result?.maxCellV, 3.72, accuracy: 0.01)
        XCTAssertEqual(result?.minCellV, 3.70, accuracy: 0.01)
        XCTAssertEqual(result?.maxTemp, 27)
        XCTAssertEqual(result?.minTemp, 24)
    }

    func testBMS2101ParseTooShort() {
        let shortBytes = [UInt8](repeating: 0, count: 10)
        XCTAssertNil(TucsonPHEV2023.BMS2101.parse(shortBytes))
    }

    func testBMS2105ParseValidBytes() {
        var bytes = [UInt8](repeating: 0, count: 32)
        bytes[20] = 1    // cellDeviation = 1/50 = 0.02V
        // sohMax: 962 = 0x03C2 → bytes[25]=0x03, bytes[26]=0xC2
        bytes[25] = 0x03
        bytes[26] = 0xC2
        // sohMin: 958 = 0x03BE → bytes[27]=0x03, bytes[28]=0xBE
        bytes[27] = 0x03
        bytes[28] = 0xBE

        let result = TucsonPHEV2023.BMS2105.parse(bytes)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.sohMax, 96.2, accuracy: 0.1)
        XCTAssertEqual(result?.sohMin, 95.8, accuracy: 0.1)
        XCTAssertEqual(result?.cellDeviation, 0.02, accuracy: 0.01)
    }
}
