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
                StatRow(label: "Today avg", value: String(format: "%.2fV", stats.avgVoltage))
            } else {
                StatRow(label: "Today min", value: "--")
                StatRow(label: "Today max", value: "--")
                StatRow(label: "Average", value: "--")
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
