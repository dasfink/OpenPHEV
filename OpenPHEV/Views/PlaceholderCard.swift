import SwiftUI

struct PlaceholderCard: View {
    let title: String
    let message: String
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 6) {
            Text(title.uppercased())
                .font(Theme.labelFont)
                .foregroundStyle(Theme.textMuted)
                .tracking(1.5)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let action = action {
                Button(action: action) {
                    Text(message)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textTertiary)
                }
            } else {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }
        }
        .padding(Theme.cardPadding)
        .background(Theme.cardBackgroundDashed)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                .foregroundStyle(Color(white: 0.13))
        )
    }
}
