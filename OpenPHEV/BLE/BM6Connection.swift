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
