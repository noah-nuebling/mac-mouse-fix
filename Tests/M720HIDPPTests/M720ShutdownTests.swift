import AppKit
import XCTest
@testable import Mac_Mouse_Fix_Helper

final class M720ShutdownTests: XCTestCase {
    func testDeviceManagerExposesAsynchronousCleanupEntryPoint() {
        XCTAssertTrue(DeviceManager.responds(
            to: NSSelectorFromString("deconfigureDevicesWithCompletion:")
        ))
    }

    func testAppDelegateExposesDeferredTerminationDecision() {
        let appDelegateClass = NSClassFromString("AppDelegate") as? NSObject.Type
        XCTAssertNotNil(appDelegateClass)
        XCTAssertTrue(appDelegateClass?.instancesRespond(
            to: #selector(NSApplicationDelegate.applicationShouldTerminate(_:))
        ) == true)
    }

    func testRepeatedShutdownCallsShareOneCleanupAndCompleteEveryCallerOnce() {
        let harness = M720ShutdownHarness()
        var results: [Bool] = []

        harness.coordinator.beginShutdown { results.append($0) }
        harness.coordinator.beginShutdown { results.append($0) }

        XCTAssertEqual(harness.cleanupStarts, 1)
        XCTAssertEqual(harness.scheduler.pendingDeadlines, [3])
        XCTAssertTrue(results.isEmpty)

        harness.scheduler.advance(to: 2.999)
        harness.finishCleanup()
        harness.finishCleanup()

        XCTAssertEqual(results, [true, true])
        XCTAssertTrue(harness.scheduler.pendingDeadlines.isEmpty)

        harness.coordinator.beginShutdown { results.append($0) }
        XCTAssertEqual(results, [true, true, true])
        XCTAssertEqual(harness.cleanupStarts, 1)
    }

    func testDeadlineWinsExactlyAtThreeSecondsAndLateCleanupCannotChangeResult() {
        let harness = M720ShutdownHarness()
        var results: [Bool] = []

        harness.coordinator.beginShutdown { results.append($0) }
        harness.scheduler.advance(to: 2.999)
        XCTAssertTrue(results.isEmpty)

        harness.scheduler.advance(to: 3)
        XCTAssertEqual(results, [false])
        XCTAssertEqual(harness.coordinator.state, .finished(false))

        harness.coordinator.beginShutdown { results.append($0) }
        harness.finishCleanup()
        harness.finishCleanup()

        XCTAssertEqual(results, [false, false])
        XCTAssertEqual(harness.coordinator.state, .finished(false))
        XCTAssertEqual(harness.cleanupStarts, 1)
    }

    func testDeadlinePropagatesFenceOnceBeforeFalseCompletion() {
        let scheduler = ManualScheduler()
        var events: [String] = []
        let coordinator = M720ShutdownCoordinator(
            scheduler: scheduler,
            deadlineReached: { events.append("deadline") },
            cleanup: { _ in }
        )

        coordinator.beginShutdown { events.append("completion:\($0)") }
        scheduler.advance(to: 3)
        coordinator.beginShutdown { events.append("late:\($0)") }

        XCTAssertEqual(events, ["deadline", "completion:false", "late:false"])
    }

    func testSignalWaiterStartsCleanupOnMainExecutorAndWaitsAtMostThreeSeconds() {
        var mainBlock: (() -> Void)?
        var observedTimeout: TimeInterval?
        var cleanupStarts = 0
        let waiter = M720SignalShutdownWaiter(
            dispatchToMain: { mainBlock = $0 },
            wait: { semaphore, timeout in
                observedTimeout = timeout
                mainBlock?()
                return semaphore.wait(timeout: .now()) == .success
            }
        )

        let completed = waiter.waitForCleanup { completion in
            cleanupStarts += 1
            completion(true)
        }

        XCTAssertTrue(completed)
        XCTAssertEqual(observedTimeout, 3)
        XCTAssertEqual(cleanupStarts, 1)
    }

    func testSignalWaiterTimeoutAllowsLateCompletionWithoutReRaiseInsideTestHost() {
        var mainBlock: (() -> Void)?
        var cleanupCompletion: ((Bool) -> Void)?
        let waiter = M720SignalShutdownWaiter(
            dispatchToMain: { mainBlock = $0 },
            wait: { _, timeout in
                XCTAssertEqual(timeout, 3)
                return false
            }
        )

        let completed = waiter.waitForCleanup { cleanupCompletion = $0 }
        XCTAssertFalse(completed)

        mainBlock?()
        cleanupCompletion?(true)
        XCTAssertFalse(completed)
    }
}

private final class M720ShutdownHarness {
    let scheduler = ManualScheduler()
    private(set) var cleanupStarts = 0
    private var cleanupCompletion: (() -> Void)?

    lazy var coordinator = M720ShutdownCoordinator(
        scheduler: scheduler,
        cleanup: { [unowned self] completion in
            cleanupStarts += 1
            cleanupCompletion = completion
        }
    )

    func finishCleanup() {
        cleanupCompletion?()
    }
}
