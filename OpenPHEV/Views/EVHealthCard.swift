import SwiftUI

struct EVHealthCard: View {
    let health: BMSHealthData

    var body: some View {
        VStack(spacing: 6) {
            Text("EV BATTERY")
                .font(Theme.labelFont)
                .foregroundStyle(Theme.textMuted)
                .tracking(1.5)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let sohMax = health.sohMax, let sohMin = health.sohMin {
                StatRow(label: "SOH", value: String(format: "%.1f–%.1f%%", sohMin, sohMax))
            }
            if let packV = health.packVoltage {
                StatRow(label: "Pack voltage", value: String(format: "%.1fV", packV))
            }
            if let packA = health.packCurrent {
                StatRow(label: "Pack current", value: String(format: "%.1fA", packA))
            }
            if let soc = health.soc {
                StatRow(label: "SOC", value: "\(soc)%")
            }
            if let minV = health.minCellV, let maxV = health.maxCellV {
                StatRow(label: "Cell range", value: String(format: "%.2f–%.2fV", minV, maxV))
            }
            if let delta = health.cellDelta {
                StatRow(label: "Cell delta", value: String(format: "%.3fV", delta))
            }
            if let minT = health.minTemp, let maxT = health.maxTemp {
                StatRow(label: "Temp range", value: "\(minT)–\(maxT)\u{00B0}C")
            }
        }
        .padding(Theme.cardPadding)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
    }
}
