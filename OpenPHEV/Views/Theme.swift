import SwiftUI

enum Theme {
    // MARK: - Colors
    static let background = Color.black
    static let cardBackground = Color(white: 0.067) // #111
    static let cardBackgroundDashed = Color(white: 0.05) // #0d0d0d
    static let textPrimary = Color(white: 0.87)
    static let textSecondary = Color(white: 0.53) // #888
    static let textTertiary = Color(white: 0.33) // #555
    static let textMuted = Color(white: 0.27) // #444
    static let separator = Color(white: 0.1)

    // MARK: - Status Colors (semantic only)
    static let statusGood = Color(red: 0.29, green: 0.85, blue: 0.50)     // #4ade80
    static let statusWarn = Color(red: 0.98, green: 0.80, blue: 0.08)     // #facc15
    static let statusCritical = Color(red: 0.98, green: 0.45, blue: 0.09) // #f97316
    static let statusDanger = Color(red: 0.94, green: 0.27, blue: 0.27)   // #ef4444

    static func statusColor(for status: BatteryStatus) -> Color {
        switch status {
        case .full: return statusGood
        case .warning: return statusWarn
        case .critical: return statusCritical
        case .danger: return statusDanger
        case .unknown: return textTertiary
        }
    }

    // MARK: - Typography
    static let heroFont = Font.system(size: 56, weight: .bold, design: .monospaced)
    static let heroUnitFont = Font.system(size: 24, weight: .regular, design: .monospaced)
    static let dataFont = Font.system(size: 13, weight: .medium, design: .monospaced)
    static let labelFont = Font.system(size: 11, weight: .semibold, design: .default)
    static let metaFont = Font.system(size: 13, weight: .regular, design: .monospaced)

    // MARK: - Layout
    static let cardRadius: CGFloat = 12
    static let cardPadding: CGFloat = 16
    static let scrollSpacing: CGFloat = 12
}
