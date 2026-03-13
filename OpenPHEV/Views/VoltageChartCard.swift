import SwiftUI
import Charts

struct VoltageChartCard: View {
    let readings: [BM6Reading]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("24 HOURS")
                .font(Theme.labelFont)
                .foregroundStyle(Theme.textMuted)
                .tracking(1.5)

            Chart {
                ForEach(readings) { reading in
                    LineMark(
                        x: .value("Time", reading.timestamp),
                        y: .value("Voltage", reading.voltage)
                    )
                    .foregroundStyle(Theme.statusGood)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                }

                RuleMark(y: .value("Warning", 12.4))
                    .foregroundStyle(Theme.statusWarn.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [4, 4]))

                RuleMark(y: .value("Critical", 12.0))
                    .foregroundStyle(Theme.statusDanger.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: 11.5...13.5)
            .frame(height: 60)
        }
        .padding(Theme.cardPadding)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
    }
}
