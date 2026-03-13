import SwiftUI

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
