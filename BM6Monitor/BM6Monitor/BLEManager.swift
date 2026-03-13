import Foundation
import CoreBluetooth
import Combine

/// Manages BLE connection to BM6 battery monitor sensor.
/// Scans for devices named "BM6", connects, sends the initialization
/// command on FFF3, and subscribes to notifications on FFF4.
class BLEManager: NSObject, ObservableObject {

    // MARK: - Published State

    @Published var isScanning = false
    @Published var isConnected = false
    @Published var connectionState: ConnectionState = .disconnected
    @Published var latestReading: BM6Reading?
    @Published var readingHistory: [BM6Reading] = []
    @Published var discoveredDevices: [DiscoveredDevice] = []
    @Published var errorMessage: String?

    // MARK: - Configuration

    /// Max history entries to keep in memory
    let maxHistoryCount = 1440  // 24 hours at 1 reading/minute

    // MARK: - BLE Constants

    /// BM6 advertises with this local name
    private let targetDeviceName = "BM6"

    /// Service containing the read/write characteristics
    /// BM6 uses a custom service containing FFF3 (write) and FFF4 (notify)
    private let serviceUUID = CBUUID(string: "FFF0")
    private let writeCharUUID = CBUUID(string: "FFF3")
    private let notifyCharUUID = CBUUID(string: "FFF4")

    /// Command to request voltage/temperature/SOC data
    private let dataRequestCommand = Data([
        0xD1, 0x55, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    ])

    // MARK: - Private

    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var notifyCharacteristic: CBCharacteristic?
    private var pollTimer: Timer?
    private var targetAddress: String?

    // MARK: - Types

    struct DiscoveredDevice: Identifiable {
        let id: String  // peripheral identifier
        let name: String
        let rssi: Int
        let peripheral: CBPeripheral
    }

    enum ConnectionState: String {
        case disconnected = "Disconnected"
        case scanning = "Scanning..."
        case connecting = "Connecting..."
        case discoveringServices = "Discovering services..."
        case ready = "Connected"
        case error = "Error"
    }

    // MARK: - Init

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: - Public API

    func startScanning() {
        guard centralManager.state == .poweredOn else {
            errorMessage = "Bluetooth is not available"
            return
        }
        discoveredDevices = []
        isScanning = true
        connectionState = .scanning
        errorMessage = nil

        centralManager.scanForPeripherals(
            withServices: nil,  // Scan for all — BM6 may not advertise service UUIDs
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )

        // Auto-stop scan after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            if self?.isScanning == true {
                self?.stopScanning()
            }
        }
    }

    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
        if !isConnected {
            connectionState = .disconnected
        }
    }

    func connect(to device: DiscoveredDevice) {
        stopScanning()
        connectionState = .connecting
        connectedPeripheral = device.peripheral
        connectedPeripheral?.delegate = self
        centralManager.connect(device.peripheral, options: nil)
    }

    func disconnect() {
        pollTimer?.invalidate()
        pollTimer = nil
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        connectedPeripheral = nil
        writeCharacteristic = nil
        notifyCharacteristic = nil
        isConnected = false
        connectionState = .disconnected
    }

    func requestReading() {
        guard let char = writeCharacteristic,
              let peripheral = connectedPeripheral else { return }

        guard let encrypted = BM6Crypto.encrypt(dataRequestCommand) else {
            errorMessage = "Encryption failed"
            return
        }

        peripheral.writeValue(encrypted, for: char, type: .withResponse)
    }

    // MARK: - Private Helpers

    private func startPolling() {
        // Request data immediately
        requestReading()

        // Then poll every 30 seconds
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.requestReading()
        }
    }

    private func handleNotification(_ data: Data) {
        guard let decrypted = BM6Crypto.decrypt(data) else {
            errorMessage = "Decryption failed"
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
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEManager: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            errorMessage = nil
        case .poweredOff:
            errorMessage = "Bluetooth is turned off"
            connectionState = .disconnected
        case .unauthorized:
            errorMessage = "Bluetooth permission not granted"
        case .unsupported:
            errorMessage = "Bluetooth LE not supported"
        default:
            errorMessage = "Bluetooth unavailable"
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? ""

        guard name == targetDeviceName else { return }

        let device = DiscoveredDevice(
            id: peripheral.identifier.uuidString,
            name: name,
            rssi: RSSI.intValue,
            peripheral: peripheral
        )

        DispatchQueue.main.async { [weak self] in
            // Avoid duplicates
            if self?.discoveredDevices.contains(where: { $0.id == device.id }) == false {
                self?.discoveredDevices.append(device)
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectionState = .discoveringServices
        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connectionState = .error
        errorMessage = "Failed to connect: \(error?.localizedDescription ?? "Unknown error")"
        isConnected = false
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        isConnected = false
        connectionState = .disconnected
        pollTimer?.invalidate()
        pollTimer = nil

        // Auto-reconnect if unexpected disconnect
        if error != nil, let p = connectedPeripheral {
            connectionState = .connecting
            centralManager.connect(p, options: nil)
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BLEManager: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics([writeCharUUID, notifyCharUUID], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }

        for char in characteristics {
            if char.uuid == writeCharUUID {
                writeCharacteristic = char
            }
            if char.uuid == notifyCharUUID {
                notifyCharacteristic = char
                peripheral.setNotifyValue(true, for: char)
            }
        }

        // Start data flow once both characteristics are found
        if writeCharacteristic != nil && notifyCharacteristic != nil {
            isConnected = true
            connectionState = .ready
            startPolling()
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == notifyCharUUID,
              let data = characteristic.value else { return }
        handleNotification(data)
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            DispatchQueue.main.async { [weak self] in
                self?.errorMessage = "Write error: \(error.localizedDescription)"
            }
        }
    }
}
