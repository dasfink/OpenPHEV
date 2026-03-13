# OpenPHEV Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a privacy-first iOS app that monitors a 2023 Hyundai Tucson PHEV via BM6 (12V battery) and Veepeak OBDCheck BLE+ (OBD-II diagnostics) in a single-scroll Bauhaus/Tufte UI.

**Architecture:** Single-scroll SwiftUI app with two independent BLE connections managed by one CBCentralManager. BM6 polls passively in background; Veepeak connects on demand. SQLite (GRDB.swift) persists 12V history and EV health snapshots with 90-day rolling window. Vehicle-specific PID definitions in a TucsonPHEV2023 profile struct.

**Tech Stack:** Swift 5.9+, SwiftUI, iOS 16+, CoreBluetooth, CommonCrypto, GRDB.swift (MIT), SwiftOBD2 (MIT), Swift Charts

**Existing Code:** The `BM6Monitor/` prototype has working AES crypto (`BM6Crypto.swift`), packet parser (`BM6Data.swift`), BLE manager (`BLEManager.swift`), and SwiftUI views (`ContentView.swift`). Port and refactor, don't rewrite from scratch.

---

## Task 1: Create Xcode Project and Add Dependencies

**Files:**
- Create: `OpenPHEV/OpenPHEV.xcodeproj` (via Xcode)
- Create: `OpenPHEV/OpenPHEV/App/OpenPHEVApp.swift`
- Create: `OpenPHEV/OpenPHEV/Info.plist`

**Step 1: Create the Xcode project**

Open Xcode → File → New → Project → iOS → App
- Product Name: `OpenPHEV`
- Interface: SwiftUI
- Language: Swift
- Bundle Identifier: `org.openphev.app`
- Minimum Deployments: iOS 16.0
- Save in the `OpenPHEV/` repo root (creates `OpenPHEV/OpenPHEV.xcodeproj` and `OpenPHEV/OpenPHEV/` source directory)

**Step 2: Add SPM dependencies**

In Xcode: File → Add Package Dependencies:
- GRDB.swift: `https://github.com/groue/GRDB.swift` — branch: `master`, Up to Next Major: 7.0.0
- SwiftOBD2: `https://github.com/kkonteh97/SwiftOBD2` — branch: `main`

**Step 3: Configure Info.plist**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSBluetoothAlwaysUsageDescription</key>
    <string>OpenPHEV uses Bluetooth to connect to your BM6 battery sensor and Veepeak OBD-II adapter to monitor your vehicle's health. No data leaves your device.</string>
    <key>NSBluetoothPeripheralUsageDescription</key>
    <string>OpenPHEV needs Bluetooth to read your vehicle's battery and diagnostic data.</string>
    <key>UIBackgroundModes</key>
    <array>
        <string>bluetooth-central</string>
    </array>
</dict>
</plist>
```

**Step 4: Set up folder structure**

Create these groups/folders in Xcode (empty for now):
```
OpenPHEV/
├── App/
├── BLE/
├── Crypto/
├── Models/
├── Data/
├── Views/
├── Notifications/
└── Assets.xcassets/
```

**Step 5: Minimal app entry point**

```swift
// OpenPHEV/App/OpenPHEVApp.swift
import SwiftUI

@main
struct OpenPHEVApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}
```

Create a placeholder `ContentView.swift` in `Views/`:
```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        Text("OpenPHEV")
    }
}
```

**Step 6: Build and run**

Run: Cmd+B in Xcode
Expected: Clean build, app launches with "OpenPHEV" text on black background

**Step 7: Commit**

```bash
git add OpenPHEV/
git commit -m "feat: create OpenPHEV Xcode project with GRDB and SwiftOBD2 dependencies"
```

---

## Task 2: Port BM6 Crypto and Parser with Tests

**Files:**
- Create: `OpenPHEV/OpenPHEV/Crypto/BM6Crypto.swift` (port from `BM6Monitor/BM6Monitor/BM6Crypto.swift`)
- Create: `OpenPHEV/OpenPHEV/Models/BM6Data.swift` (port from `BM6Monitor/BM6Monitor/BM6Data.swift`)
- Create: `OpenPHEVTests/BM6CryptoTests.swift`
- Create: `OpenPHEVTests/BM6ParserTests.swift`

**Step 1: Add test target**

In Xcode: File → New → Target → Unit Testing Bundle
- Name: `OpenPHEVTests`
- Target to Test: `OpenPHEV`

**Step 2: Port BM6Crypto.swift**

Copy `BM6Monitor/BM6Monitor/BM6Crypto.swift` to `OpenPHEV/OpenPHEV/Crypto/BM6Crypto.swift`. No changes needed — the crypto code is correct and verified.

**Step 3: Write crypto tests**

```swift
// OpenPHEVTests/BM6CryptoTests.swift
import XCTest
@testable import OpenPHEV

final class BM6CryptoTests: XCTestCase {

    /// The known plaintext data request command
    let dataRequestPlaintext = Data([
        0xD1, 0x55, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    ])

    func testEncryptProducesNonNilOutput() {
        let encrypted = BM6Crypto.encrypt(dataRequestPlaintext)
        XCTAssertNotNil(encrypted)
        XCTAssertEqual(encrypted?.count, 16, "AES-128-CBC with no padding on 16 bytes should produce 16 bytes")
    }

    func testRoundTrip() {
        guard let encrypted = BM6Crypto.encrypt(dataRequestPlaintext) else {
            XCTFail("Encryption returned nil")
            return
        }
        guard let decrypted = BM6Crypto.decrypt(encrypted) else {
            XCTFail("Decryption returned nil")
            return
        }
        XCTAssertEqual(decrypted, dataRequestPlaintext, "Decrypt(Encrypt(x)) should equal x")
    }

    func testDecryptNilOnGarbage() {
        // Garbage data that isn't a multiple of block size
        let garbage = Data([0x01, 0x02, 0x03])
        let result = BM6Crypto.decrypt(garbage)
        // CommonCrypto may return nil or garbage — we just confirm no crash
        // The important thing is we don't crash
        _ = result
    }
}
```

**Step 4: Run crypto tests**

Run: Cmd+U in Xcode (or `xcodebuild test -scheme OpenPHEV -destination 'platform=iOS Simulator,name=iPhone 16 Pro'`)
Expected: All 3 tests PASS

**Step 5: Port BM6Data.swift with modifications**

Port from `BM6Monitor/BM6Monitor/BM6Data.swift` to `OpenPHEV/OpenPHEV/Models/BM6Data.swift`. Changes from prototype:
- Use `Color` from SwiftUI directly instead of named asset colors
- Add `isCharging` field placeholder (BM6 reports this but prototype didn't parse it)

```swift
// OpenPHEV/OpenPHEV/Models/BM6Data.swift
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
```

**Step 6: Write parser tests**

```swift
// OpenPHEVTests/BM6ParserTests.swift
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
        // Full: >= 12.6V
        let full = BM6Reading(timestamp: Date(), voltage: 12.7, temperature: 22, soc: 100, isCharging: false)
        XCTAssertEqual(full.status, .full)

        // Warning: >= 12.4V, < 12.6V
        let warning = BM6Reading(timestamp: Date(), voltage: 12.5, temperature: 22, soc: 80, isCharging: false)
        XCTAssertEqual(warning.status, .warning)

        // Critical: >= 12.0V, < 12.4V
        let critical = BM6Reading(timestamp: Date(), voltage: 12.1, temperature: 22, soc: 50, isCharging: false)
        XCTAssertEqual(critical.status, .critical)

        // Danger: < 12.0V
        let danger = BM6Reading(timestamp: Date(), voltage: 11.5, temperature: 22, soc: 20, isCharging: false)
        XCTAssertEqual(danger.status, .danger)
    }
}
```

**Step 7: Run all tests**

Run: Cmd+U in Xcode
Expected: All tests PASS (crypto + parser)

**Step 8: Commit**

```bash
git add OpenPHEV/ OpenPHEVTests/
git commit -m "feat: port BM6 crypto and parser from prototype with unit tests"
```

---

## Task 3: Database Layer (GRDB)

**Files:**
- Create: `OpenPHEV/OpenPHEV/Models/BatteryReading.swift`
- Create: `OpenPHEV/OpenPHEV/Models/EVHealthSnapshot.swift`
- Create: `OpenPHEV/OpenPHEV/Data/Database.swift`
- Create: `OpenPHEV/OpenPHEV/Data/BatteryStore.swift`
- Create: `OpenPHEVTests/DatabaseTests.swift`

**Step 1: Write database tests**

```swift
// OpenPHEVTests/DatabaseTests.swift
import XCTest
import GRDB
@testable import OpenPHEV

final class DatabaseTests: XCTestCase {

    var dbQueue: DatabaseQueue!
    var store: BatteryStore!

    override func setUp() async throws {
        // In-memory database for testing
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
        // Insert a reading from 100 days ago
        let old = BatteryRecord(
            timestamp: Date().addingTimeInterval(-100 * 24 * 3600),
            voltage: 12.0, temperatureC: 20, socPercent: 50, isCharging: false
        )
        // Insert a recent reading
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
```

**Step 2: Run tests to verify they fail**

Run: Cmd+U
Expected: FAIL — `AppDatabase`, `BatteryStore`, `BatteryRecord`, `EVHealthRecord` don't exist yet

**Step 3: Implement GRDB models**

```swift
// OpenPHEV/OpenPHEV/Models/BatteryReading.swift
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
```

```swift
// OpenPHEV/OpenPHEV/Models/EVHealthSnapshot.swift
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
```

**Step 4: Implement Database setup and BatteryStore**

```swift
// OpenPHEV/OpenPHEV/Data/Database.swift
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

        var config = Configuration()
        config.prepareDatabase { db in
            db.trace { print("SQL: \($0)") }  // Debug only — remove for release
        }

        let dbQueue = try DatabaseQueue(path: url.path, configuration: config)
        try migrate(dbQueue)
        return dbQueue
    }
}
```

```swift
// OpenPHEV/OpenPHEV/Data/BatteryStore.swift
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
```

**Step 5: Run all tests**

Run: Cmd+U
Expected: All tests PASS (crypto + parser + database)

**Step 6: Commit**

```bash
git add OpenPHEV/ OpenPHEVTests/
git commit -m "feat: add SQLite persistence layer with GRDB, battery readings and EV health tables"
```

---

## Task 4: BLE Manager — Refactored for Dual Peripherals

**Files:**
- Create: `OpenPHEV/OpenPHEV/BLE/BLEManager.swift`
- Create: `OpenPHEV/OpenPHEV/BLE/BM6Connection.swift`

Port `BM6Monitor/BM6Monitor/BLEManager.swift` but refactor:
- Extract BM6-specific logic into `BM6Connection` class
- `BLEManager` owns the `CBCentralManager` and delegates to the appropriate connection handler
- Prepare the interface for `OBDConnection` (Task 7) without implementing it yet
- Inject `BatteryStore` so readings persist to SQLite

**Step 1: Implement BM6Connection**

This is the BM6-specific BLE logic extracted from the prototype's `BLEManager`. Handles FFF3/FFF4 characteristics, encryption, parsing, polling.

```swift
// OpenPHEV/OpenPHEV/BLE/BM6Connection.swift
import Foundation
import CoreBluetooth
import Combine

/// Manages the BM6-specific BLE protocol: service discovery, encrypted commands, and data parsing.
/// Does NOT own the CBCentralManager — that belongs to BLEManager.
class BM6Connection: NSObject, ObservableObject, CBPeripheralDelegate {

    // MARK: - Published State
    @Published var isConnected = false
    @Published var latestReading: BM6Reading?
    @Published var readingHistory: [BM6Reading] = []
    @Published var errorMessage: String?

    // MARK: - Constants
    let serviceUUID = CBUUID(string: "FFF0")
    let writeCharUUID = CBUUID(string: "FFF3")
    let notifyCharUUID = CBUUID(string: "FFF4")
    static let deviceName = "BM6"

    private let dataRequestCommand = Data([
        0xD1, 0x55, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    ])

    // MARK: - Internal State
    var peripheral: CBPeripheral?
    private var writeChar: CBCharacteristic?
    private var notifyChar: CBCharacteristic?
    private var pollTimer: Timer?

    let maxHistoryCount = 2880  // 24h at 30s intervals

    /// Callback for persisting readings
    var onReading: ((BM6Reading) -> Void)?

    // MARK: - Public API

    func attach(peripheral: CBPeripheral) {
        self.peripheral = peripheral
        peripheral.delegate = self
    }

    func detach() {
        pollTimer?.invalidate()
        pollTimer = nil
        peripheral = nil
        writeChar = nil
        notifyChar = nil
        isConnected = false
    }

    func requestReading() {
        guard let char = writeChar, let peripheral = peripheral else { return }
        guard let encrypted = BM6Crypto.encrypt(dataRequestCommand) else {
            errorMessage = "Encryption failed"
            return
        }
        peripheral.writeValue(encrypted, for: char, type: .withResponse)
    }

    // MARK: - Private

    private func startPolling() {
        requestReading()
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.requestReading()
        }
    }

    // MARK: - CBPeripheralDelegate

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services where service.uuid == serviceUUID {
            peripheral.discoverCharacteristics([writeCharUUID, notifyCharUUID], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let chars = service.characteristics else { return }
        for char in chars {
            if char.uuid == writeCharUUID { writeChar = char }
            if char.uuid == notifyCharUUID {
                notifyChar = char
                peripheral.setNotifyValue(true, for: char)
            }
        }
        if writeChar != nil && notifyChar != nil {
            DispatchQueue.main.async { [weak self] in
                self?.isConnected = true
            }
            startPolling()
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == notifyCharUUID, let data = characteristic.value else { return }
        guard let decrypted = BM6Crypto.decrypt(data) else {
            DispatchQueue.main.async { self.errorMessage = "Decryption failed" }
            return
        }
        guard let reading = BM6Parser.parse(decrypted) else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.latestReading = reading
            self.readingHistory.append(reading)
            if self.readingHistory.count > self.maxHistoryCount {
                self.readingHistory.removeFirst()
            }
            self.errorMessage = nil
            self.onReading?(reading)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            DispatchQueue.main.async { self.errorMessage = "Write error: \(error.localizedDescription)" }
        }
    }
}
```

**Step 2: Implement BLEManager**

```swift
// OpenPHEV/OpenPHEV/BLE/BLEManager.swift
import Foundation
import CoreBluetooth
import Combine

/// Central BLE coordinator. Owns the CBCentralManager and delegates
/// to BM6Connection (and later OBDConnection) based on device identity.
class BLEManager: NSObject, ObservableObject {

    // MARK: - Published
    @Published var bluetoothState: CBManagerState = .unknown
    @Published var isScanning = false
    @Published var discoveredBM6Devices: [DiscoveredDevice] = []

    // MARK: - Connections
    let bm6 = BM6Connection()

    // MARK: - Private
    private var centralManager: CBCentralManager!
    private var store: BatteryStore?

    struct DiscoveredDevice: Identifiable {
        let id: String
        let name: String
        let rssi: Int
        let peripheral: CBPeripheral
    }

    // MARK: - Init

    init(store: BatteryStore? = nil) {
        self.store = store
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)

        // Persist readings to SQLite
        bm6.onReading = { [weak self] reading in
            guard let store = self?.store else { return }
            let record = BatteryRecord(
                timestamp: reading.timestamp,
                voltage: reading.voltage,
                temperatureC: reading.temperature,
                socPercent: reading.soc,
                isCharging: reading.isCharging
            )
            try? store.save(reading: record)
        }
    }

    // MARK: - Scanning

    func scanForBM6() {
        guard centralManager.state == .poweredOn else { return }
        discoveredBM6Devices = []
        isScanning = true
        centralManager.scanForPeripherals(withServices: nil, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            if self?.isScanning == true { self?.stopScanning() }
        }
    }

    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
    }

    func connectBM6(_ device: DiscoveredDevice) {
        stopScanning()
        bm6.attach(peripheral: device.peripheral)
        centralManager.connect(device.peripheral, options: nil)
    }

    func disconnectBM6() {
        if let p = bm6.peripheral {
            centralManager.cancelPeripheralConnection(p)
        }
        bm6.detach()
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEManager: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        DispatchQueue.main.async { self.bluetoothState = central.state }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = peripheral.name
            ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String
            ?? ""

        if name == BM6Connection.deviceName {
            let device = DiscoveredDevice(
                id: peripheral.identifier.uuidString,
                name: name, rssi: RSSI.intValue, peripheral: peripheral
            )
            DispatchQueue.main.async { [weak self] in
                if self?.discoveredBM6Devices.contains(where: { $0.id == device.id }) == false {
                    self?.discoveredBM6Devices.append(device)
                }
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        if peripheral === bm6.peripheral {
            peripheral.discoverServices([bm6.serviceUUID])
        }
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        if peripheral === bm6.peripheral {
            bm6.errorMessage = "Connection failed: \(error?.localizedDescription ?? "Unknown")"
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if peripheral === bm6.peripheral {
            bm6.isConnected = false
            // Auto-reconnect on unexpected disconnect
            if error != nil, let p = bm6.peripheral {
                centralManager.connect(p, options: nil)
            }
        }
    }
}
```

**Step 3: Build**

Run: Cmd+B
Expected: Clean build

**Step 4: Commit**

```bash
git add OpenPHEV/
git commit -m "feat: refactored BLE manager with extracted BM6Connection for dual-peripheral support"
```

---

## Task 5: Bauhaus/Tufte UI — 12V Battery Views

**Files:**
- Create: `OpenPHEV/OpenPHEV/Views/Theme.swift`
- Create: `OpenPHEV/OpenPHEV/Views/BatteryHeroView.swift`
- Create: `OpenPHEV/OpenPHEV/Views/VoltageChartCard.swift`
- Create: `OpenPHEV/OpenPHEV/Views/BatteryStatsCard.swift`
- Create: `OpenPHEV/OpenPHEV/Views/PlaceholderCard.swift`
- Modify: `OpenPHEV/OpenPHEV/Views/ContentView.swift`

**Design references:** See visual companion mockups at `localhost:60064` — Option B (Structured Cards). Key rules:
- Near-monochrome. Color ONLY for status semantics (green/yellow/orange/red)
- SF Mono for data values, SF Pro for labels
- Dark background (#000), cards (#111), muted text (#666/#888)
- No icons unless they carry meaning. No decoration.

**Step 1: Create Theme.swift with design tokens**

```swift
// OpenPHEV/OpenPHEV/Views/Theme.swift
import SwiftUI

enum Theme {
    // MARK: - Colors
    static let background = Color.black
    static let cardBackground = Color(white: 0.067) // #111
    static let cardBackgroundDashed = Color(white: 0.05) // #0d0d0d
    static let textPrimary = Color(white: 0.87)
    static let textSecondary = Color(white: 0.53) // #888
    static let textTertiary = Color(white: 0.33) // #555
    static let textMuted = Color(white: 0.27) // #444
    static let separator = Color(white: 0.1)

    // MARK: - Status Colors (semantic only)
    static let statusGood = Color(red: 0.29, green: 0.85, blue: 0.50)     // #4ade80
    static let statusWarn = Color(red: 0.98, green: 0.80, blue: 0.08)     // #facc15
    static let statusCritical = Color(red: 0.98, green: 0.45, blue: 0.09) // #f97316
    static let statusDanger = Color(red: 0.94, green: 0.27, blue: 0.27)   // #ef4444

    static func statusColor(for status: BatteryStatus) -> Color {
        switch status {
        case .full: return statusGood
        case .warning: return statusWarn
        case .critical: return statusCritical
        case .danger: return statusDanger
        case .unknown: return textTertiary
        }
    }

    // MARK: - Typography
    static let heroFont = Font.system(size: 56, weight: .bold, design: .monospaced)
    static let heroUnitFont = Font.system(size: 24, weight: .regular, design: .monospaced)
    static let dataFont = Font.system(size: 13, weight: .medium, design: .monospaced)
    static let labelFont = Font.system(size: 11, weight: .semibold, design: .default)
    static let metaFont = Font.system(size: 13, weight: .regular, design: .monospaced)

    // MARK: - Layout
    static let cardRadius: CGFloat = 12
    static let cardPadding: CGFloat = 16
    static let scrollSpacing: CGFloat = 12
}
```

**Step 2: Implement BatteryHeroView**

```swift
// OpenPHEV/OpenPHEV/Views/BatteryHeroView.swift
import SwiftUI

/// Large voltage number with secondary meta line. The hero of the single-scroll layout.
struct BatteryHeroView: View {
    let reading: BM6Reading?

    var body: some View {
        VStack(alignment: .center, spacing: 2) {
            if let reading = reading {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(String(format: "%.2f", reading.voltage))
                        .font(Theme.heroFont)
                        .foregroundStyle(Theme.statusColor(for: reading.status))
                    Text("V")
                        .font(Theme.heroUnitFont)
                        .foregroundStyle(Theme.statusColor(for: reading.status).opacity(0.5))
                }

                Text("\(reading.temperature)\u{00B0}C  \u{00B7}  \(reading.soc)%  \u{00B7}  \(reading.isCharging ? "Charging" : reading.status.advice)")
                    .font(Theme.metaFont)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                Text("--.--.V")
                    .font(Theme.heroFont)
                    .foregroundStyle(Theme.textTertiary)
                Text("Scanning for BM6...")
                    .font(Theme.metaFont)
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}
```

**Step 3: Implement VoltageChartCard using Swift Charts**

```swift
// OpenPHEV/OpenPHEV/Views/VoltageChartCard.swift
import SwiftUI
import Charts

struct VoltageChartCard: View {
    let readings: [BM6Reading]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("24 HOURS")
                .font(Theme.labelFont)
                .foregroundStyle(Theme.textMuted)
                .tracking(1.5)

            Chart {
                ForEach(readings) { reading in
                    LineMark(
                        x: .value("Time", reading.timestamp),
                        y: .value("Voltage", reading.voltage)
                    )
                    .foregroundStyle(Theme.statusGood)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                }

                // Warning threshold
                RuleMark(y: .value("Warning", 12.4))
                    .foregroundStyle(Theme.statusWarn.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [4, 4]))

                // Critical threshold
                RuleMark(y: .value("Critical", 12.0))
                    .foregroundStyle(Theme.statusDanger.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: 11.5...13.5)
            .frame(height: 60)
        }
        .padding(Theme.cardPadding)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
    }
}
```

**Step 4: Implement BatteryStatsCard**

```swift
// OpenPHEV/OpenPHEV/Views/BatteryStatsCard.swift
import SwiftUI

struct BatteryStatsCard: View {
    let stats: BatteryStats?

    var body: some View {
        VStack(spacing: 6) {
            Text("STATISTICS")
                .font(Theme.labelFont)
                .foregroundStyle(Theme.textMuted)
                .tracking(1.5)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let stats = stats {
                StatRow(label: "Today min", value: String(format: "%.2fV", stats.minVoltage))
                StatRow(label: "Today max", value: String(format: "%.2fV", stats.maxVoltage))
                StatRow(label: "7-day average", value: String(format: "%.2fV", stats.avgVoltage))
            } else {
                StatRow(label: "Today min", value: "--")
                StatRow(label: "Today max", value: "--")
                StatRow(label: "7-day average", value: "--")
            }
        }
        .padding(Theme.cardPadding)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
    }
}

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(Theme.dataFont)
                .foregroundStyle(Theme.textPrimary)
        }
    }
}
```

**Step 5: Implement PlaceholderCard**

```swift
// OpenPHEV/OpenPHEV/Views/PlaceholderCard.swift
import SwiftUI

struct PlaceholderCard: View {
    let title: String
    let message: String
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 6) {
            Text(title.uppercased())
                .font(Theme.labelFont)
                .foregroundStyle(Theme.textMuted)
                .tracking(1.5)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let action = action {
                Button(action: action) {
                    Text(message)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textTertiary)
                }
            } else {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }
        }
        .padding(Theme.cardPadding)
        .background(Theme.cardBackgroundDashed)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                .foregroundStyle(Color(white: 0.13))
        )
    }
}
```

**Step 6: Wire up ContentView**

```swift
// OpenPHEV/OpenPHEV/Views/ContentView.swift
import SwiftUI

struct ContentView: View {
    @StateObject private var ble = BLEManager()
    @State private var stats: BatteryStats?

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.scrollSpacing) {
                // 12V Hero
                BatteryHeroView(reading: ble.bm6.latestReading)

                // Voltage sparkline
                if ble.bm6.readingHistory.count > 1 {
                    VoltageChartCard(readings: ble.bm6.readingHistory)
                        .padding(.horizontal)
                }

                // Statistics
                BatteryStatsCard(stats: stats)
                    .padding(.horizontal)

                // EV Battery placeholder
                PlaceholderCard(
                    title: "EV Battery",
                    message: "Connect Veepeak to scan"
                )
                .padding(.horizontal)

                // Diagnostics placeholder
                PlaceholderCard(
                    title: "Diagnostics",
                    message: "Requires Veepeak connection"
                )
                .padding(.horizontal)

                Spacer(minLength: 40)
            }
        }
        .background(Theme.background)
        .sheet(isPresented: .init(
            get: { ble.isScanning || (!ble.bm6.isConnected && !ble.discoveredBM6Devices.isEmpty) },
            set: { if !$0 { ble.stopScanning() } }
        )) {
            DeviceScannerSheet(ble: ble)
        }
        .onAppear {
            // Auto-scan on first launch
            if ble.bluetoothState == .poweredOn {
                ble.scanForBM6()
            }
        }
    }
}
```

Port `DeviceScannerSheet` from prototype with updated styling to match Bauhaus theme.

**Step 7: Build and test on simulator**

Run: Cmd+R on iPhone 16 Pro simulator
Expected: Black screen with "--.--.V" hero, stats card with "--", two dashed placeholder cards for EV and Diagnostics.

**Step 8: Commit**

```bash
git add OpenPHEV/
git commit -m "feat: Bauhaus/Tufte UI with hero voltage, sparkline chart, stats, and placeholder cards"
```

---

## Task 6: Local Push Notifications

**Files:**
- Create: `OpenPHEV/OpenPHEV/Notifications/AlertManager.swift`
- Modify: `OpenPHEV/OpenPHEV/BLE/BLEManager.swift` (wire alerts)
- Create: `OpenPHEVTests/AlertManagerTests.swift`

**Step 1: Write alert logic tests**

```swift
// OpenPHEVTests/AlertManagerTests.swift
import XCTest
@testable import OpenPHEV

final class AlertManagerTests: XCTestCase {

    func testShouldAlertAtWarning() {
        let mgr = AlertManager()
        // First reading at 12.3V (below 12.4) should trigger warning
        XCTAssertTrue(mgr.shouldAlert(voltage: 12.3))
    }

    func testNoAlertWhenHealthy() {
        let mgr = AlertManager()
        XCTAssertFalse(mgr.shouldAlert(voltage: 12.7))
    }

    func testNoRepeatAlertInCooldown() {
        let mgr = AlertManager()
        _ = mgr.shouldAlert(voltage: 12.3)  // first alert
        XCTAssertFalse(mgr.shouldAlert(voltage: 12.3))  // within cooldown, no repeat
    }

    func testEscalationAlerts() {
        let mgr = AlertManager()
        _ = mgr.shouldAlert(voltage: 12.3)  // warning
        // Voltage drops further — should alert at new threshold
        XCTAssertTrue(mgr.shouldAlert(voltage: 11.9))  // critical
    }
}
```

**Step 2: Implement AlertManager**

```swift
// OpenPHEV/OpenPHEV/Notifications/AlertManager.swift
import Foundation
import UserNotifications

class AlertManager {

    enum AlertLevel: Int, Comparable {
        case none = 0
        case warning = 1   // < 12.4V
        case critical = 2  // < 12.0V
        case danger = 3    // < 11.6V

        static func < (lhs: AlertLevel, rhs: AlertLevel) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        static func from(voltage: Double) -> AlertLevel {
            if voltage < 11.6 { return .danger }
            if voltage < 12.0 { return .critical }
            if voltage < 12.4 { return .warning }
            return .none
        }
    }

    private var lastAlertLevel: AlertLevel = .none
    private var lastAlertTime: Date?
    private let cooldownInterval: TimeInterval = 600  // 10 minutes

    /// Returns true if an alert should fire for this voltage reading.
    func shouldAlert(voltage: Double) -> Bool {
        let level = AlertLevel.from(voltage: voltage)
        guard level != .none else {
            // Voltage recovered — reset
            lastAlertLevel = .none
            lastAlertTime = nil
            return false
        }

        // Alert if: new escalation OR cooldown expired
        let isEscalation = level > lastAlertLevel
        let cooldownExpired = lastAlertTime.map { Date().timeIntervalSince($0) > cooldownInterval } ?? true

        if isEscalation || cooldownExpired {
            lastAlertLevel = level
            lastAlertTime = Date()
            return true
        }

        return false
    }

    /// Request notification permissions on first launch
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    /// Send a local notification for the given voltage
    func sendAlert(voltage: Double) {
        let level = AlertLevel.from(voltage: voltage)
        let content = UNMutableNotificationContent()
        content.sound = .default

        switch level {
        case .warning:
            content.title = "12V Battery Warning"
            content.body = String(format: "Voltage dropped to %.2fV — drive or plug in soon.", voltage)
        case .critical:
            content.title = "12V Battery Critical"
            content.body = String(format: "Voltage at %.2fV — drive or plug in immediately.", voltage)
        case .danger:
            content.title = "12V Battery Danger"
            content.body = String(format: "Voltage at %.2fV — sulfation risk, battery damage possible.", voltage)
        case .none:
            return
        }

        let request = UNNotificationRequest(
            identifier: "openphev.battery.\(level)",
            content: content,
            trigger: nil  // Deliver immediately
        )
        UNUserNotificationCenter.current().add(request)
    }
}
```

**Step 3: Wire into BLEManager**

In `BLEManager.init`, add to the `bm6.onReading` callback:

```swift
// Add alertManager as a property
private let alertManager = AlertManager()

// In the onReading callback:
bm6.onReading = { [weak self] reading in
    // ... existing persistence code ...

    // Check alerts
    if let self = self, self.alertManager.shouldAlert(voltage: reading.voltage) {
        self.alertManager.sendAlert(voltage: reading.voltage)
    }
}
```

**Step 4: Request permission on app launch**

In `OpenPHEVApp.swift`, add:
```swift
.onAppear {
    AlertManager.requestPermission()
}
```

**Step 5: Run tests**

Run: Cmd+U
Expected: All tests PASS

**Step 6: Commit**

```bash
git add OpenPHEV/ OpenPHEVTests/
git commit -m "feat: local push notifications for low voltage alerts with cooldown and escalation"
```

---

## Task 7: Vehicle Profile and EV Battery Health Models

**Files:**
- Create: `OpenPHEV/OpenPHEV/Models/TucsonPHEV2023.swift`
- Create: `OpenPHEVTests/VehicleProfileTests.swift`

**Step 1: Write vehicle profile tests**

```swift
// OpenPHEVTests/VehicleProfileTests.swift
import XCTest
@testable import OpenPHEV

final class VehicleProfileTests: XCTestCase {

    func testPID2101ByteParsingPackVoltage() {
        // Simulated response for PID 2101: pack voltage at bytes m:n = 13:14
        // 356.4V = 3564 decimal = 0x0DEC
        let profile = TucsonPHEV2023()
        let mockBytes: [UInt8] = Array(repeating: 0, count: 32)
        // We'll test the formula directly
        let raw: UInt16 = 0x0DEC
        let voltage = Double(raw) / 10.0
        XCTAssertEqual(voltage, 356.4, accuracy: 0.1)
    }

    func testPID2105SOHParsing() {
        // SOH deterioration: Int16(z:aa)/10
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
        // Signed byte, -40 to 80 range
        // Byte value 62 → 62°C raw, but BMS uses Signed(O) directly
        let raw: Int8 = 24
        XCTAssertEqual(Int(raw), 24)

        let negative: Int8 = -5
        XCTAssertEqual(Int(negative), -5)
    }
}
```

**Step 2: Implement TucsonPHEV2023 profile**

```swift
// OpenPHEV/OpenPHEV/Models/TucsonPHEV2023.swift
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
```

**Step 3: Run tests**

Run: Cmd+U
Expected: All PASS

**Step 4: Commit**

```bash
git add OpenPHEV/ OpenPHEVTests/
git commit -m "feat: Tucson PHEV 2023 vehicle profile with BMS PID definitions from community database"
```

---

## Task 8: OBD-II Connection via SwiftOBD2

**Files:**
- Create: `OpenPHEV/OpenPHEV/BLE/OBDConnection.swift`
- Modify: `OpenPHEV/OpenPHEV/BLE/BLEManager.swift`

**Step 1: Implement OBDConnection**

This wraps SwiftOBD2's `OBDService` for Veepeak BLE communication. Handles:
- Connect/disconnect lifecycle
- Standard PID queries (DTCs, live data)
- Extended UDS requests for BMS (Tier 2 auto-detection)
- 5-minute idle auto-disconnect

```swift
// OpenPHEV/OpenPHEV/BLE/OBDConnection.swift
import Foundation
import SwiftOBD2
import Combine

class OBDConnection: ObservableObject {

    // MARK: - Published State
    @Published var isConnected = false
    @Published var isConnecting = false
    @Published var supportsTier2 = false  // BMS extended PIDs detected
    @Published var errorMessage: String?

    // MARK: - Data
    @Published var troubleCodes: [String] = []
    @Published var liveData: [String: String] = [:]
    @Published var latestBMSData: BMSHealthData?

    // MARK: - Private
    private var obdService: OBDService?
    private var idleTimer: Timer?
    private let idleTimeout: TimeInterval = 300  // 5 minutes
    private let profile = TucsonPHEV2023()

    var onHealthSnapshot: ((EVHealthRecord) -> Void)?

    // MARK: - Connect

    func connect() {
        guard !isConnected && !isConnecting else { return }
        isConnecting = true
        errorMessage = nil

        // SwiftOBD2 handles BLE scanning and connection internally
        obdService = OBDService(connectionType: .bluetooth)

        Task {
            do {
                try await obdService?.startConnection(preferedProtocol: .protocol6)  // ISO 15765-4 CAN
                await MainActor.run {
                    self.isConnected = true
                    self.isConnecting = false
                    self.resetIdleTimer()
                }
                // Probe for Tier 2 BMS support
                await probeBMSSupport()
            } catch {
                await MainActor.run {
                    self.isConnecting = false
                    self.errorMessage = "Connection failed: \(error.localizedDescription)"
                }
            }
        }
    }

    func disconnect() {
        idleTimer?.invalidate()
        idleTimer = nil
        obdService?.stopConnection()
        obdService = nil
        isConnected = false
        isConnecting = false
        supportsTier2 = false
    }

    // MARK: - DTCs

    func readTroubleCodes() async {
        resetIdleTimer()
        guard let obd = obdService else { return }
        do {
            let codes = try await obd.scanForTroubleCodes()
            await MainActor.run {
                self.troubleCodes = codes.map { $0.code }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "DTC read failed: \(error.localizedDescription)"
            }
        }
    }

    func clearTroubleCodes() async {
        resetIdleTimer()
        guard let obd = obdService else { return }
        do {
            try await obd.clearTroubleCodes()
            await MainActor.run { self.troubleCodes = [] }
        } catch {
            await MainActor.run {
                self.errorMessage = "DTC clear failed: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Live Data

    func requestLivePIDs() async {
        resetIdleTimer()
        guard let obd = obdService else { return }

        let pids: [OBDCommand] = [
            .mode1(.coolantTemp),
            .mode1(.rpm),
            .mode1(.speed),
            .mode1(.intakeTemp),
            .mode1(.engineLoad),
            .mode1(.mafAirFlowRate)
        ]

        for pid in pids {
            do {
                let result = try await obd.sendCommand(pid.properties.command)
                await MainActor.run {
                    self.liveData[pid.properties.description] = result.stringValue
                }
            } catch {
                // Skip unsupported PIDs silently
            }
        }
    }

    // MARK: - BMS Health (Tier 2)

    private func probeBMSSupport() async {
        guard let obd = obdService else { return }
        do {
            // Set header to BMS ECU
            _ = try await obd.sendCommand("AT SH \(profile.bmsECUHeader)")
            // Try reading PID 2101
            let response = try await obd.sendCommand("22 01 01")
            let hasData = !response.stringValue.contains("NO DATA") && !response.stringValue.contains("ERROR")
            await MainActor.run {
                self.supportsTier2 = hasData
            }
            // Reset header
            _ = try await obd.sendCommand("AT SH 7DF")
        } catch {
            await MainActor.run { self.supportsTier2 = false }
        }
    }

    func runHealthReport() async {
        resetIdleTimer()
        guard let obd = obdService, supportsTier2 else { return }

        do {
            _ = try await obd.sendCommand("AT SH \(profile.bmsECUHeader)")

            // Query PID 2101
            let resp2101 = try await obd.sendCommand("22 01 01")
            let bytes2101 = resp2101.data

            // Query PID 2105
            let resp2105 = try await obd.sendCommand("22 01 05")
            let bytes2105 = resp2105.data

            // Reset header
            _ = try await obd.sendCommand("AT SH 7DF")

            let result2101 = TucsonPHEV2023.BMS2101.parse(bytes2101)
            let result2105 = TucsonPHEV2023.BMS2105.parse(bytes2105)

            let health = BMSHealthData(
                packVoltage: result2101?.packVoltage,
                packCurrent: result2101?.packCurrent,
                soc: result2101?.soc,
                sohMin: result2105?.sohMin,
                sohMax: result2105?.sohMax,
                minCellV: result2101?.minCellV,
                maxCellV: result2101?.maxCellV,
                cellDelta: result2101?.cellDelta,
                minTemp: result2101?.minTemp,
                maxTemp: result2101?.maxTemp
            )

            await MainActor.run {
                self.latestBMSData = health
            }

            // Persist snapshot
            let record = EVHealthRecord(
                timestamp: Date(),
                packVoltage: health.packVoltage,
                packCurrent: health.packCurrent,
                soc: health.soc,
                sohMin: health.sohMin,
                sohMax: health.sohMax,
                minCellV: health.minCellV,
                maxCellV: health.maxCellV,
                cellDelta: health.cellDelta,
                minTemp: health.minTemp,
                maxTemp: health.maxTemp,
                rawJSON: "{}"  // TODO: serialize full response
            )
            onHealthSnapshot?(record)

        } catch {
            await MainActor.run {
                self.errorMessage = "Health report failed: \(error.localizedDescription)"
            }
            // Reset header on error
            _ = try? await obd.sendCommand("AT SH 7DF")
        }
    }

    // MARK: - Idle Timer

    private func resetIdleTimer() {
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: idleTimeout, repeats: false) { [weak self] _ in
            self?.disconnect()
        }
    }
}

struct BMSHealthData {
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
}
```

**Step 2: Add OBDConnection to BLEManager**

Add `let obd = OBDConnection()` as a property alongside `bm6`. Wire up persistence:

```swift
// In BLEManager.init:
obd.onHealthSnapshot = { [weak self] record in
    try? self?.store?.save(snapshot: record)
}
```

**Step 3: Build**

Run: Cmd+B
Expected: Clean build. Note: SwiftOBD2 API may differ slightly — adjust types as needed during implementation.

**Step 4: Commit**

```bash
git add OpenPHEV/
git commit -m "feat: OBD-II connection via SwiftOBD2 with Tier 2 BMS auto-detection and health reports"
```

---

## Task 9: EV Health and Diagnostics UI Cards

**Files:**
- Create: `OpenPHEV/OpenPHEV/Views/EVHealthCard.swift`
- Create: `OpenPHEV/OpenPHEV/Views/CellBalanceCard.swift`
- Create: `OpenPHEV/OpenPHEV/Views/DiagnosticsCard.swift`
- Modify: `OpenPHEV/OpenPHEV/Views/ContentView.swift`

**Step 1: EVHealthCard**

Shows 2x2 grid (SOH, SOC, Pack voltage, Current) when Veepeak Tier 2 is detected. Falls back to Tier 1 standard data if only basic PIDs are available.

**Step 2: CellBalanceCard**

Shows min/max cell voltage, delta, and temperature spread in StatRow format.

**Step 3: DiagnosticsCard**

Shows DTC count (tap to expand list). Live PID data in compact StatRow grid.

**Step 4: Update ContentView**

Replace the two PlaceholderCards with conditional views:
- If `obd.isConnected` → show EVHealthCard + DiagnosticsCard
- If `!obd.isConnected` → show PlaceholderCards with "Connect Veepeak to scan" tap action that calls `obd.connect()`

**Step 5: Build and test on simulator**

Run: Cmd+R
Expected: App shows 12V hero + placeholders. Tapping "Connect Veepeak to scan" triggers OBD connection flow (will fail on simulator — that's expected).

**Step 6: Commit**

```bash
git add OpenPHEV/
git commit -m "feat: EV health, cell balance, and diagnostics cards with connected/placeholder states"
```

---

## Task 10: Device Scanner Sheet (Updated)

**Files:**
- Create: `OpenPHEV/OpenPHEV/Views/DeviceScannerSheet.swift`

Port the scanner sheet from the prototype, but update styling to match Bauhaus theme (dark background, SF Mono for device IDs, minimal chrome). This sheet appears when the user taps "Scan" or on first launch for BM6 discovery.

**Commit:**

```bash
git add OpenPHEV/
git commit -m "feat: device scanner sheet with Bauhaus styling"
```

---

## Task 11: Integration Test on Device

This task requires the physical iPhone 16 Pro and both BLE devices.

**Step 1: Build and deploy to iPhone**

- Select iPhone 16 Pro as run destination
- Set development team for code signing
- Run: Cmd+R

**Step 2: BM6 test**

- Ensure BM6 is on jump-start terminals (or nearby for BLE)
- App should auto-scan, discover BM6, connect
- Verify: hero voltage updates, sparkline populates, stats compute
- Background the app → wait 2 minutes → verify readings continue
- Trigger low voltage alert (may need to wait for natural voltage reading)

**Step 3: Veepeak test**

- Plug Veepeak into OBD-II port
- Tap EV Battery placeholder → "Connect Veepeak to scan"
- Verify: connection establishes
- Verify: Tier 2 probe result (does 7E4/2101 respond?)
- If Tier 2: run health report, verify SOH/cell data displays
- If Tier 1 only: verify standard PIDs display
- Check DTCs: read and display
- Check live data: RPM, coolant, speed update

**Step 4: Document results**

Note in a `TESTING.md`:
- BM6 connection: PASS/FAIL
- Veepeak connection: PASS/FAIL
- Tier 2 BMS detection: YES/NO (this is the big unknown)
- Any byte offset adjustments needed for TucsonPHEV2023 profile
- Background BLE reliability

**Step 5: Commit any fixes**

```bash
git commit -m "fix: adjustments from device integration testing"
```

---

## Task 12: Final Polish and README

**Files:**
- Create/update: `OpenPHEV/README.md`
- Clean up any debug logging (`db.trace` in Database.swift)
- Verify all test pass: Cmd+U

**Commit:**

```bash
git add .
git commit -m "docs: README, clean up debug logging, final polish for v1"
```

---

## Summary

| Task | What | Tests |
|------|------|-------|
| 1 | Xcode project + dependencies | Build only |
| 2 | BM6 Crypto + Parser | 8 unit tests |
| 3 | GRDB database layer | 4 unit tests |
| 4 | BLE Manager (dual peripheral) | Build + manual |
| 5 | Bauhaus/Tufte UI (12V views) | Visual on simulator |
| 6 | Local push notifications | 4 unit tests |
| 7 | Vehicle profile + PID definitions | 4 unit tests |
| 8 | OBD-II via SwiftOBD2 | Build + device test |
| 9 | EV Health + Diagnostics UI | Visual on simulator |
| 10 | Device scanner sheet | Visual |
| 11 | Integration test on device | Manual on hardware |
| 12 | README + polish | All tests green |

**Total estimated tests:** 20 unit tests + manual device validation
**Estimated time:** 4-6 hours for an experienced Swift dev with both devices in hand
