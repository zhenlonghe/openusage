import XCTest
@testable import OpenUsage

@MainActor
final class WidgetDataStoreRefreshTimingTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    func testAWindowThatResetIsReadAgainOnceAfterTheGrace() async {
        let clock = TestClock(start)
        let reset = start.addingTimeInterval(60)
        let (runtime, store) = makeStore(clock: clock) { _ in
            .success(self.snapshot(refreshedAt: clock.now, resetsAt: reset))
        }
        await store.refresh(providerID: runtime.provider.id, force: true)
        XCTAssertEqual(runtime.refreshCount, 1)

        clock.set(reset.addingTimeInterval(RefreshSetting.rolloverGrace - 1))
        await store.refreshResetWindows()
        XCTAssertEqual(runtime.refreshCount, 1, "read before the provider has started the new window")

        clock.set(reset.addingTimeInterval(RefreshSetting.rolloverGrace))
        await store.refreshResetWindows()
        XCTAssertEqual(runtime.refreshCount, 2, "a window that reset is read without waiting for the next pass")

        clock.set(reset.addingTimeInterval(RefreshSetting.rolloverGrace + 60))
        await store.refreshResetWindows()
        XCTAssertEqual(runtime.refreshCount, 2, "a provider still reporting the past reset is not read again")
    }

    func testAResetWindowWaitsOutAFailure() async {
        let clock = TestClock(start)
        let reset = start.addingTimeInterval(60)
        let (runtime, store) = makeStore(clock: clock) { count in
            count == 0 ? .success(self.snapshot(refreshedAt: clock.now, resetsAt: reset))
                : .failure(RefreshFailure(message: "down", kind: .refused))
        }
        await store.refresh(providerID: runtime.provider.id, force: true)
        clock.set(reset.addingTimeInterval(RefreshSetting.rolloverGrace))
        await store.refreshResetWindows()
        await store.refreshResetWindows()
        XCTAssertEqual(runtime.refreshCount, 2, "the wait after a failure holds")
        XCTAssertNotNil(store.backoffs[runtime.provider.id])
    }

    func testOpeningThePanelReadsOnlyValuesOlderThanItsMaxAge() async {
        let clock = TestClock(start)
        let (runtime, store) = makeStore(clock: clock) { _ in .success(self.snapshot(refreshedAt: clock.now, resetsAt: nil)) }
        await store.refreshAll(force: true)
        let passAt = store.lastRefreshAt

        clock.set(start.addingTimeInterval(RefreshSetting.panelOpenMaxAge - 1))
        await store.refreshForOpenedPanel()
        XCTAssertEqual(runtime.refreshCount, 1)

        clock.set(start.addingTimeInterval(RefreshSetting.panelOpenMaxAge))
        await store.refreshForOpenedPanel()
        XCTAssertEqual(runtime.refreshCount, 2)
        XCTAssertEqual(store.lastRefreshAt, passAt, "opening the panel doesn't move the next pass's countdown")
    }

    func testOldValuesDimOnlyOnceARefreshHasFailed() async {
        let clock = TestClock(start)
        let (runtime, store) = makeStore(clock: clock) { count in
            count == 0 ? .success(self.snapshot(refreshedAt: clock.now, resetsAt: nil))
                : .failure(RefreshFailure(message: "down", kind: .refused))
        }
        let id = runtime.provider.id
        await store.refresh(providerID: id, force: true)
        clock.set(start.addingTimeInterval(RefreshSetting.stalenessThreshold))
        XCTAssertFalse(store.showsOldValues(for: id), "old values waiting for their next read don't dim")

        await store.refresh(providerID: id, force: true)
        XCTAssertTrue(store.showsOldValues(for: id))
    }

    private func makeStore(
        clock: TestClock,
        answer: @escaping @MainActor (Int) -> Result<ProviderSnapshot, RefreshFailure>
    ) -> (StubRuntime, WidgetDataStore) {
        let runtime = StubRuntime(provider: Provider(id: "codex", kind: .codex), descriptors: [], answer: answer)
        let store = WidgetDataStore.forTesting([runtime], defaults: isolatedDefaults(), now: { clock.now })
        return (runtime, store)
    }

    private func snapshot(refreshedAt: Date, resetsAt: Date?) -> ProviderSnapshot {
        ProviderSnapshot(
            providerID: "codex", displayName: "Codex",
            lines: [.progress(label: "Session", used: 10, limit: 100, format: .percent, resetsAt: resetsAt)],
            refreshedAt: refreshedAt
        )
    }
}
