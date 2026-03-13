import SwiftUI

struct ContentView: View {
    @StateObject private var ble: BLEManager
    @State private var stats: BatteryStats?

    init() {
        let db = try? AppDatabase.openDatabase()
        let store = db.flatMap { try? BatteryStore(db: $0) }
        _ble = StateObject(wrappedValue: BLEManager(store: store))
    }

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

                // EV Battery — show data or placeholder
                if let health = ble.obd.latestBMSData {
                    EVHealthCard(health: health)
                        .padding(.horizontal)
                } else {
                    PlaceholderCard(
                        title: "EV Battery",
                        message: ble.obd.isConnected ? "Tap to run health report" : "Connect Veepeak to scan",
                        action: ble.obd.isConnected && ble.obd.supportsTier2 ? {
                            Task { await ble.obd.runHealthReport() }
                        } : nil
                    )
                    .padding(.horizontal)
                }

                // Diagnostics — show data or placeholder
                if ble.obd.isConnected {
                    DiagnosticsCard(
                        troubleCodes: ble.obd.troubleCodes,
                        isConnected: true,
                        onScan: {
                            Task { await ble.obd.readTroubleCodes() }
                        }
                    )
                    .padding(.horizontal)
                } else {
                    PlaceholderCard(
                        title: "Diagnostics",
                        message: "Requires Veepeak connection"
                    )
                    .padding(.horizontal)
                }

                // Veepeak connect button
                if !ble.obd.isConnected {
                    Button {
                        ble.obd.connect()
                    } label: {
                        Text(ble.obd.isConnecting ? "Connecting..." : "Connect Veepeak")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(white: 0.2), lineWidth: 1)
                            )
                    }
                    .disabled(ble.obd.isConnecting)
                    .padding(.top, 8)
                }

                // Error display
                if let error = ble.obd.errorMessage {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.statusDanger)
                        .padding(.horizontal)
                }

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
    }
}
