import Foundation
import GRDB

struct AppDatabase {

    /// Run all migrations on the given database
    static func migrate(_ db: DatabaseWriter) throws {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1") { db in
            try db.create(table: "battery_readings") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("timestamp", .datetime).notNull().indexed()
                t.column("voltage", .double).notNull()
                t.column("temperatureC", .integer).notNull()
                t.column("socPercent", .integer).notNull()
                t.column("isCharging", .boolean).notNull()
            }

            try db.create(table: "ev_health_snapshots") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("timestamp", .datetime).notNull().indexed()
                t.column("packVoltage", .double)
                t.column("packCurrent", .double)
                t.column("soc", .integer)
                t.column("sohMin", .double)
                t.column("sohMax", .double)
                t.column("minCellV", .double)
                t.column("maxCellV", .double)
                t.column("cellDelta", .double)
                t.column("minTemp", .integer)
                t.column("maxTemp", .integer)
                t.column("rawJSON", .text).notNull()
            }
        }

        try migrator.migrate(db)
    }

    /// Create the production database at the app's documents directory
    static func openDatabase() throws -> DatabaseQueue {
        let url = try FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("openphev.sqlite")

        let dbQueue = try DatabaseQueue(path: url.path)
        try migrate(dbQueue)
        return dbQueue
    }
}
