#if canImport(_Concurrency) && compiler(>=5.5.2)
import ReactiveSwift
import XCTest

// !!!: Using XCTest as only from Quick 6 are asynchronous contexts available (we're on Quick 4 at the time of writing)

@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, *)
final class DateSchedulerAsyncTestCase: XCTestCase {
	var scheduler: TestScheduler!
	var startDate: Date!

	override func setUpWithError() throws {
		try super.setUpWithError()

		startDate = Date()
		scheduler = TestScheduler(startDate: startDate)
		XCTAssert(scheduler.currentDate == startDate)
	}

	override func tearDownWithError() throws {
		scheduler = nil
		startDate = nil

		try super.tearDownWithError()
	}

	func test_sleepFor_shouldSleepForTheDefinedIntervalBeforeReturning() async throws {
		let task = Task {
			try await scheduler.sleep(for: .seconds(5))
			XCTAssertEqual(scheduler.currentDate, startDate.addingTimeInterval(5))
		}

		XCTAssertEqual(scheduler.currentDate, startDate)
		await scheduler.advance(by: .seconds(5))

		let _ = await task.result
	}

	func test_sleepUntil_shouldSleepForTheDefinedIntervalBeforeReturning() async throws {
		let sleepDate = startDate.addingTimeInterval(5)

		let task = Task {
			try await scheduler.sleep(until: sleepDate)
			XCTAssertEqual(scheduler.currentDate, sleepDate)
		}

		XCTAssertEqual(scheduler.currentDate, startDate)
		await scheduler.advance(by: .seconds(5))

		let _ = await task.result
	}

	func test_timer_shouldSendTheCurrentDateAtTheGivenInterval() async throws {
		let expectation = self.expectation(description: "timer")
		expectation.expectedFulfillmentCount = 3

		let startDate = scheduler.currentDate
		let tick1 = startDate.addingTimeInterval(1)
		let tick2 = startDate.addingTimeInterval(2)
		let tick3 = startDate.addingTimeInterval(3)

		let dates = Atomic<[Date]>([])

		let task = Task { [dates] in
			for await date in scheduler.timer(interval: .seconds(1)) {
				XCTAssertEqual(scheduler.currentDate, date)
				dates.modify { $0.append(date) }
				expectation.fulfill()
			}
		}

		await scheduler.advance(by: .milliseconds(900))
		XCTAssertEqual(dates.value, [])

		await scheduler.advance(by: .seconds(1))
		XCTAssertEqual(dates.value, [tick1])

		await scheduler.advance()
		XCTAssertEqual(dates.value, [tick1])

		await scheduler.advance(by: .milliseconds(200))
		XCTAssertEqual(dates.value, [tick1, tick2])

		await scheduler.advance(by: .seconds(1))
		XCTAssertEqual(dates.value, [tick1, tick2, tick3])

		task.cancel() // cancel the timer

		await waitForExpectations(timeout: 0.1)
	}
}
#endif

