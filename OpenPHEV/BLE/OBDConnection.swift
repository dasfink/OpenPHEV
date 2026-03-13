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

        obdService = OBDService(connectionType: .bluetooth)

        Task {
            do {
                try await obdService?.startConnection(preferedProtocol: .protocol6)  // ISO 15765-4 CAN
                await MainActor.run {
                    self.isConnected = true
                    self.isConnecting = false
                    self.resetIdleTimer()
                }
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

    // MARK: - BMS Health (Tier 2)

    private func probeBMSSupport() async {
        guard let obd = obdService else { return }
        do {
            _ = try await obd.sendCommand("AT SH \(profile.bmsECUHeader)")
            let response = try await obd.sendCommand("22 01 01")
            let hasData = !response.stringValue.contains("NO DATA") && !response.stringValue.contains("ERROR")
            await MainActor.run {
                self.supportsTier2 = hasData
            }
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

            let resp2101 = try await obd.sendCommand("22 01 01")
            let bytes2101 = resp2101.data

            let resp2105 = try await obd.sendCommand("22 01 05")
            let bytes2105 = resp2105.data

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
                rawJSON: "{}"
            )
            onHealthSnapshot?(record)

        } catch {
            await MainActor.run {
                self.errorMessage = "Health report failed: \(error.localizedDescription)"
            }
            _ = try? await obd.sendCommand("AT SH 7DF")
        }
    }

    // MARK: - Idle Timer

    private func resetIdleTimer() {
        DispatchQueue.main.async { [weak self] in
            self?.idleTimer?.invalidate()
            self?.idleTimer = Timer.scheduledTimer(withTimeInterval: self?.idleTimeout ?? 300, repeats: false) { [weak self] _ in
                self?.disconnect()
            }
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
