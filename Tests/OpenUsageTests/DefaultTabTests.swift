import XCTest
@testable import OpenUsage

@MainActor
final class DefaultTabTests: XCTestCase {
    func testColdLaunchAndReopenUseTheDefaultEvenAfterAnotherTabWasSelected() {
        let defaults = isolatedDefaults()
        let popover = PopoverState()

        popover.show(dashboardTab: .priority)
        popover.show(dashboardTab: .preferred(in: defaults))
        XCTAssertEqual(popover.dashboardTab, .allUsage)

        defaults.set(DashboardTab.priority.rawValue, forKey: DashboardTab.defaultKey)
        popover.dashboardTab = .allUsage
        popover.show(dashboardTab: .preferred(in: defaults))
        XCTAssertEqual(popover.dashboardTab, .priority)
    }

    func testClosingThePanelReturnsSettingsToItsFirstTab() {
        let popover = PopoverState()
        popover.settingsTab = .alerts
        popover.reset()
        XCTAssertEqual(popover.settingsTab, .general)
    }
}
