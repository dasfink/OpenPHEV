import SwiftUI

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
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .listRowBackground(Theme.cardBackground)
                }

                if ble.discoveredBM6Devices.isEmpty && !ble.isScanning {
                    ContentUnavailableView(
                        "No BM6 Found",
                        systemImage: "antenna.radiowaves.left.and.right.slash",
                        description: Text("Make sure you're near the vehicle and the BM6 is installed on the jump-start terminals.")
                    )
                    .listRowBackground(Color.clear)
                }

                ForEach(ble.discoveredBM6Devices) { device in
                    Button {
                        ble.connectBM6(device)
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(device.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Theme.textPrimary)
                                Text(String(device.id.prefix(8)) + "...")
                                    .font(Theme.dataFont)
                                    .foregroundStyle(Theme.textTertiary)
                            }
                            Spacer()
                            Text("\(device.rssi) dBm")
                                .font(Theme.dataFont)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .listRowBackground(Theme.cardBackground)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("BM6 Devices")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !ble.isScanning {
                        Button("Rescan") { ble.scanForBM6() }
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
