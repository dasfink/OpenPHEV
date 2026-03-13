import Foundation
import UserNotifications

class AlertManager {

    enum AlertLevel: Int, Comparable {
        case none = 0
        case warning = 1   // < 12.4V
        case critical = 2  // < 12.0V
        case danger = 3    // < 11.6V

        static func < (lhs: AlertLevel, rhs: AlertLevel) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        static func from(voltage: Double) -> AlertLevel {
            if voltage < 11.6 { return .danger }
            if voltage < 12.0 { return .critical }
            if voltage < 12.4 { return .warning }
            return .none
        }
    }

    private var lastAlertLevel: AlertLevel = .none
    private var lastAlertTime: Date?
    private let cooldownInterval: TimeInterval = 600  // 10 minutes

    /// Returns true if an alert should fire for this voltage reading.
    func shouldAlert(voltage: Double) -> Bool {
        let level = AlertLevel.from(voltage: voltage)
        guard level != .none else {
            lastAlertLevel = .none
            lastAlertTime = nil
            return false
        }

        let isEscalation = level > lastAlertLevel
        let cooldownExpired = lastAlertTime.map { Date().timeIntervalSince($0) > cooldownInterval } ?? true

        if isEscalation || cooldownExpired {
            lastAlertLevel = level
            lastAlertTime = Date()
            return true
        }

        return false
    }

    /// Request notification permissions on first launch
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    /// Send a local notification for the given voltage
    func sendAlert(voltage: Double) {
        let level = AlertLevel.from(voltage: voltage)
        let content = UNMutableNotificationContent()
        content.sound = .default

        switch level {
        case .warning:
            content.title = "12V Battery Warning"
            content.body = String(format: "Voltage dropped to %.2fV — drive or plug in soon.", voltage)
        case .critical:
            content.title = "12V Battery Critical"
            content.body = String(format: "Voltage at %.2fV — drive or plug in immediately.", voltage)
        case .danger:
            content.title = "12V Battery Danger"
            content.body = String(format: "Voltage at %.2fV — sulfation risk, battery damage possible.", voltage)
        case .none:
            return
        }

        let request = UNNotificationRequest(
            identifier: "openphev.battery.\(level)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
