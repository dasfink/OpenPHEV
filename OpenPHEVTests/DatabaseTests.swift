import XCTest
import GRDB
@testable import OpenPHEV

final class DatabaseTests: XCTestCase {

    var dbQueue: DatabaseQueue!
    var store: BatteryStore!

    override func setUp() async throws {
        dbQueue = try DatabaseQueue()
        try AppDatabase.migrate(dbQueue)
        store = BatteryStore(db: dbQueue)
    }

    func testInsertAndFetchBatteryReading() throws {
        let reading = BatteryRecord(
            timestamp: Date(),
            voltage: 12.63,
            temperatureC: 22,
            socPercent: 94,
            isCharging: false
        )
        try store.save(reading: reading)

        let fetched = try store.recentReadings(limit: 10)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.voltage, 12.63, accuracy: 0.01)
    }

    func testInsertAndFetchEVSnapshot() throws {
        let snapshot = EVHealthRecord(
            timestamp: Date(),
            packVoltage: 356.4,
            packCurrent: 12.3,
            soc: 78,
            sohMin: 95.8,
            sohMax: 96.2,
            minCellV: 3.71,
            maxCellV: 3.73,
            cellDelta: 0.02,
            minTemp: 24,
            maxTemp: 27,
            rawJSON: "{}"
        )
        try store.save(snapshot: snapshot)

        let fetched = try store.recentSnapshots(limit: 10)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.sohMax, 96.2, accuracy: 0.1)
    }

    func testPruneOldReadings() throws {
        let old = BatteryRecord(
            timestamp: Date().addingTimeInterval(-100 * 24 * 3600),
            voltage: 12.0, temperatureC: 20, socPercent: 50, isCharging: false
        )
        let recent = BatteryRecord(
            timestamp: Date(),
            voltage: 12.6, temperatureC: 22, socPercent: 94, isCharging: false
        )
        try store.save(reading: old)
        try store.save(reading: recent)

        try store.pruneOlderThan(days: 90)

        let fetched = try store.recentReadings(limit: 100)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.voltage, 12.6, accuracy: 0.01)
    }

    func testStatsComputation() throws {
        let readings: [(Double, Date)] = [
            (12.3, Date().addingTimeInterval(-3600)),
            (12.5, Date().addingTimeInterval(-1800)),
            (12.7, Date()),
        ]
        for (v, t) in readings {
            try store.save(reading: BatteryRecord(
                timestamp: t, voltage: v, temperatureC: 22, socPercent: 80, isCharging: false
            ))
        }

        let stats = try store.todayStats()
        XCTAssertNotNil(stats)
        XCTAssertEqual(stats?.minVoltage, 12.3, accuracy: 0.01)
        XCTAssertEqual(stats?.maxVoltage, 12.7, accuracy: 0.01)
        XCTAssertEqual(stats?.avgVoltage, 12.5, accuracy: 0.01)
    }
}
