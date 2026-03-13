import Foundation
import GRDB

struct BatteryStats {
    let minVoltage: Double
    let maxVoltage: Double
    let avgVoltage: Double
}

class BatteryStore {
    let db: DatabaseWriter

    init(db: DatabaseWriter) {
        self.db = db
    }

    // MARK: - 12V Readings

    func save(reading: BatteryRecord) throws {
        var record = reading
        try db.write { db in
            try record.insert(db)
        }
    }

    func recentReadings(limit: Int) -> [BatteryRecord] {
        (try? db.read { db in
            try BatteryRecord
                .order(Column("timestamp").desc)
                .limit(limit)
                .fetchAll(db)
                .reversed()
        }) ?? []
    }

    func readingsLast(hours: Int) -> [BatteryRecord] {
        let since = Date().addingTimeInterval(-Double(hours) * 3600)
        return (try? db.read { db in
            try BatteryRecord
                .filter(Column("timestamp") >= since)
                .order(Column("timestamp").asc)
                .fetchAll(db)
        }) ?? []
    }

    func todayStats() throws -> BatteryStats? {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return try db.read { db in
            let row = try Row.fetchOne(db, sql: """
                SELECT MIN(voltage) AS minV, MAX(voltage) AS maxV, AVG(voltage) AS avgV
                FROM battery_readings
                WHERE timestamp >= ?
                """, arguments: [startOfDay])

            guard let row = row,
                  let minV: Double = row["minV"],
                  let maxV: Double = row["maxV"],
                  let avgV: Double = row["avgV"] else { return nil }

            return BatteryStats(minVoltage: minV, maxVoltage: maxV, avgVoltage: avgV)
        }
    }

    // MARK: - EV Health Snapshots

    func save(snapshot: EVHealthRecord) throws {
        var record = snapshot
        try db.write { db in
            try record.insert(db)
        }
    }

    func recentSnapshots(limit: Int) -> [EVHealthRecord] {
        (try? db.read { db in
            try EVHealthRecord
                .order(Column("timestamp").desc)
                .limit(limit)
                .fetchAll(db)
        }) ?? []
    }

    // MARK: - Pruning

    func pruneOlderThan(days: Int) throws {
        let cutoff = Date().addingTimeInterval(-Double(days) * 24 * 3600)
        try db.write { db in
            try BatteryRecord
                .filter(Column("timestamp") < cutoff)
                .deleteAll(db)
            try EVHealthRecord
                .filter(Column("timestamp") < cutoff)
                .deleteAll(db)
        }
    }
}
