import Foundation

/// Parsed battery reading from BM6 sensor
struct BM6Reading: Identifiable {
    let id = UUID()
    let timestamp: Date
    let voltage: Double
    let temperature: Int  // Celsius
    let soc: Int          // 0-100%

    /// Battery status based on voltage thresholds
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

    var color: String {
        switch self {
        case .full: return "statusGreen"
        case .warning: return "statusYellow"
        case .critical: return "statusOrange"
        case .danger: return "statusRed"
        case .unknown: return "statusGray"
        }
    }

    var systemImage: String {
        switch self {
        case .full: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "exclamationmark.octagon.fill"
        case .danger: return "xmark.octagon.fill"
        case .unknown: return "questionmark.circle.fill"
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
    ///   [8:10]  = temperature value (unsigned, °C)
    ///   [12:14] = state of charge (0-100)
    ///   [15:18] = voltage * 100
    static func parse(_ decrypted: Data) -> BM6Reading? {
        guard decrypted.count >= 16 else { return nil }

        let hex = decrypted.map { String(format: "%02x", $0) }.joined()

        // Verify header
        guard hex.hasPrefix("d15507") else { return nil }

        // Temperature
        let tempSignHex = String(hex[hex.index(hex.startIndex, offsetBy: 6)..<hex.index(hex.startIndex, offsetBy: 8)])
        let tempValueHex = String(hex[hex.index(hex.startIndex, offsetBy: 8)..<hex.index(hex.startIndex, offsetBy: 10)])
        guard let tempValue = UInt8(tempValueHex, radix: 16) else { return nil }
        let temperature = tempSignHex == "01" ? -Int(tempValue) : Int(tempValue)

        // State of charge
        let socHex = String(hex[hex.index(hex.startIndex, offsetBy: 12)..<hex.index(hex.startIndex, offsetBy: 14)])
        guard let soc = UInt8(socHex, radix: 16) else { return nil }

        // Voltage: bytes at hex offset 15-18, divided by 100
        // Note: hex offset 15 means we start at character 14 (0-indexed) for the nibble
        let voltHex = String(hex[hex.index(hex.startIndex, offsetBy: 14)..<hex.index(hex.startIndex, offsetBy: 18)])
        guard let voltRaw = UInt16(voltHex, radix: 16) else { return nil }
        let voltage = Double(voltRaw) / 100.0

        return BM6Reading(
            timestamp: Date(),
            voltage: voltage,
            temperature: temperature,
            soc: Int(soc)
        )
    }
}
