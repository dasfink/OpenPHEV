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
    let obd = OBDConnection()

    // MARK: - Private
    private var centralManager: CBCentralManager!
    private var store: BatteryStore?
    private let alertManager = AlertManager()

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

        // Persist readings to SQLite and check for low-battery alerts
        bm6.onReading = { [weak self] reading in
            guard let self = self else { return }
            // Persist on background queue to avoid blocking UI
            if let store = self.store {
                DispatchQueue.global(qos: .utility).async {
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
            // Check voltage for low-battery alerts
            if self.alertManager.shouldAlert(voltage: reading.voltage) {
                self.alertManager.sendAlert(voltage: reading.voltage)
            }
        }

        // Persist EV health snapshots to SQLite
        obd.onHealthSnapshot = { [weak self] record in
            guard let store = self?.store else { return }
            try? store.save(snapshot: record)
        }

        // Prune readings older than 90 days on launch
        if let store = store {
            DispatchQueue.global(qos: .utility).async {
                try? store.pruneOlderThan(days: 90)
            }
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
        DispatchQueue.main.async {
            self.bluetoothState = central.state
            if central.state == .poweredOn && !self.bm6.isConnected {
                self.scanForBM6()
            }
        }
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
