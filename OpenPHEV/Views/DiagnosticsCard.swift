import SwiftUI

struct DiagnosticsCard: View {
    let troubleCodes: [String]
    let isConnected: Bool
    var onScan: (() -> Void)?

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("DIAGNOSTICS")
                    .font(Theme.labelFont)
                    .foregroundStyle(Theme.textMuted)
                    .tracking(1.5)

                Spacer()

                if isConnected {
                    Button(action: { onScan?() }) {
                        Text("Scan")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.statusGood)
                    }
                }
            }

            if troubleCodes.isEmpty {
                Text(isConnected ? "No trouble codes" : "Connect Veepeak to scan")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 4)
            } else {
                ForEach(troubleCodes, id: \.self) { code in
                    HStack {
                        Text(code)
                            .font(Theme.dataFont)
                            .foregroundStyle(Theme.statusDanger)
                        Spacer()
                    }
                }
            }
        }
        .padding(Theme.cardPadding)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
    }
}
