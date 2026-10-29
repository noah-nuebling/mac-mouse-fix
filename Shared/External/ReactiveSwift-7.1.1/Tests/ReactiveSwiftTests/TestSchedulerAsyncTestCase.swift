#if canImport(_Concurrency) && compiler(>=5.5.2)
import ReactiveSwift
import XCTest

// !!!: Using XCTest as only from Quick 6 are asynchronous contexts available (we're on Quick 4 at the time of writing)

@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, *)
final class TestSchedulerAsyncTestCase: XCTestCase {
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

    func test_advance_shouldRunEnqueuedActionsImmediately() async {
		var string = ""

		scheduler.schedule {
			string += "foo"
			XCTAssert(Thread.isMainThread)
		}

		scheduler.schedule {
			string += "bar"
			XCTAssert(Thread.isMainThread)
		}

		XCTAssert(string.isEmpty)

		await scheduler.advance()

		// How much dates are allowed to differ when they should be "equal."
		let dateComparisonDelta = 0.00001

		XCTAssertLessThanOrEqual(
			scheduler.currentDate.timeIntervalSince1970 - startDate.timeIntervalSince1970,
			dateComparisonDelta
		)

		XCTAssertEqual(string, "foobar")
    }

	func test_advanceByDispatchTimeInterval_shouldRunEnqueuedActionsWhenPastTheTargetDate() async {
		var string = ""

		scheduler.schedule(after: .seconds(15)) {
			string += "bar"
			XCTAssert(Thread.isMainThread)
			XCTAssertEqual(self.scheduler.currentDate, self.startDate!.addingTimeInterval(15))
		}

		scheduler.schedule(after: .seconds(5)) {
			string += "foo"
			XCTAssert(Thread.isMainThread)
			XCTAssertEqual(self.scheduler.currentDate, self.startDate!.addingTimeInterval(5))
		}

		XCTAssert(string.isEmpty)

		await scheduler.advance(by: .seconds(10))
		XCTAssertEqual(scheduler.currentDate, startDate.addingTimeInterval(10))
		XCTAssertEqual(string, "foo")

		await scheduler.advance(by: .seconds(10))
		XCTAssertEqual(scheduler.currentDate, startDate.addingTimeInterval(20))
		XCTAssertEqual(string, "foobar")
	}

	func test_advanceByTimeInterval_shouldRunEnqueuedActionsWhenPastTheTargetDate() async {
		var string = ""

		scheduler.schedule(after: .seconds(15)) {
			string += "bar"
			XCTAssert(Thread.isMainThread)
			XCTAssertEqual(self.scheduler.currentDate, self.startDate!.addingTimeInterval(15))
		}

		scheduler.schedule(after: .seconds(5)) {
			string += "foo"
			XCTAssert(Thread.isMainThread)
			XCTAssertEqual(self.scheduler.currentDate, self.startDate!.addingTimeInterval(5))
		}

		XCTAssert(string.isEmpty)

		await scheduler.advance(by: 10)
		XCTAssertEqual(scheduler.currentDate, startDate.addingTimeInterval(10))
		XCTAssertEqual(string, "foo")

		await scheduler.advance(by: 10)
		XCTAssertEqual(scheduler.currentDate, startDate.addingTimeInterval(20))
		XCTAssertEqual(string, "foobar")
	}

	func test_run_shouldRunAllEnqueuedActionsInOrder() async {
		var string = ""

		scheduler.schedule(after: .seconds(15)) {
			string += "bar"
			XCTAssert(Thread.isMainThread)
		}

		scheduler.schedule(after: .seconds(5)) {
			string += "foo"
			XCTAssert(Thread.isMainThread)
		}

		scheduler.schedule {
			string += "fuzzbuzz"
			XCTAssert(Thread.isMainThread)
		}

		XCTAssert(string.isEmpty)

		await scheduler.run()
		XCTAssertEqual(scheduler.currentDate, Date.distantFuture)
		XCTAssertEqual(string, "fuzzbuzzfoobar")
	}
}
#endif
