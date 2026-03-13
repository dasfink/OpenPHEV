import SwiftUI

struct ContentView: View {
    @StateObject private var ble = BLEManager()
    @State private var showHistory = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Connection status bar
                    ConnectionStatusBar(ble: ble)

                    if let reading = ble.latestReading {
                        // Main voltage display
                        VoltageGaugeView(reading: reading)

                        // Detail cards
                        HStack(spacing: 12) {
                            DetailCard(
                                title: "Temperature",
                                value: "\(reading.temperature)°C",
                                icon: "thermometer.medium",
                                color: reading.temperature > 50 ? .orange : .blue
                            )
                            DetailCard(
                                title: "Charge",
                                value: "\(reading.soc)%",
                                icon: "battery.75percent",
                                color: reading.soc > 50 ? .green : .orange
                            )
                        }
                        .padding(.horizontal)

                        // Status advice
                        StatusBanner(status: reading.status)
                            .padding(.horizontal)

                        // Voltage history mini chart
                        if ble.readingHistory.count > 1 {
                            VoltageChartView(readings: ble.readingHistory)
                                .padding(.horizontal)
                        }

                    } else {
                        // Empty state
                        EmptyStateView(ble: ble)
                    }

                    Spacer(minLength: 40)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("BM6 Monitor")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if ble.isConnected {
                            ble.disconnect()
                        } else {
                            ble.startScanning()
                        }
                    } label: {
                        Image(systemName: ble.isConnected ? "antenna.radiowaves.left.and.right.slash" : "antenna.radiowaves.left.and.right")
                    }
                }
            }
            .sheet(isPresented: .init(
                get: { ble.isScanning || (!ble.isConnected && !ble.discoveredDevices.isEmpty) },
                set: { if !$0 { ble.stopScanning() } }
            )) {
                DeviceScannerSheet(ble: ble)
            }
        }
    }
}

// MARK: - Connection Status Bar

struct ConnectionStatusBar: View {
    @ObservedObject var ble: BLEManager

    var body: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(ble.connectionState.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if let reading = ble.latestReading {
                Text(reading.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal)
        .padding(.top, 4)
    }

    var statusColor: Color {
        switch ble.connectionState {
        case .ready: return .green
        case .connecting, .discoveringServices, .scanning: return .orange
        case .error: return .red
        case .disconnected: return .gray
        }
    }
}

// MARK: - Voltage Gauge

struct VoltageGaugeView: View {
    let reading: BM6Reading

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background arc
                Circle()
                    .trim(from: 0.15, to: 0.85)
                    .stroke(Color(.systemGray5), style: StrokeStyle(lineWidth: 20, lineCap: .round))
                    .rotationEffect(.degrees(90))
                    .frame(width: 200, height: 200)

                // Value arc
                Circle()
                    .trim(from: 0.15, to: gaugeProgress)
                    .stroke(gaugeColor, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                    .rotationEffect(.degrees(90))
                    .frame(width: 200, height: 200)
                    .animation(.easeInOut(duration: 0.5), value: reading.voltage)

                VStack(spacing: 2) {
                    Text(String(format: "%.2f", reading.voltage))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(gaugeColor)
                    Text("VOLTS")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .tracking(2)
                }
            }
            .padding(.top, 20)

            // Min/max labels
            HStack {
                Text("10V")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Text("15V")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 60)
        }
    }

    /// Maps voltage (10V-15V) to gauge arc (0.15-0.85)
    var gaugeProgress: Double {
        let normalized = (reading.voltage - 10.0) / 5.0 // 0.0 to 1.0
        let clamped = min(max(normalized, 0), 1)
        return 0.15 + clamped * 0.7
    }

    var gaugeColor: Color {
        switch reading.status {
        case .full: return .green
        case .warning: return .yellow
        case .critical: return .orange
        case .danger: return .red
        case .unknown: return .gray
        }
    }
}

// MARK: - Detail Card

struct DetailCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Status Banner

struct StatusBanner: View {
    let status: BatteryStatus

    var body: some View {
        HStack {
            Image(systemName: status.systemImage)
            VStack(alignment: .leading) {
                Text(status.rawValue)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(status.advice)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(bannerColor.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .foregroundStyle(bannerColor)
    }

    var bannerColor: Color {
        switch status {
        case .full: return .green
        case .warning: return .yellow
        case .critical: return .orange
        case .danger: return .red
        case .unknown: return .gray
        }
    }
}

// MARK: - Voltage Chart

struct VoltageChartView: View {
    let readings: [BM6Reading]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Voltage History")
                .font(.subheadline)
                .fontWeight(.semibold)

            // Simple line chart using Canvas
            GeometryReader { geo in
                Canvas { context, size in
                    guard readings.count > 1 else { return }

                    let minV = max((readings.map(\.voltage).min() ?? 11.0) - 0.2, 10.0)
                    let maxV = min((readings.map(\.voltage).max() ?? 13.0) + 0.2, 15.0)
                    let range = maxV - minV

                    var path = Path()
                    for (i, reading) in readings.enumerated() {
                        let x = CGFloat(i) / CGFloat(readings.count - 1) * size.width
                        let y = (1 - (reading.voltage - minV) / range) * size.height
                        if i == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }

                    context.stroke(path, with: .color(.green), lineWidth: 2)

                    // Threshold lines
                    let warnY = (1 - (12.4 - minV) / range) * size.height
                    let critY = (1 - (12.0 - minV) / range) * size.height

                    if warnY > 0 && warnY < size.height {
                        var warnPath = Path()
                        warnPath.move(to: CGPoint(x: 0, y: warnY))
                        warnPath.addLine(to: CGPoint(x: size.width, y: warnY))
                        context.stroke(warnPath, with: .color(.yellow.opacity(0.5)),
                                       style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    }
                    if critY > 0 && critY < size.height {
                        var critPath = Path()
                        critPath.move(to: CGPoint(x: 0, y: critY))
                        critPath.addLine(to: CGPoint(x: size.width, y: critY))
                        context.stroke(critPath, with: .color(.red.opacity(0.5)),
                                       style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    }
                }
            }
            .frame(height: 120)

            // Legend
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Rectangle().fill(.yellow.opacity(0.5)).frame(width: 12, height: 2)
                    Text("12.4V warn").font(.caption2).foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    Rectangle().fill(.red.opacity(0.5)).frame(width: 12, height: 2)
                    Text("12.0V crit").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    @ObservedObject var ble: BLEManager

    var body: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 60)

            Image(systemName: "car.side")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No BM6 Connected")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Tap the antenna icon to scan for your BM6 battery sensor near your Tucson's jump-start terminals.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if let error = ble.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.top, 4)
            }

            Button {
                ble.startScanning()
            } label: {
                Label("Scan for BM6", systemImage: "antenna.radiowaves.left.and.right")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .padding(.top, 8)
        }
    }
}

// MARK: - Device Scanner Sheet

struct DeviceScannerSheet: View {
    @ObservedObject var ble: BLEManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if ble.isScanning {
                    HStack {
                        ProgressView()
                            .padding(.trailing, 8)
                        Text("Scanning for BM6 devices...")
                            .foregroundStyle(.secondary)
                    }
                }

                if ble.discoveredDevices.isEmpty && !ble.isScanning {
                    ContentUnavailableView(
                        "No BM6 Found",
                        systemImage: "antenna.radiowaves.left.and.right.slash",
                        description: Text("Make sure you're near the vehicle and the BM6 is installed on the jump-start terminals.")
                    )
                }

                ForEach(ble.discoveredDevices) { device in
                    Button {
                        ble.connect(to: device)
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(device.name)
                                    .font(.headline)
                                Text(device.id.prefix(8) + "...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(device.rssi) dBm")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
            .navigationTitle("BM6 Devices")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !ble.isScanning {
                        Button("Rescan") { ble.startScanning() }
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    ContentView()
}
