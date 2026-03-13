import Foundation

/// Vehicle-specific PID definitions for the 2023 Hyundai Tucson PHEV.
/// Extended PIDs derived from Kia Soul EV / Ioniq / Niro community database.
/// ECU: 7E4 (BMS), Response: 7EC, Service: 22 (ReadDataByIdentifier)
///
/// IMPORTANT: These PIDs are UNCONFIRMED on the 2023 Tucson PHEV.
/// Auto-detection probes 7E4/2101 on first connect. If no response,
/// falls back to standard OBD-II only.
struct TucsonPHEV2023 {

    let name = "2023 Hyundai Tucson PHEV Limited AWD"
    let bmsECUHeader = "7E4"
    let bmsResponseHeader = "7EC"

    /// Probe this PID to detect extended BMS support
    let probePID = "2101"

    /// Extended PID definitions (Tier 2)
    struct BMS2101 {
        /// Parse response bytes from PID 2101
        static func parse(_ bytes: [UInt8]) -> BMS2101Result? {
            guard bytes.count >= 32 else { return nil }

            let packVoltage = Double(UInt16(bytes[13]) << 8 | UInt16(bytes[14])) / 10.0
            let packCurrent = Double(Int16(bitPattern: UInt16(bytes[11]) << 8 | UInt16(bytes[12]))) / 10.0
            let soc = Int(bytes[6])
            let maxCellV = Double(bytes[8]) / 50.0
            let minCellV = Double(bytes[10]) / 50.0
            let maxTemp = Int(Int8(bitPattern: bytes[15]))
            let minTemp = Int(Int8(bitPattern: bytes[16]))

            return BMS2101Result(
                packVoltage: packVoltage,
                packCurrent: packCurrent,
                soc: soc,
                maxCellV: maxCellV,
                minCellV: minCellV,
                cellDelta: maxCellV - minCellV,
                maxTemp: maxTemp,
                minTemp: minTemp
            )
        }
    }

    struct BMS2105 {
        /// Parse response bytes from PID 2105
        static func parse(_ bytes: [UInt8]) -> BMS2105Result? {
            guard bytes.count >= 32 else { return nil }

            let cellDeviation = Double(bytes[20]) / 50.0
            let sohMax = Double(Int16(bitPattern: UInt16(bytes[25]) << 8 | UInt16(bytes[26]))) / 10.0
            let sohMin = Double(Int16(bitPattern: UInt16(bytes[27]) << 8 | UInt16(bytes[28]))) / 10.0

            return BMS2105Result(
                cellDeviation: cellDeviation,
                sohMax: sohMax,
                sohMin: sohMin
            )
        }
    }
}

struct BMS2101Result {
    let packVoltage: Double
    let packCurrent: Double
    let soc: Int
    let maxCellV: Double
    let minCellV: Double
    let cellDelta: Double
    let maxTemp: Int
    let minTemp: Int
}

struct BMS2105Result {
    let cellDeviation: Double
    let sohMax: Double
    let sohMin: Double
}
