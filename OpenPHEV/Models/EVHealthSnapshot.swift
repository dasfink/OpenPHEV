import Foundation
import GRDB

/// Persisted EV battery health snapshot (one row per OBD-II health scan)
struct EVHealthRecord: Codable, FetchableRecord, PersistableRecord, Identifiable {
    var id: Int64?
    let timestamp: Date
    let packVoltage: Double?
    let packCurrent: Double?
    let soc: Int?
    let sohMin: Double?
    let sohMax: Double?
    let minCellV: Double?
    let maxCellV: Double?
    let cellDelta: Double?
    let minTemp: Int?
    let maxTemp: Int?
    let rawJSON: String

    static let databaseTableName = "ev_health_snapshots"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
