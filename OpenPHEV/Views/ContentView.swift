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
    }
}
