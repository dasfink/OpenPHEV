import XCTest
@testable import OpenPHEV

final class AlertManagerTests: XCTestCase {

    func testShouldAlertAtWarning() {
        let mgr = AlertManager()
        XCTAssertTrue(mgr.shouldAlert(voltage: 12.3))
    }

    func testNoAlertWhenHealthy() {
        let mgr = AlertManager()
        XCTAssertFalse(mgr.shouldAlert(voltage: 12.7))
    }

    func testNoRepeatAlertInCooldown() {
        let mgr = AlertManager()
        _ = mgr.shouldAlert(voltage: 12.3)
        XCTAssertFalse(mgr.shouldAlert(voltage: 12.3))
    }

    func testEscalationAlerts() {
        let mgr = AlertManager()
        _ = mgr.shouldAlert(voltage: 12.3)
        XCTAssertTrue(mgr.shouldAlert(voltage: 11.9))
    }
}
