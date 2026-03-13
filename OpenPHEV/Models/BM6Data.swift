import Foundation
import SwiftUI

/// Parsed battery reading from BM6 sensor
struct BM6Reading: Identifiable {
    let id = UUID()
    let timestamp: Date
    let voltage: Double
    let temperature: Int   // Celsius
    let soc: Int           // 0-100%
    let isCharging: Bool

    var status: BatteryStatus {
        if voltage >= 12.6 { return .full }
        if voltage >= 12.4 { return .warning }
        if voltage >= 12.0 { return .critical }
        return .danger
    }
}

enum BatteryStatus: String {
    case full = "Charged"
    case warning = "Warning"
    case critical = "Critical"
    case danger = "Danger"
    case unknown = "Unknown"

    var color: Color {
        switch self {
        case .full: return Color(red: 0.29, green: 0.85, blue: 0.50)     // #4ade80
        case .warning: return Color(red: 0.98, green: 0.80, blue: 0.08)  // #facc15
        case .critical: return Color(red: 0.98, green: 0.45, blue: 0.09) // #f97316
        case .danger: return Color(red: 0.94, green: 0.27, blue: 0.27)   // #ef4444
        case .unknown: return .gray
        }
    }

    var advice: String {
        switch self {
        case .full: return "Battery is healthy"
        case .warning: return "Drive or plug in soon"
        case .critical: return "Drive or plug in immediately"
        case .danger: return "Sulfation risk — battery damage possible"
        case .unknown: return "Connecting..."
        }
    }
}

/// Parses decrypted BM6 BLE notification packets
struct BM6Parser {

    /// Parse a 16-byte decrypted BM6 notification into a reading.
    ///
    /// Packet structure (hex string of decrypted bytes):
    ///   [0:6]   = "d15507" header
    ///   [6:8]   = temperature sign: "01" = negative
    ///   [8:10]  = temperature value (unsigned, C)
    ///   [10:12] = charging flag (non-zero = charging)
    ///   [12:14] = state of charge (0-100)
    ///   [14:18] = voltage * 100
    static func parse(_ decrypted: Data) -> BM6Reading? {
        guard decrypted.count >= 16 else { return nil }

        let hex = decrypted.map { String(format: "%02x", $0) }.joined()

        guard hex.hasPrefix("d15507") else { return nil }

        // Temperature
        let tempSignHex = String(hex[hex.index(hex.startIndex, offsetBy: 6)..<hex.index(hex.startIndex, offsetBy: 8)])
        let tempValueHex = String(hex[hex.index(hex.startIndex, offsetBy: 8)..<hex.index(hex.startIndex, offsetBy: 10)])
        guard let tempValue = UInt8(tempValueHex, radix: 16) else { return nil }
        let temperature = tempSignHex == "01" ? -Int(tempValue) : Int(tempValue)

        // Charging flag
        let chargingHex = String(hex[hex.index(hex.startIndex, offsetBy: 10)..<hex.index(hex.startIndex, offsetBy: 12)])
        let isCharging = chargingHex != "00"

        // State of charge
        let socHex = String(hex[hex.index(hex.startIndex, offsetBy: 12)..<hex.index(hex.startIndex, offsetBy: 14)])
        guard let soc = UInt8(socHex, radix: 16) else { return nil }

        // Voltage
        let voltHex = String(hex[hex.index(hex.startIndex, offsetBy: 14)..<hex.index(hex.startIndex, offsetBy: 18)])
        guard let voltRaw = UInt16(voltHex, radix: 16) else { return nil }
        let voltage = Double(voltRaw) / 100.0

        return BM6Reading(
            timestamp: Date(),
            voltage: voltage,
            temperature: temperature,
            soc: Int(soc),
            isCharging: isCharging
        )
    }
}
