import Foundation
import GRDB

/// Persisted 12V battery reading (one row per 30-second BM6 poll)
struct BatteryRecord: Codable, FetchableRecord, PersistableRecord, Identifiable {
    var id: Int64?
    let timestamp: Date
    let voltage: Double
    let temperatureC: Int
    let socPercent: Int
    let isCharging: Bool

    static let databaseTableName = "battery_readings"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
