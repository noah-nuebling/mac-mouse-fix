import Foundation
import IOKit
import XCTest
@testable import Mac_Mouse_Fix_Helper

final class HIDPPRequestPipelineTests: XCTestCase {
    func testOnlyExactIdentityCompletesInflightRequestAndStartsNextFIFORequest() {
        let harness = RequestPipelineHarness()
        var firstResults: [Result<Data, HIDPPRequestError>] = []
        var secondResults: [Result<Data, HIDPPRequestError>] = []
        var foreignIdentities: [HIDPPRequestIdentity] = []
        harness.pipeline.onForeignResponse = { foreignIdentities.append($0) }

        harness.pipeline.perform(featureIndex: 0x0B, function: 0x2, parameters: [0x00, 0x5B]) {
            firstResults.append($0)
        }
        harness.pipeline.perform(featureIndex: 0x0C, function: 0x3, parameters: [0x00, 0x5D]) {
            secondResults.append($0)
        }
        harness.drain()

        XCTAssertEqual(harness.transport.sent.count, 1)
        let firstIdentity = harness.sentIdentity(at: 0)

        harness.injectResponse(identity: firstIdentity, reportID: 0x10)
        harness.injectResponse(identity: firstIdentity, deviceIndex: 0x01)
        harness.injectResponse(identity: .init(
            featureIndex: firstIdentity.featureIndex ^ 0x01,
            function: firstIdentity.function,
            softwareID: firstIdentity.softwareID
        ))
        harness.injectResponse(identity: .init(
            featureIndex: firstIdentity.featureIndex,
            function: firstIdentity.function ^ 0x01,
            softwareID: firstIdentity.softwareID
        ))
        let foreignIdentity = HIDPPRequestIdentity(
            featureIndex: firstIdentity.featureIndex,
            function: firstIdentity.function,
            softwareID: firstIdentity.softwareID ^ 0x01
        )
        harness.injectResponse(identity: foreignIdentity)
        harness.drain()

        XCTAssertTrue(firstResults.isEmpty)
        XCTAssertTrue(secondResults.isEmpty)
        XCTAssertEqual(harness.transport.sent.count, 1)
        XCTAssertEqual(foreignIdentities, [foreignIdentity])

        harness.injectResponse(identity: firstIdentity, parameters: [0xAA, 0xBB])
        harness.drain()

        XCTAssertEqual(firstResults, [.success(harness.paddedParameters([0xAA, 0xBB]))])
        XCTAssertTrue(secondResults.isEmpty)
        XCTAssertEqual(harness.transport.sent.count, 2)

        let secondIdentity = harness.sentIdentity(at: 1)
        harness.injectResponse(identity: secondIdentity, parameters: [0xCC], deviceIndex: 0xFF)
        harness.drain()

        XCTAssertEqual(secondResults, [.success(harness.paddedParameters([0xCC]))])
    }

    func testEventsAlwaysUseEventHookAndNeverCompleteTheRequest() {
        let harness = RequestPipelineHarness()
        var events: [HIDPPInbound] = []
        var results: [Result<Data, HIDPPRequestError>] = []
        harness.pipeline.onEvent = { events.append($0) }

        harness.injectEvent(featureIndex: 0x22, event: 0x4, parameters: [0x01])
        harness.pipeline.perform(featureIndex: 0x0B, function: 0x2, parameters: []) {
            results.append($0)
        }
        harness.drain()
        let identity = harness.sentIdentity(at: 0)
        harness.injectEvent(featureIndex: 0x22, event: 0x5, parameters: [0x02])
        harness.drain()

        XCTAssertEqual(events, [
            .event(featureIndex: 0x22, event: 0x4, parameters: harness.paddedParameters([0x01])),
            .event(featureIndex: 0x22, event: 0x5, parameters: harness.paddedParameters([0x02])),
        ])
        XCTAssertTrue(results.isEmpty)

        harness.injectResponse(identity: identity)
        harness.drain()
        XCTAssertEqual(results, [.success(harness.paddedParameters([]))])
    }

    func testSpecialErrorsRequireExactOriginalIdentity() {
        let harness = RequestPipelineHarness()
        var results: [Result<Data, HIDPPRequestError>] = []
        var foreignIdentities: [HIDPPRequestIdentity] = []
        harness.pipeline.onForeignResponse = { foreignIdentities.append($0) }
        harness.pipeline.perform(featureIndex: 0x0B, function: 0x3, parameters: []) {
            results.append($0)
        }
        harness.drain()
        let identity = harness.sentIdentity(at: 0)

        let foreignIdentity = HIDPPRequestIdentity(
            featureIndex: identity.featureIndex ^ 0x01,
            function: identity.function ^ 0x01,
            softwareID: identity.softwareID ^ 0x01
        )
        harness.injectError(identity: foreignIdentity, code: 0x08)
        harness.injectError(identity: .init(
            featureIndex: identity.featureIndex ^ 0x01,
            function: identity.function,
            softwareID: identity.softwareID
        ), code: 0x08)
        harness.injectError(identity: .init(
            featureIndex: identity.featureIndex,
            function: identity.function ^ 0x01,
            softwareID: identity.softwareID
        ), code: 0x08)
        harness.drain()

        XCTAssertTrue(results.isEmpty)
        XCTAssertEqual(foreignIdentities, [foreignIdentity])

        harness.injectError(identity: identity, code: 0x08)
        harness.drain()

        XCTAssertEqual(results, [.failure(.device(code: 0x08))])
    }

    func testSolicitedResponsesAndErrorsWithoutAnActiveAttemptAreForeign() {
        let harness = RequestPipelineHarness()
        var foreignIdentities: [HIDPPRequestIdentity] = []
        harness.pipeline.onForeignResponse = { foreignIdentities.append($0) }
        let responseIdentity = HIDPPRequestIdentity(featureIndex: 0x0B, function: 0x2, softwareID: 0x8)
        let errorIdentity = HIDPPRequestIdentity(featureIndex: 0x0C, function: 0x3, softwareID: 0x9)

        harness.injectResponse(identity: responseIdentity)
        harness.injectError(identity: errorIdentity, code: 0x08)
        harness.drain()

        XCTAssertEqual(foreignIdentities, [responseIdentity, errorIdentity])
    }

    func testMalformedLengthAndSoftwareIDAreTerminalOnlyWhileAnAttemptIsActive() {
        let harness = RequestPipelineHarness(automaticallyCompletesSends: false)
        var firstResults: [Result<Data, HIDPPRequestError>] = []
        var secondResults: [Result<Data, HIDPPRequestError>] = []

        harness.injectMalformedLength()
        harness.injectInvalidSoftwareIDError()
        harness.drain()

        harness.pipeline.perform(featureIndex: 0x0B, function: 0x2, parameters: []) {
            firstResults.append($0)
        }
        harness.drain()
        harness.injectMalformedLength()
        harness.drain()

        XCTAssertEqual(firstResults, [.failure(.malformed(.invalidLength(19)))])

        harness.injectInvalidSoftwareIDError()
        harness.pipeline.perform(featureIndex: 0x0C, function: 0x3, parameters: []) {
            secondResults.append($0)
        }
        harness.drain()
        harness.injectInvalidSoftwareIDError()
        harness.drain()

        XCTAssertEqual(secondResults, [.failure(.malformed(.invalidSoftwareID(0)))])
    }

    func testInlineZeroTimeoutCompletesExactlyOnceAndPreservesFIFOWithoutNestedSend() {
        let transport = ScriptedHIDPPTransport()
        let scheduler = InlineZeroScheduler()
        let stateQueue = DispatchQueue(label: "HIDPPRequestPipelineTests.inlineZero")
        let pipeline = HIDPPRequestPipeline(
            transport: transport,
            scheduler: scheduler,
            retryPolicy: HIDPPRetryPolicy(timeout: 0, busyDelays: [], timeoutDelays: []),
            stateQueue: stateQueue
        )
        var completionOrder: [String] = []
        var results: [Result<Data, HIDPPRequestError>] = []
        var sentCountsAtCompletion: [Int] = []

        pipeline.perform(featureIndex: 0x0B, function: 0x2, parameters: []) {
            completionOrder.append("first")
            results.append($0)
            sentCountsAtCompletion.append(transport.sent.count)
        }
        pipeline.perform(featureIndex: 0x0C, function: 0x3, parameters: []) {
            completionOrder.append("second")
            results.append($0)
            sentCountsAtCompletion.append(transport.sent.count)
        }
        stateQueue.sync {}

        XCTAssertEqual(completionOrder, ["first", "second"])
        XCTAssertEqual(results, [
            .failure(.timeout),
            .failure(.timeout),
        ])
        XCTAssertEqual(sentCountsAtCompletion, [1, 2])
        XCTAssertEqual(transport.sent.map { [UInt8]($0)[2] }, [0x0B, 0x0C])
        XCTAssertEqual(transport.maximumSendCallDepth, 1)
        XCTAssertEqual(scheduler.scheduledDelays, [0, 0])
        XCTAssertTrue(scheduler.cancellations.allSatisfy(\.isCancelled))
    }

    func testTimeoutRetriesOnceAtExactTimesThenTerminates() {
        let harness = RequestPipelineHarness()
        var results: [Result<Data, HIDPPRequestError>] = []
        harness.pipeline.perform(featureIndex: 0x0B, function: 0x2, parameters: []) {
            results.append($0)
        }
        harness.drain()

        harness.assertSchedulerNow(0)
        XCTAssertEqual(harness.transport.sent.count, 1)
        XCTAssertEqual(harness.sentIdentity(at: 0).softwareID, 0x8)
        harness.assertOnlyPendingDeadline(1.0)

        harness.advance(by: 0.999)
        XCTAssertEqual(harness.transport.sent.count, 1)
        XCTAssertTrue(results.isEmpty)

        harness.advance(by: 0.001)
        harness.assertSchedulerNow(1.0)
        XCTAssertEqual(harness.transport.sent.count, 1)
        XCTAssertTrue(results.isEmpty)
        harness.assertOnlyPendingDeadline(1.20)

        harness.advance(by: 0.199)
        XCTAssertEqual(harness.transport.sent.count, 1)

        harness.advance(by: 0.001)
        harness.assertSchedulerNow(1.20)
        XCTAssertEqual(harness.transport.sent.count, 2)
        XCTAssertEqual(harness.sentIdentity(at: 1).softwareID, 0x9)
        harness.assertOnlyPendingDeadline(2.20)

        harness.advance(to: 2.199)
        XCTAssertTrue(results.isEmpty)
        harness.advance(to: 2.20)

        harness.assertSchedulerNow(2.20)
        XCTAssertEqual(results, [.failure(.timeout)])
        XCTAssertEqual(harness.transport.sent.count, 2)
        harness.assertNoPendingDeadlines()
    }

    func testTimeoutStartsAtSuccessfulSendCompletion() {
        let harness = RequestPipelineHarness(automaticallyCompletesSends: false)
        var results: [Result<Data, HIDPPRequestError>] = []
        harness.pipeline.perform(featureIndex: 0x0B, function: 0x2, parameters: []) {
            results.append($0)
        }
        harness.drain()

        XCTAssertEqual(harness.transport.sent.count, 1)
        XCTAssertEqual(harness.transport.pendingSendCompletionCount, 1)
        harness.assertNoPendingDeadlines()

        harness.advance(by: 10)
        XCTAssertTrue(results.isEmpty)
        harness.transport.completeNextSend()
        harness.drain()

        harness.assertOnlyPendingDeadline(11)
        harness.advance(by: 0.999)
        XCTAssertTrue(results.isEmpty)
        harness.advance(by: 0.001)

        XCTAssertTrue(results.isEmpty)
        XCTAssertEqual(harness.transport.sent.count, 1)
        harness.assertOnlyPendingDeadline(11.20)
    }

    func testBusyRetriesAtFiftyAndTwoHundredMillisecondsThenTerminates() {
        let harness = RequestPipelineHarness()
        var results: [Result<Data, HIDPPRequestError>] = []
        harness.pipeline.perform(featureIndex: 0x0B, function: 0x2, parameters: []) {
            results.append($0)
        }
        harness.drain()

        harness.injectError(identity: harness.sentIdentity(at: 0), code: 0x07)
        harness.drain()
        harness.assertOnlyPendingDeadline(0.05)

        harness.advance(by: 0.049)
        XCTAssertEqual(harness.transport.sent.count, 1)
        harness.advance(by: 0.001)
        harness.assertSchedulerNow(0.05)
        XCTAssertEqual(harness.transport.sent.count, 2)

        harness.injectError(identity: harness.sentIdentity(at: 1), code: 0x07)
        harness.drain()
        harness.assertOnlyPendingDeadline(0.25)

        harness.advance(by: 0.199)
        XCTAssertEqual(harness.transport.sent.count, 2)
        harness.advance(by: 0.001)
        harness.assertSchedulerNow(0.25)
        XCTAssertEqual(harness.transport.sent.count, 3)

        harness.injectError(identity: harness.sentIdentity(at: 2), code: 0x07)
        harness.drain()

        XCTAssertEqual(results, [.failure(.device(code: 0x07))])
        XCTAssertEqual(harness.transport.sent.count, 3)
        harness.assertNoPendingDeadlines()
    }

    func testBusyRetrySynchronousSendFailurePumpsQueuedRequestWithoutNestedSend() {
        let harness = RequestPipelineHarness(retryPolicy: HIDPPRetryPolicy(
            timeout: 1,
            busyDelays: [0],
            timeoutDelays: [0.20]
        ))
        var completionOrder: [String] = []
        var results: [Result<Data, HIDPPRequestError>] = []
        var sentCountsAtCompletion: [Int] = []
        harness.pipeline.perform(featureIndex: 0x0B, function: 0x2, parameters: []) {
            completionOrder.append("first")
            results.append($0)
            sentCountsAtCompletion.append(harness.transport.sent.count)
        }
        harness.pipeline.perform(featureIndex: 0x0C, function: 0x3, parameters: []) {
            completionOrder.append("second")
            results.append($0)
            sentCountsAtCompletion.append(harness.transport.sent.count)
        }
        harness.drain()

        harness.injectError(identity: harness.sentIdentity(at: 0), code: 0x07)
        harness.drain()
        XCTAssertEqual(harness.transport.sent.count, 1)

        harness.transport.automaticSendResult = kIOReturnNotOpen
        harness.advanceToNextDeadline()

        XCTAssertEqual(completionOrder, ["first", "second"])
        XCTAssertEqual(results, [
            .failure(.transport(kIOReturnNotOpen)),
            .failure(.transport(kIOReturnNotOpen)),
        ])
        XCTAssertEqual(sentCountsAtCompletion, [2, 3])
        XCTAssertEqual(
            harness.transport.sent.indices.map { harness.sentIdentity(at: $0).featureIndex },
            [0x0B, 0x0B, 0x0C]
        )
        XCTAssertEqual(harness.transport.maximumSendCallDepth, 1)
    }

    func testTimeoutRetrySynchronousSendFailurePumpsQueuedRequestWithoutNestedSend() {
        let harness = RequestPipelineHarness()
        var completionOrder: [String] = []
        var results: [Result<Data, HIDPPRequestError>] = []
        var sentCountsAtCompletion: [Int] = []
        harness.pipeline.perform(featureIndex: 0x0B, function: 0x2, parameters: []) {
            completionOrder.append("first")
            results.append($0)
            sentCountsAtCompletion.append(harness.transport.sent.count)
        }
        harness.pipeline.perform(featureIndex: 0x0C, function: 0x3, parameters: []) {
            completionOrder.append("second")
            results.append($0)
            sentCountsAtCompletion.append(harness.transport.sent.count)
        }
        harness.drain()

        harness.advanceToNextDeadline()
        XCTAssertEqual(harness.transport.sent.count, 1)

        harness.transport.automaticSendResult = kIOReturnNotOpen
        harness.advanceToNextDeadline()

        XCTAssertEqual(completionOrder, ["first", "second"])
        XCTAssertEqual(results, [
            .failure(.transport(kIOReturnNotOpen)),
            .failure(.transport(kIOReturnNotOpen)),
        ])
        XCTAssertEqual(sentCountsAtCompletion, [2, 3])
        XCTAssertEqual(
            harness.transport.sent.indices.map { harness.sentIdentity(at: $0).featureIndex },
            [0x0B, 0x0B, 0x0C]
        )
        XCTAssertEqual(harness.transport.maximumSendCallDepth, 1)
    }

    func testBusyAndTimeoutRetryBudgetsRemainIndependentWhenInterleaved() {
        let harness = RequestPipelineHarness()
        var results: [Result<Data, HIDPPRequestError>] = []
        harness.pipeline.perform(featureIndex: 0x0B, function: 0x2, parameters: []) {
            results.append($0)
        }
        harness.drain()

        harness.injectError(identity: harness.sentIdentity(at: 0), code: 0x07)
        harness.drain()
        harness.assertOnlyPendingDeadline(0.05)

        harness.advance(to: 0.05)
        XCTAssertEqual(harness.transport.sent.count, 2)
        harness.assertOnlyPendingDeadline(1.05)

        harness.advance(to: 1.05)
        XCTAssertTrue(results.isEmpty)
        XCTAssertEqual(harness.transport.sent.count, 2)
        harness.assertOnlyPendingDeadline(1.25)

        harness.advance(to: 1.25)
        XCTAssertEqual(harness.transport.sent.count, 3)
        harness.injectError(identity: harness.sentIdentity(at: 2), code: 0x07)
        harness.drain()
        harness.assertOnlyPendingDeadline(1.45)

        harness.advance(to: 1.449)
        XCTAssertEqual(harness.transport.sent.count, 3)
        harness.advance(to: 1.45)
        XCTAssertEqual(harness.transport.sent.count, 4)
        harness.assertOnlyPendingDeadline(2.45)

        harness.advance(to: 2.45)

        XCTAssertEqual(results, [.failure(.timeout)])
        XCTAssertEqual(
            harness.transport.sent.indices.map { harness.sentIdentity(at: $0).softwareID },
            [0x8, 0x9, 0xA, 0xB]
        )
        harness.assertNoPendingDeadlines()
    }

    func testTransportSendFailureWinsAndStartsTheQueuedRequest() {
        let harness = RequestPipelineHarness(automaticallyCompletesSends: false)
        var firstResults: [Result<Data, HIDPPRequestError>] = []
        var secondResults: [Result<Data, HIDPPRequestError>] = []
        var foreignIdentities: [HIDPPRequestIdentity] = []
        harness.pipeline.onForeignResponse = { foreignIdentities.append($0) }
        harness.pipeline.perform(featureIndex: 0x0B, function: 0x2, parameters: []) {
            firstResults.append($0)
        }
        harness.pipeline.perform(featureIndex: 0x0C, function: 0x3, parameters: []) {
            secondResults.append($0)
        }
        harness.drain()
        let failedIdentity = harness.sentIdentity(at: 0)

        harness.transport.completeNextSend(with: kIOReturnNotOpen)
        harness.drain()

        XCTAssertEqual(firstResults, [.failure(.transport(kIOReturnNotOpen))])
        XCTAssertTrue(secondResults.isEmpty)
        XCTAssertEqual(harness.transport.sent.count, 2)

        harness.injectResponse(identity: failedIdentity)
        harness.drain()
        XCTAssertEqual(firstResults.count, 1)
        XCTAssertTrue(secondResults.isEmpty)
        XCTAssertEqual(foreignIdentities, [failedIdentity])

        harness.transport.completeNextSend()
        harness.drain()
        harness.injectResponse(identity: harness.sentIdentity(at: 1))
        harness.drain()

        XCTAssertEqual(secondResults, [.success(harness.paddedParameters([]))])
    }

    func testSynchronousSendFailuresPumpLongFIFOWithoutRecursiveCompletionStack() {
        let requestCount = 64
        let harness = RequestPipelineHarness(automaticallyCompletesSends: false)
        var completionOrder: [Int] = []
        var results: [Result<Data, HIDPPRequestError>] = []
        var sentCountsAtCompletion: [Int] = []

        for index in 0..<requestCount {
            harness.pipeline.perform(
                featureIndex: 0x20 + UInt8(index),
                function: 0x1,
                parameters: []
            ) {
                completionOrder.append(index)
                results.append($0)
                sentCountsAtCompletion.append(harness.transport.sent.count)
            }
        }
        harness.drain()

        XCTAssertEqual(harness.transport.sent.count, 1)
        XCTAssertEqual(harness.transport.pendingSendCompletionCount, 1)

        harness.transport.automaticSendResult = kIOReturnNotOpen
        harness.transport.automaticallyCompletesSends = true
        harness.transport.completeNextSend(with: kIOReturnNotOpen)
        harness.drain()

        XCTAssertEqual(completionOrder, Array(0..<requestCount))
        XCTAssertEqual(
            results,
            [Result<Data, HIDPPRequestError>](
                repeating: .failure(.transport(kIOReturnNotOpen)),
                count: requestCount
            )
        )
        XCTAssertEqual(sentCountsAtCompletion, Array(1...requestCount))
        XCTAssertEqual(
            harness.transport.sent.indices.map { harness.sentIdentity(at: $0).featureIndex },
            (0..<requestCount).map { 0x20 + UInt8($0) }
        )
        XCTAssertEqual(harness.transport.maximumSendCallDepth, 1)
    }

    func testExactResponseCanWinBeforeSendCompletionAndLateCompletionIsNoOp() {
        let harness = RequestPipelineHarness(automaticallyCompletesSends: false)
        var firstResults: [Result<Data, HIDPPRequestError>] = []
        var secondResults: [Result<Data, HIDPPRequestError>] = []
        harness.pipeline.perform(featureIndex: 0x0B, function: 0x2, parameters: []) {
            firstResults.append($0)
        }
        harness.pipeline.perform(featureIndex: 0x0C, function: 0x3, parameters: []) {
            secondResults.append($0)
        }
        harness.drain()

        harness.injectResponse(identity: harness.sentIdentity(at: 0), parameters: [0xAA])
        harness.drain()

        XCTAssertEqual(firstResults, [.success(harness.paddedParameters([0xAA]))])
        XCTAssertEqual(harness.transport.sent.count, 2)
        XCTAssertEqual(harness.transport.pendingSendCompletionCount, 2)

        harness.transport.completeNextSend(with: kIOReturnNotOpen)
        harness.drain()
        XCTAssertEqual(firstResults.count, 1)
        XCTAssertTrue(secondResults.isEmpty)

        harness.transport.completeNextSend()
        harness.drain()
        harness.injectResponse(identity: harness.sentIdentity(at: 1), parameters: [0xBB])
        harness.drain()

        XCTAssertEqual(secondResults, [.success(harness.paddedParameters([0xBB]))])
    }

    func testTimedOutSoftwareIDIsQuarantinedAndItsLateResponseIsForeign() {
        let harness = RequestPipelineHarness()
        var initialResults: [Result<Data, HIDPPRequestError>] = []
        var foreignIdentities: [HIDPPRequestIdentity] = []
        harness.pipeline.onForeignResponse = { foreignIdentities.append($0) }
        harness.pipeline.perform(featureIndex: 0x0B, function: 0x2, parameters: []) {
            initialResults.append($0)
        }
        harness.drain()
        let timedOutIdentity = harness.sentIdentity(at: 0)

        harness.advanceToNextDeadline()
        harness.advanceToNextDeadline()
        let retryIdentity = harness.sentIdentity(at: 1)
        XCTAssertEqual(retryIdentity.softwareID, 0x9)

        harness.injectResponse(identity: timedOutIdentity, parameters: [0xAA])
        harness.drain()
        XCTAssertTrue(initialResults.isEmpty)
        XCTAssertEqual(foreignIdentities, [timedOutIdentity])

        harness.injectResponse(identity: retryIdentity, parameters: [0xBB])
        harness.drain()
        XCTAssertEqual(initialResults, [.success(harness.paddedParameters([0xBB]))])

        var laterSoftwareIDs: [UInt8] = []
        for index in 0..<7 {
            var results: [Result<Data, HIDPPRequestError>] = []
            harness.pipeline.perform(featureIndex: 0x20 + UInt8(index), function: 0x1, parameters: []) {
                results.append($0)
            }
            harness.drain()
            let identity = harness.sentIdentity(at: harness.transport.sent.count - 1)
            laterSoftwareIDs.append(identity.softwareID)
            harness.injectResponse(identity: identity)
            harness.drain()
            XCTAssertEqual(results, [.success(harness.paddedParameters([]))])
        }

        XCTAssertEqual(laterSoftwareIDs, [0xA, 0xB, 0xC, 0xD, 0xE, 0xF, 0x9])
    }

    func testBusyRetryKeepsQueuedRequestSingleFlightAndDoesNotQuarantineItsID() {
        let harness = RequestPipelineHarness()
        var firstResults: [Result<Data, HIDPPRequestError>] = []
        var secondResults: [Result<Data, HIDPPRequestError>] = []
        harness.pipeline.perform(featureIndex: 0x0B, function: 0x2, parameters: []) {
            firstResults.append($0)
        }
        harness.pipeline.perform(featureIndex: 0x0C, function: 0x3, parameters: []) {
            secondResults.append($0)
        }
        harness.drain()

        harness.injectError(identity: harness.sentIdentity(at: 0), code: 0x07)
        harness.drain()
        XCTAssertEqual(harness.transport.sent.count, 1)

        harness.advanceToNextDeadline()
        XCTAssertEqual(harness.transport.sent.count, 2)
        XCTAssertEqual(harness.sentIdentity(at: 1).softwareID, 0x9)
        XCTAssertTrue(secondResults.isEmpty)

        harness.injectResponse(identity: harness.sentIdentity(at: 1))
        harness.drain()
        XCTAssertEqual(firstResults, [.success(harness.paddedParameters([]))])
        XCTAssertEqual(harness.transport.sent.count, 3)

        var laterSoftwareIDs = [harness.sentIdentity(at: 2).softwareID]
        harness.injectResponse(identity: harness.sentIdentity(at: 2))
        harness.drain()
        XCTAssertEqual(secondResults, [.success(harness.paddedParameters([]))])

        for index in 0..<6 {
            var results: [Result<Data, HIDPPRequestError>] = []
            harness.pipeline.perform(featureIndex: 0x60 + UInt8(index), function: 0x1, parameters: []) {
                results.append($0)
            }
            harness.drain()
            let identity = harness.sentIdentity(at: harness.transport.sent.count - 1)
            laterSoftwareIDs.append(identity.softwareID)
            harness.injectResponse(identity: identity)
            harness.drain()
            XCTAssertEqual(results, [.success(harness.paddedParameters([]))])
        }

        XCTAssertEqual(laterSoftwareIDs, [0xA, 0xB, 0xC, 0xD, 0xE, 0xF, 0x8])
    }

    func testEightQuarantinedSoftwareIDsFailWithoutSendingAnotherFrame() {
        let harness = RequestPipelineHarness()
        var timeoutResults: [Result<Data, HIDPPRequestError>] = []

        for index in 0..<4 {
            harness.pipeline.perform(featureIndex: 0x30 + UInt8(index), function: 0x1, parameters: []) {
                timeoutResults.append($0)
            }
            harness.drain()
            harness.advanceToNextDeadline()
            harness.advanceToNextDeadline()
            harness.advanceToNextDeadline()
            XCTAssertEqual(timeoutResults.count, index + 1)
            XCTAssertEqual(timeoutResults.last, .failure(.timeout))
        }

        XCTAssertEqual(harness.transport.sent.count, 8)
        XCTAssertEqual(
            harness.transport.sent.indices.map { harness.sentIdentity(at: $0).softwareID },
            [0x8, 0x9, 0xA, 0xB, 0xC, 0xD, 0xE, 0xF]
        )

        var exhaustedResults: [Result<Data, HIDPPRequestError>] = []
        harness.pipeline.perform(featureIndex: 0x40, function: 0x1, parameters: []) {
            exhaustedResults.append($0)
        }
        harness.drain()

        XCTAssertEqual(exhaustedResults, [.failure(.softwareIDsExhausted)])
        XCTAssertEqual(harness.transport.sent.count, 8)
    }

    func testSoftwareIDExhaustionPumpsQueuedRequestsWithoutRecursiveCompletionStack() {
        let harness = RequestPipelineHarness()
        var timeoutResults: [Result<Data, HIDPPRequestError>] = []

        for index in 0..<3 {
            harness.pipeline.perform(featureIndex: 0x60 + UInt8(index), function: 0x1, parameters: []) {
                timeoutResults.append($0)
            }
            harness.drain()
            harness.advanceToNextDeadline()
            harness.advanceToNextDeadline()
            harness.advanceToNextDeadline()
        }

        var finalTimeoutResults: [Result<Data, HIDPPRequestError>] = []
        harness.pipeline.perform(featureIndex: 0x70, function: 0x1, parameters: []) {
            finalTimeoutResults.append($0)
        }
        harness.drain()
        harness.advanceToNextDeadline()
        harness.advanceToNextDeadline()

        let requestCount = 64
        var completionOrder: [Int] = []
        var exhaustedResults: [Result<Data, HIDPPRequestError>] = []
        var sentCountsAtCompletion: [Int] = []
        var completionStackDepths: [Int] = []
        for index in 0..<requestCount {
            harness.pipeline.perform(featureIndex: 0x80 + UInt8(index), function: 0x1, parameters: []) {
                completionOrder.append(index)
                exhaustedResults.append($0)
                sentCountsAtCompletion.append(harness.transport.sent.count)
                completionStackDepths.append(Thread.callStackReturnAddresses.count)
            }
        }
        harness.drain()
        XCTAssertEqual(harness.transport.sent.count, 8)

        harness.advanceToNextDeadline()

        XCTAssertEqual(timeoutResults, [Result<Data, HIDPPRequestError>](
            repeating: .failure(.timeout),
            count: 3
        ))
        XCTAssertEqual(finalTimeoutResults, [.failure(.timeout)])
        XCTAssertEqual(completionOrder, Array(0..<requestCount))
        XCTAssertEqual(exhaustedResults, [Result<Data, HIDPPRequestError>](
            repeating: .failure(.softwareIDsExhausted),
            count: requestCount
        ))
        XCTAssertEqual(sentCountsAtCompletion, [Int](repeating: 8, count: requestCount))
        XCTAssertEqual(harness.transport.sent.count, 8)

        guard let minimumDepth = completionStackDepths.min(),
              let maximumDepth = completionStackDepths.max()
        else {
            XCTFail("Expected exhaustion completion stack samples")
            return
        }
        XCTAssertLessThanOrEqual(
            maximumDepth - minimumDepth,
            4,
            "Exhaustion completion stack grew recursively: \(minimumDepth)...\(maximumDepth)"
        )
    }

    func testBeginNewLifecycleInvalidatesRetryWaitAndPendingThenClearsQuarantine() {
        let harness = RequestPipelineHarness()
        var activeResults: [Result<Data, HIDPPRequestError>] = []
        var pendingResults: [Result<Data, HIDPPRequestError>] = []
        var completionOrder: [String] = []
        harness.pipeline.perform(featureIndex: 0x0B, function: 0x2, parameters: []) {
            activeResults.append($0)
            completionOrder.append("active")
        }
        harness.pipeline.perform(featureIndex: 0x0C, function: 0x3, parameters: []) {
            pendingResults.append($0)
            completionOrder.append("pending")
        }
        harness.drain()
        XCTAssertEqual(harness.sentIdentity(at: 0).softwareID, 0x8)

        harness.advanceToNextDeadline()
        harness.injectMalformedLength()
        harness.injectInvalidSoftwareIDError()
        harness.drain()
        XCTAssertTrue(activeResults.isEmpty)
        XCTAssertTrue(pendingResults.isEmpty)

        harness.advanceToOnlyPendingDeadline(after: {
            harness.pipeline.beginNewLifecycle()
        })

        XCTAssertEqual(activeResults, [.failure(.invalidated)])
        XCTAssertEqual(pendingResults, [.failure(.invalidated)])
        XCTAssertEqual(completionOrder, ["active", "pending"])
        XCTAssertEqual(harness.transport.sent.count, 1)
        XCTAssertEqual(harness.transport.invalidateCallCount, 0)
        XCTAssertNotNil(harness.transport.onReport)
        harness.assertNoPendingDeadlines()

        var postLifecycleSoftwareIDs: [UInt8] = []
        for index in 0..<8 {
            var results: [Result<Data, HIDPPRequestError>] = []
            harness.pipeline.perform(featureIndex: 0x50 + UInt8(index), function: 0x1, parameters: []) {
                results.append($0)
            }
            harness.drain()
            let identity = harness.sentIdentity(at: harness.transport.sent.count - 1)
            postLifecycleSoftwareIDs.append(identity.softwareID)
            harness.injectResponse(identity: identity)
            harness.drain()
            XCTAssertEqual(results, [.success(harness.paddedParameters([]))])
        }

        XCTAssertEqual(postLifecycleSoftwareIDs, [0x9, 0xA, 0xB, 0xC, 0xD, 0xE, 0xF, 0x8])
    }

    func testBeginNewLifecycleRejectsLateSendCompletionFromInvalidatedRequest() {
        let harness = RequestPipelineHarness(automaticallyCompletesSends: false)
        var oldResults: [Result<Data, HIDPPRequestError>] = []
        var newResults: [Result<Data, HIDPPRequestError>] = []
        harness.pipeline.perform(featureIndex: 0x0B, function: 0x2, parameters: []) {
            oldResults.append($0)
        }
        harness.drain()

        harness.pipeline.beginNewLifecycle()
        harness.drain()
        XCTAssertEqual(oldResults, [.failure(.invalidated)])

        harness.pipeline.perform(featureIndex: 0x0B, function: 0x2, parameters: []) {
            newResults.append($0)
        }
        harness.drain()
        XCTAssertEqual(harness.transport.sent.count, 2)
        let newIdentity = harness.sentIdentity(at: 1)

        harness.transport.completeNextSend(with: kIOReturnNotOpen)
        harness.drain()
        XCTAssertEqual(oldResults.count, 1)
        XCTAssertTrue(newResults.isEmpty)

        harness.transport.completeNextSend()
        harness.drain()
        harness.injectResponse(identity: newIdentity)
        harness.drain()

        XCTAssertEqual(newResults, [.success(harness.paddedParameters([]))])
    }

    func testInvalidateIsPermanentIdempotentAndRejectsAlreadyCopiedCallbacks() {
        let harness = RequestPipelineHarness()
        var activeResults: [Result<Data, HIDPPRequestError>] = []
        var pendingResults: [Result<Data, HIDPPRequestError>] = []
        var futureResults: [Result<Data, HIDPPRequestError>] = []
        var revivedResults: [Result<Data, HIDPPRequestError>] = []
        var events: [HIDPPInbound] = []
        harness.pipeline.onEvent = { events.append($0) }
        harness.pipeline.perform(featureIndex: 0x0B, function: 0x2, parameters: []) {
            activeResults.append($0)
        }
        harness.pipeline.perform(featureIndex: 0x0C, function: 0x3, parameters: []) {
            pendingResults.append($0)
        }
        harness.drain()
        let copiedReportHandler = harness.transport.onReport
        let activeIdentity = harness.sentIdentity(at: 0)
        harness.advanceToOnlyPendingDeadline(after: {
            harness.pipeline.invalidate()
            harness.pipeline.invalidate()
        })

        XCTAssertEqual(activeResults, [.failure(.invalidated)])
        XCTAssertEqual(pendingResults, [.failure(.invalidated)])
        XCTAssertEqual(harness.transport.invalidateCallCount, 1)
        XCTAssertNil(harness.transport.onReport)
        harness.assertNoPendingDeadlines()

        copiedReportHandler?(Data(harness.responseBytes(identity: activeIdentity)))
        copiedReportHandler?(Data(harness.eventBytes(featureIndex: 0x22, event: 0x4, parameters: [])))
        harness.drain()
        XCTAssertEqual(activeResults.count, 1)
        XCTAssertTrue(events.isEmpty)

        harness.pipeline.perform(featureIndex: 0x0D, function: 0x4, parameters: []) {
            futureResults.append($0)
        }
        harness.pipeline.beginNewLifecycle()
        harness.pipeline.perform(featureIndex: 0x0E, function: 0x5, parameters: []) {
            revivedResults.append($0)
        }
        harness.drain()

        XCTAssertEqual(futureResults, [.failure(.invalidated)])
        XCTAssertEqual(revivedResults, [.failure(.invalidated)])
        XCTAssertEqual(harness.transport.sent.count, 1)
        XCTAssertEqual(harness.transport.invalidateCallCount, 1)
    }

    func testInvalidateCompletionWaitsForTransportDrainAndCoalescesCallers() {
        let harness = RequestPipelineHarness()
        harness.transport.automaticallyCompletesInvalidation = false
        var activeResults: [Result<Data, HIDPPRequestError>] = []
        var pendingResults: [Result<Data, HIDPPRequestError>] = []
        var completionOrder: [String] = []
        harness.pipeline.perform(featureIndex: 0x0B, function: 0x2, parameters: []) {
            activeResults.append($0)
        }
        harness.pipeline.perform(featureIndex: 0x0C, function: 0x3, parameters: []) {
            pendingResults.append($0)
        }
        harness.drain()

        harness.pipeline.invalidate { completionOrder.append("first") }
        harness.pipeline.invalidate { completionOrder.append("second") }
        harness.drain()

        XCTAssertEqual(activeResults, [.failure(.invalidated)])
        XCTAssertEqual(pendingResults, [.failure(.invalidated)])
        XCTAssertEqual(harness.transport.invalidateCallCount, 1)
        XCTAssertEqual(harness.transport.pendingInvalidationCompletionCount, 1)
        XCTAssertTrue(completionOrder.isEmpty)

        harness.transport.completeInvalidation()
        harness.drain()

        XCTAssertEqual(completionOrder, ["first", "second"])
        XCTAssertEqual(harness.transport.invalidateCallCount, 1)

        var lateDidComplete = false
        harness.stateQueue.sync {
            harness.pipeline.invalidate {
                lateDidComplete = true
                completionOrder.append("late")
            }
            XCTAssertFalse(lateDidComplete)
        }
        XCTAssertFalse(lateDidComplete)
        harness.drain()
        XCTAssertTrue(lateDidComplete)
        XCTAssertEqual(completionOrder, ["first", "second", "late"])
        XCTAssertEqual(harness.transport.invalidateCallCount, 1)
    }

    func testInvalidateFromCompletionStopsQueuedRequestBeforeItSends() {
        let harness = RequestPipelineHarness()
        var firstResults: [Result<Data, HIDPPRequestError>] = []
        var secondResults: [Result<Data, HIDPPRequestError>] = []
        harness.pipeline.perform(featureIndex: 0x0B, function: 0x2, parameters: []) {
            firstResults.append($0)
            harness.pipeline.invalidate()
        }
        harness.pipeline.perform(featureIndex: 0x0C, function: 0x3, parameters: []) {
            secondResults.append($0)
        }
        harness.drain()

        harness.injectResponse(identity: harness.sentIdentity(at: 0))
        harness.drain()

        XCTAssertEqual(firstResults, [.success(harness.paddedParameters([]))])
        XCTAssertEqual(secondResults, [.failure(.invalidated)])
        XCTAssertEqual(harness.transport.sent.count, 1)
        XCTAssertEqual(harness.transport.invalidateCallCount, 1)
    }

    func testBeginNewLifecycleFromCompletionStopsQueuedRequestBeforeItSends() {
        let harness = RequestPipelineHarness()
        var firstResults: [Result<Data, HIDPPRequestError>] = []
        var secondResults: [Result<Data, HIDPPRequestError>] = []
        var newResults: [Result<Data, HIDPPRequestError>] = []
        harness.pipeline.perform(featureIndex: 0x0B, function: 0x2, parameters: []) {
            firstResults.append($0)
            harness.pipeline.beginNewLifecycle()
        }
        harness.pipeline.perform(featureIndex: 0x0C, function: 0x3, parameters: []) {
            secondResults.append($0)
        }
        harness.drain()

        harness.injectResponse(identity: harness.sentIdentity(at: 0))
        harness.drain()

        XCTAssertEqual(firstResults, [.success(harness.paddedParameters([]))])
        XCTAssertEqual(secondResults, [.failure(.invalidated)])
        XCTAssertEqual(harness.transport.sent.count, 1)
        XCTAssertEqual(harness.transport.invalidateCallCount, 0)

        harness.pipeline.perform(featureIndex: 0x0D, function: 0x4, parameters: []) {
            newResults.append($0)
        }
        harness.drain()
        XCTAssertEqual(harness.sentIdentity(at: 1).softwareID, 0x9)
        harness.injectResponse(identity: harness.sentIdentity(at: 1))
        harness.drain()
        XCTAssertEqual(newResults, [.success(harness.paddedParameters([]))])
    }

    func testPerformSubmittedFromCompletionBeforeLifecycleBoundaryIsNotAdopted() {
        let harness = RequestPipelineHarness()
        var firstResults: [Result<Data, HIDPPRequestError>] = []
        var staleResults: [Result<Data, HIDPPRequestError>] = []
        var postLifecycleResults: [Result<Data, HIDPPRequestError>] = []
        var staleCompletionWasDeferred = false

        harness.pipeline.perform(featureIndex: 0x0B, function: 0x2, parameters: []) {
            firstResults.append($0)
            harness.pipeline.perform(featureIndex: 0x0C, function: 0x3, parameters: []) {
                staleResults.append($0)
            }
            staleCompletionWasDeferred = staleResults.isEmpty
            harness.pipeline.beginNewLifecycle()
        }
        harness.drain()

        harness.injectResponse(identity: harness.sentIdentity(at: 0))
        harness.drain()
        harness.drain()

        XCTAssertEqual(firstResults, [.success(harness.paddedParameters([]))])
        XCTAssertTrue(staleCompletionWasDeferred)
        XCTAssertEqual(staleResults, [.failure(.invalidated)])
        XCTAssertEqual(harness.transport.sent.count, 1)
        guard staleResults == [.failure(.invalidated)], harness.transport.sent.count == 1 else {
            return
        }

        harness.pipeline.perform(featureIndex: 0x0D, function: 0x4, parameters: []) {
            postLifecycleResults.append($0)
        }
        harness.drain()

        XCTAssertEqual(harness.transport.sent.count, 2)
        harness.injectResponse(identity: harness.sentIdentity(at: 1))
        harness.drain()

        XCTAssertEqual(postLifecycleResults, [.success(harness.paddedParameters([]))])
        XCTAssertEqual(staleResults, [.failure(.invalidated)])
    }

    func testPerformSubmittedFromEventBeforeLifecycleBoundaryIsNotAdopted() {
        let harness = RequestPipelineHarness()
        var events: [HIDPPInbound] = []
        var staleResults: [Result<Data, HIDPPRequestError>] = []
        var postLifecycleResults: [Result<Data, HIDPPRequestError>] = []
        var staleCompletionWasDeferred = false
        harness.pipeline.onEvent = { event in
            events.append(event)
            harness.pipeline.perform(featureIndex: 0x0C, function: 0x3, parameters: []) {
                staleResults.append($0)
            }
            staleCompletionWasDeferred = staleResults.isEmpty
            harness.pipeline.beginNewLifecycle()
        }

        harness.injectEvent(featureIndex: 0x22, event: 0x4, parameters: [0xAA])
        harness.drain()
        harness.drain()

        XCTAssertEqual(events, [
            .event(featureIndex: 0x22, event: 0x4, parameters: harness.paddedParameters([0xAA])),
        ])
        XCTAssertTrue(staleCompletionWasDeferred)
        XCTAssertEqual(staleResults, [.failure(.invalidated)])
        XCTAssertTrue(harness.transport.sent.isEmpty)
        guard staleResults == [.failure(.invalidated)], harness.transport.sent.isEmpty else {
            return
        }

        harness.pipeline.perform(featureIndex: 0x0D, function: 0x4, parameters: []) {
            postLifecycleResults.append($0)
        }
        harness.drain()

        XCTAssertEqual(harness.transport.sent.count, 1)
        harness.injectResponse(identity: harness.sentIdentity(at: 0))
        harness.drain()

        XCTAssertEqual(postLifecycleResults, [.success(harness.paddedParameters([]))])
        XCTAssertEqual(staleResults, [.failure(.invalidated)])
    }

    func testAttemptTokenRejectsOldSendFailureAfterSoftwareIDWrapWithinOneRequest() {
        let policy = HIDPPRetryPolicy(
            timeout: 1,
            busyDelays: [TimeInterval](repeating: 0, count: 8),
            timeoutDelays: []
        )
        let harness = RequestPipelineHarness(
            automaticallyCompletesSends: false,
            retryPolicy: policy
        )
        var results: [Result<Data, HIDPPRequestError>] = []
        harness.pipeline.perform(featureIndex: 0x0B, function: 0x2, parameters: []) {
            results.append($0)
        }
        harness.drain()

        for index in 0..<8 {
            let identity = harness.sentIdentity(at: index)
            harness.injectError(identity: identity, code: 0x07)
            harness.drain()
            harness.advanceToNextDeadline()
        }

        XCTAssertEqual(
            harness.transport.sent.indices.map { harness.sentIdentity(at: $0).softwareID },
            [0x8, 0x9, 0xA, 0xB, 0xC, 0xD, 0xE, 0xF, 0x8]
        )
        XCTAssertTrue(results.isEmpty)

        harness.transport.completeNextSend(with: kIOReturnNotOpen)
        harness.drain()

        XCTAssertTrue(results.isEmpty)
        harness.injectResponse(identity: harness.sentIdentity(at: 8), parameters: [0xAA])
        harness.drain()
        XCTAssertEqual(results, [.success(harness.paddedParameters([0xAA]))])
    }
}

private final class InlineZeroScheduler: HIDPPScheduler {
    let now: TimeInterval = 0
    private(set) var scheduledDelays: [TimeInterval] = []
    private(set) var cancellations: [InlineZeroCancellation] = []

    @discardableResult
    func schedule(
        after delay: TimeInterval,
        _ block: @escaping () -> Void
    ) -> HIDPPCancellation {
        precondition(delay == 0)
        let cancellation = InlineZeroCancellation()
        scheduledDelays.append(delay)
        cancellations.append(cancellation)
        block()
        return cancellation
    }
}

private final class InlineZeroCancellation: HIDPPCancellation {
    private(set) var isCancelled = false

    func cancel() {
        isCancelled = true
    }
}

private final class RequestPipelineHarness {
    let transport = ScriptedHIDPPTransport()
    let scheduler = ManualScheduler()
    let stateQueue = DispatchQueue(label: "HIDPPRequestPipelineTests.state")
    let pipeline: HIDPPRequestPipeline

    init(
        automaticallyCompletesSends: Bool = true,
        retryPolicy: HIDPPRetryPolicy = .m720
    ) {
        transport.automaticallyCompletesSends = automaticallyCompletesSends
        pipeline = HIDPPRequestPipeline(
            transport: transport,
            scheduler: scheduler,
            retryPolicy: retryPolicy,
            stateQueue: stateQueue
        )
    }

    func drain() {
        stateQueue.sync {}
    }

    func advance(by interval: TimeInterval) {
        stateQueue.sync {
            scheduler.advance(by: interval)
        }
        drain()
    }

    func advance(to time: TimeInterval) {
        stateQueue.sync {
            scheduler.advance(to: time)
        }
        drain()
    }

    func advanceToNextDeadline(
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let didAdvance = stateQueue.sync {
            guard let deadline = scheduler.pendingDeadlines.first else { return false }
            scheduler.advance(to: deadline)
            return true
        }
        guard didAdvance else {
            XCTFail("Expected a pending scheduler deadline", file: file, line: line)
            return
        }
        drain()
    }

    func advanceToOnlyPendingDeadline(
        after stateChange: () -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var pendingCount = 0
        let didAdvance = stateQueue.sync {
            let pendingDeadlines = scheduler.pendingDeadlines
            pendingCount = pendingDeadlines.count
            guard let deadline = pendingDeadlines.first, pendingDeadlines.count == 1 else {
                return false
            }
            stateChange()
            scheduler.advance(to: deadline)
            return true
        }
        XCTAssertEqual(pendingCount, 1, file: file, line: line)
        guard didAdvance else { return }
        drain()
    }

    func assertSchedulerNow(
        _ expected: TimeInterval,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let now = stateQueue.sync { scheduler.now }
        XCTAssertEqual(now, expected, accuracy: 0.000_001, file: file, line: line)
    }

    func assertNoPendingDeadlines(
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let pendingDeadlines = stateQueue.sync { scheduler.pendingDeadlines }
        XCTAssertTrue(pendingDeadlines.isEmpty, file: file, line: line)
    }

    func assertOnlyPendingDeadline(
        _ expected: TimeInterval,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let pendingDeadlines = stateQueue.sync { scheduler.pendingDeadlines }
        XCTAssertEqual(pendingDeadlines.count, 1, file: file, line: line)
        guard let deadline = pendingDeadlines.first else { return }
        XCTAssertEqual(deadline, expected, accuracy: 0.000_001, file: file, line: line)
    }

    func sentIdentity(at index: Int) -> HIDPPRequestIdentity {
        let bytes = [UInt8](transport.sent[index])
        return HIDPPRequestIdentity(
            featureIndex: bytes[2],
            function: bytes[3] >> 4,
            softwareID: bytes[3] & 0x0F
        )
    }

    func injectResponse(
        identity: HIDPPRequestIdentity,
        parameters: [UInt8] = [],
        reportID: UInt8 = 0x11,
        deviceIndex: UInt8 = 0x00
    ) {
        transport.inject(responseBytes(
            identity: identity,
            parameters: parameters,
            reportID: reportID,
            deviceIndex: deviceIndex
        ))
    }

    func injectEvent(featureIndex: UInt8, event: UInt8, parameters: [UInt8]) {
        transport.inject(eventBytes(featureIndex: featureIndex, event: event, parameters: parameters))
    }

    func injectError(identity: HIDPPRequestIdentity, code: UInt8) {
        transport.inject([
            0x11,
            0x00,
            0xFF,
            identity.featureIndex,
            (identity.function << 4) | identity.softwareID,
            code,
        ] + [UInt8](repeating: 0, count: 14))
    }

    func injectMalformedLength() {
        transport.inject([UInt8](repeating: 0, count: 19))
    }

    func injectInvalidSoftwareIDError() {
        injectError(
            identity: .init(featureIndex: 0x0B, function: 0x2, softwareID: 0),
            code: 0x08
        )
    }

    func paddedParameters(_ parameters: [UInt8]) -> Data {
        Data(parameters + [UInt8](repeating: 0, count: 16 - parameters.count))
    }

    func responseBytes(
        identity: HIDPPRequestIdentity,
        parameters: [UInt8] = [],
        reportID: UInt8 = 0x11,
        deviceIndex: UInt8 = 0x00
    ) -> [UInt8] {
        precondition(parameters.count <= 16)
        return [
            reportID,
            deviceIndex,
            identity.featureIndex,
            (identity.function << 4) | identity.softwareID,
        ] + parameters + [UInt8](repeating: 0, count: 16 - parameters.count)
    }

    func eventBytes(featureIndex: UInt8, event: UInt8, parameters: [UInt8]) -> [UInt8] {
        precondition(event <= 0x0F)
        precondition(parameters.count <= 16)
        return [
            0x11,
            0x00,
            featureIndex,
            event << 4,
        ] + parameters + [UInt8](repeating: 0, count: 16 - parameters.count)
    }
}
