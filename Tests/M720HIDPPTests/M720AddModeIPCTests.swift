import XCTest
@testable import Mac_Mouse_Fix_Helper

final class M720AddModeIPCTests: XCTestCase {
    private let requestID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
    private let deviceToken = UUID(uuidString: "20000000-0000-0000-0000-000000000002")!

    func testMessageNamesAreStable() {
        XCTAssertEqual(M720IPCMessage.prepareAddMode, "prepareAddMode")
        XCTAssertEqual(M720IPCMessage.preparationResult, "addModePreparationResult")
        XCTAssertEqual(M720IPCMessage.cancelPreparation, "cancelAddModePreparation")
        XCTAssertEqual(M720IPCMessage.renewLease, "renewAddModeLease")
        XCTAssertEqual(M720IPCMessage.finishAddMode, "finishAddMode")
        XCTAssertEqual(M720IPCMessage.addModeStateChanged, "addModeStateChanged")
        XCTAssertEqual(M720IPCMessage.retryCapture, "retryM720Capture")
        XCTAssertEqual(M720IPCMessage.captureStateChanged, "m720CaptureStateChanged")
        XCTAssertEqual(M720IPCMessage.getCaptureStates, "getM720CaptureStates")
        XCTAssertEqual(M720IPCMessage.getDiagnosticState, "getM720DiagnosticState")
    }

    func testRequestIDPayloadRoundTripsAndRejectsMalformedRootFieldAndUUID() throws {
        let value = M720IPCRequest(requestID: requestID)
        XCTAssertEqual(try M720IPCRequest.decode(value.payload), value)

        assertProtocolFailures(M720IPCRequest.decode, payloads: [
            nil,
            "not-a-dictionary" as NSString,
            [:] as NSDictionary,
            ["requestID": requestID] as NSDictionary,
            ["requestID": 7] as NSDictionary,
            ["requestID": "not-a-uuid"] as NSDictionary,
            ["requestID": requestID.uuidString, "extra": true] as NSDictionary,
        ])
    }

    func testRetryPayloadRoundTripsAndRejectsMalformedTokens() throws {
        let value = M720RetryCaptureRequest(requestID: requestID, deviceToken: deviceToken)
        XCTAssertEqual(try M720RetryCaptureRequest.decode(value.payload), value)

        assertProtocolFailures(M720RetryCaptureRequest.decode, payloads: [
            nil,
            [] as NSArray,
            ["requestID": requestID.uuidString] as NSDictionary,
            ["requestID": requestID.uuidString, "deviceToken": 9] as NSDictionary,
            ["requestID": requestID.uuidString, "deviceToken": "bad"] as NSDictionary,
            ["requestID": 9, "deviceToken": deviceToken.uuidString] as NSDictionary,
        ])
    }

    func testAcknowledgementRoundTripsAndProtocolRejectionIsStable() throws {
        let accepted = M720IPCAcknowledgement.accepted
        XCTAssertEqual(try M720IPCAcknowledgement.decode(accepted.payload), accepted)

        let rejected = M720IPCAcknowledgement.rejected(.protocol)
        XCTAssertEqual(
            rejected.payload,
            ["accepted": false, "error": M720StableErrorCode.protocol.rawValue] as NSDictionary
        )
        XCTAssertEqual(try M720IPCAcknowledgement.decode(rejected.payload), rejected)

        assertProtocolFailures(M720IPCAcknowledgement.decode, payloads: [
            nil,
            ["accepted": 1] as NSDictionary,
            ["accepted": false] as NSDictionary,
            ["accepted": true, "error": "timeout"] as NSDictionary,
            ["accepted": false, "error": "unknown"] as NSDictionary,
        ])
    }

    func testPreparationResultsRoundTripEveryStateAndRejectMalformedFields() throws {
        let fixtures: [M720PreparationResult] = [
            M720PreparationResult(
                requestID: requestID,
                outcome: .ready,
                deviceTokens: [deviceToken]
            ),
            M720PreparationResult(
                requestID: requestID,
                outcome: .failed(.timeout),
                deviceTokens: [deviceToken]
            ),
            M720PreparationResult(
                requestID: requestID,
                outcome: .conflict,
                deviceTokens: [deviceToken]
            ),
            M720PreparationResult(
                requestID: requestID,
                outcome: .cancelled,
                deviceTokens: []
            ),
        ]
        for fixture in fixtures {
            XCTAssertEqual(try M720PreparationResult.decode(fixture.payload), fixture)
        }

        let valid = fixtures[1].payload.mutableCopy() as! NSMutableDictionary
        let malformed: [Any?] = [
            "root",
            replacing(valid, key: "requestID", value: 3),
            replacing(valid, key: "state", value: "unknown"),
            replacing(valid, key: "error", value: 3),
            replacing(valid, key: "error", value: "unknown"),
            replacing(valid, key: "deviceTokens", value: deviceToken.uuidString),
            replacing(valid, key: "deviceTokens", value: [deviceToken.uuidString, 4]),
            replacing(valid, key: "deviceTokens", value: [deviceToken.uuidString, deviceToken.uuidString]),
        ]
        assertProtocolFailures(M720PreparationResult.decode, payloads: malformed)
    }

    func testPreparationResultEnforcesStateErrorContract() {
        assertProtocolFailures(M720PreparationResult.decode, payloads: [
            [
                "requestID": requestID.uuidString,
                "state": M720AddModePreparationState.ready.rawValue,
                "error": M720StableErrorCode.timeout.rawValue,
                "deviceTokens": [],
            ] as NSDictionary,
            [
                "requestID": requestID.uuidString,
                "state": M720AddModePreparationState.failed.rawValue,
                "deviceTokens": [],
            ] as NSDictionary,
            [
                "requestID": requestID.uuidString,
                "state": M720AddModePreparationState.conflict.rawValue,
                "error": M720StableErrorCode.timeout.rawValue,
                "deviceTokens": [],
            ] as NSDictionary,
            [
                "requestID": requestID.uuidString,
                "state": M720AddModePreparationState.failed.rawValue,
                "error": M720StableErrorCode.conflict.rawValue,
                "deviceTokens": [],
            ] as NSDictionary,
            [
                "requestID": requestID.uuidString,
                "state": M720AddModePreparationState.failed.rawValue,
                "error": M720StableErrorCode.cancelled.rawValue,
                "deviceTokens": [],
            ] as NSDictionary,
        ])
    }

    func testEveryConstructiblePreparationOutcomeSelfRoundTrips() throws {
        var fixtures: [M720PreparationResult] = [
            M720PreparationResult(requestID: requestID, outcome: .ready, deviceTokens: []),
            M720PreparationResult(requestID: requestID, outcome: .conflict, deviceTokens: []),
            M720PreparationResult(requestID: requestID, outcome: .cancelled, deviceTokens: []),
        ]
        fixtures.append(contentsOf: M720PreparationFailure.allCases.map {
            M720PreparationResult(
                requestID: requestID,
                outcome: .failed($0),
                deviceTokens: [deviceToken]
            )
        })

        for fixture in fixtures {
            XCTAssertEqual(try M720PreparationResult.decode(fixture.payload), fixture)
        }
    }

    func testInactiveStateRoundTripsEveryReasonAndRejectsWrongStateOrReason() throws {
        for reason in M720AddModeInactiveReason.allCases {
            let fixture = M720AddModeStateChange(requestID: requestID, reason: reason)
            XCTAssertEqual(try M720AddModeStateChange.decode(fixture.payload), fixture)
        }

        assertProtocolFailures(M720AddModeStateChange.decode, payloads: [
            ["requestID": requestID.uuidString, "state": "ready", "reason": "saved"] as NSDictionary,
            ["requestID": requestID.uuidString, "state": "inactive", "reason": "unknown"] as NSDictionary,
            ["requestID": 1, "state": "inactive", "reason": "saved"] as NSDictionary,
        ])
    }

    func testCaptureStateRoundTripsStableStatesAndOptionalCorrelation() throws {
        let active = M720CaptureState(
            deviceToken: deviceToken,
            status: .active,
            requiredCIDs: [0x005B, 0x00C4],
            requestID: requestID
        )
        let invalid = M720CaptureState(
            deviceToken: deviceToken,
            status: .invalid(.disconnected),
            requiredCIDs: [],
            requestID: nil
        )
        XCTAssertEqual(try M720CaptureState.decode(active.payload), active)
        XCTAssertEqual(try M720CaptureState.decode(invalid.payload), invalid)

        let malformed: [Any?] = [
            replacing(active.payload, key: "deviceToken", value: "bad"),
            replacing(active.payload, key: "state", value: "unknown"),
            replacing(active.payload, key: "requiredCIDs", value: "005b"),
            replacing(active.payload, key: "requiredCIDs", value: [true]),
            replacing(active.payload, key: "requiredCIDs", value: [1.5]),
            replacing(active.payload, key: "requiredCIDs", value: [-1]),
            replacing(active.payload, key: "requiredCIDs", value: [65_536]),
            replacing(active.payload, key: "requiredCIDs", value: [0x005B, 0x005B]),
            replacing(active.payload, key: "requestID", value: 4),
            [
                "deviceToken": deviceToken.uuidString,
                "state": M720SessionStateName.invalid.rawValue,
                "requiredCIDs": [],
            ] as NSDictionary,
        ]
        assertProtocolFailures(M720CaptureState.decode, payloads: malformed)
    }

    func testCaptureStateEnforcesUniqueStateErrorContract() throws {
        let ordinaryStates = M720SessionStateName.allCases.filter {
            ![.conflict, .invalid].contains($0)
        }
        for state in ordinaryStates {
            assertProtocolFailures(M720CaptureState.decode, payloads: [[
                "deviceToken": deviceToken.uuidString,
                "state": state.rawValue,
                "error": M720StableErrorCode.timeout.rawValue,
                "requiredCIDs": [],
            ] as NSDictionary])
        }
        assertProtocolFailures(M720CaptureState.decode, payloads: [
            [
                "deviceToken": deviceToken.uuidString,
                "state": M720SessionStateName.conflict.rawValue,
                "requiredCIDs": [],
            ] as NSDictionary,
            [
                "deviceToken": deviceToken.uuidString,
                "state": M720SessionStateName.invalid.rawValue,
                "error": M720StableErrorCode.deviceSetChanged.rawValue,
                "requiredCIDs": [],
            ] as NSDictionary,
            [
                "deviceToken": deviceToken.uuidString,
                "state": M720SessionStateName.invalid.rawValue,
                "error": M720StableErrorCode.appUnavailable.rawValue,
                "requiredCIDs": [],
            ] as NSDictionary,
        ])

        let ordinaryStatuses: [M720CaptureStatus] = [
            .discovering, .nativeReady, .takingOver, .active, .restoring, .conflict,
        ]
        var fixtures = ordinaryStatuses.map {
            M720CaptureState(
                deviceToken: deviceToken,
                status: $0,
                requiredCIDs: [],
                requestID: nil
            )
        }
        fixtures.append(contentsOf: M720CaptureInvalidReason.allCases.map {
            M720CaptureState(
                deviceToken: deviceToken,
                status: .invalid($0),
                requiredCIDs: [0x005B],
                requestID: requestID
            )
        })
        for fixture in fixtures {
            XCTAssertEqual(try M720CaptureState.decode(fixture.payload), fixture)
        }
    }

    func testCaptureStatesSnapshotRejectsNonDictionaryElements() throws {
        let state = M720CaptureState(
            deviceToken: deviceToken,
            status: .nativeReady,
            requiredCIDs: [],
            requestID: nil
        )
        let fixture = M720CaptureStates(states: [state])
        XCTAssertEqual(try M720CaptureStates.decode(fixture.payload), fixture)

        assertProtocolFailures(M720CaptureStates.decode, payloads: [
            ["states": state.payload] as NSDictionary,
            ["states": [state.payload, "bad"]] as NSDictionary,
            ["states": [], "extra": 1] as NSDictionary,
        ])
    }

    func testFeedbackRoundTripsOnlyDictionaryFeedback() throws {
        let feedback: NSDictionary = ["trigger": ["button": 6]]
        let fixture = M720AddModeFeedback(requestID: requestID, feedback: feedback)
        XCTAssertEqual(try M720AddModeFeedback.decode(fixture.payload), fixture)

        assertProtocolFailures(M720AddModeFeedback.decode, payloads: [
            ["requestID": requestID.uuidString, "feedback": "bad"] as NSDictionary,
            ["requestID": "bad", "feedback": feedback] as NSDictionary,
            ["requestID": requestID.uuidString] as NSDictionary,
        ])
    }

    func testFeedbackRejectsCyclicAndSharedPropertyListContainers() {
        let cyclic = NSMutableArray()
        cyclic.add(cyclic)
        let shared = NSMutableArray(array: ["leaf"])

        assertProtocolFailures(M720AddModeFeedback.decode, payloads: [
            ["requestID": requestID.uuidString, "feedback": ["cycle": cyclic]] as NSDictionary,
            [
                "requestID": requestID.uuidString,
                "feedback": ["left": shared, "right": shared],
            ] as NSDictionary,
        ])
    }

    func testFeedbackRejectsExcessiveDepthAndNodeCount() throws {
        var deep: Any = "leaf"
        for _ in 0..<40 {
            deep = NSArray(object: deep)
        }
        let wide = NSArray(array: (0..<1_100).map(NSNumber.init(value:)))

        assertProtocolFailures(M720AddModeFeedback.decode, payloads: [
            ["requestID": requestID.uuidString, "feedback": ["deep": deep]] as NSDictionary,
            ["requestID": requestID.uuidString, "feedback": ["wide": wide]] as NSDictionary,
        ])

        let bounded: NSDictionary = ["nested": [["value": 1], ["value": 2]]]
        let fixture = M720AddModeFeedback(requestID: requestID, feedback: bounded)
        XCTAssertEqual(try M720AddModeFeedback.decode(fixture.payload), fixture)
    }

    func testEmptyPayloadAcceptsOnlyNil() throws {
        XCTAssertEqual(try M720EmptyPayload.decode(nil), M720EmptyPayload())
        assertProtocolFailures(M720EmptyPayload.decode, payloads: [
            NSNull(),
            [:] as NSDictionary,
            "" as NSString,
        ])
    }

    private func replacing(
        _ dictionary: NSDictionary,
        key: String,
        value: Any
    ) -> NSDictionary {
        let result = dictionary.mutableCopy() as! NSMutableDictionary
        result[key] = value
        return result
    }

    private func assertProtocolFailures<T>(
        _ decode: (Any?) throws -> T,
        payloads: [Any?],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for payload in payloads {
            XCTAssertThrowsError(try decode(payload), file: file, line: line) { error in
                XCTAssertEqual(error as? M720IPCDecodeError, .protocolViolation, file: file, line: line)
            }
        }
    }
}

extension M720AddModeIPCTests {
    func testAddModeReducerMovesFromIdleThroughRecordingAndFinishesAfterFeedback() {
        let requestID = coordinatorRequest(201)
        var reducer = M720AddModeReducer()

        XCTAssertEqual(reducer.begin(requestID, at: 10), .handled)
        XCTAssertEqual(reducer.state, .preparing(requestID))
        XCTAssertEqual(
            reducer.receivePreparationResult(requestID: requestID, result: .ready),
            .handled
        )
        XCTAssertEqual(reducer.state, .recording(requestID))
        XCTAssertEqual(reducer.receiveFeedback(requestID: requestID), .handled)
        XCTAssertEqual(reducer.finishAfterSaving(requestID), .handled)
        XCTAssertEqual(reducer.state, .idle)
    }

    func testAddModeReducerCancelsPreparingAndRecordingRequests() {
        let preparingID = coordinatorRequest(202)
        var reducer = M720AddModeReducer()
        reducer.begin(preparingID, at: 0)

        XCTAssertEqual(reducer.cancel(preparingID), .handled)
        XCTAssertEqual(reducer.state, .idle)

        let recordingID = coordinatorRequest(203)
        reducer.begin(recordingID, at: 1)
        reducer.receivePreparationResult(requestID: recordingID, result: .ready)

        XCTAssertEqual(reducer.cancel(recordingID), .handled)
        XCTAssertEqual(reducer.state, .idle)
    }

    func testAddModeReducerOverlappingBeginMakesEarlierMessagesStale() {
        let first = coordinatorRequest(204)
        let second = coordinatorRequest(205)
        var reducer = M720AddModeReducer()
        reducer.begin(first, at: 0)

        XCTAssertEqual(reducer.begin(second, at: 0.5), .handled)
        XCTAssertEqual(reducer.state, .preparing(second))
        XCTAssertEqual(
            reducer.receivePreparationResult(requestID: first, result: .ready),
            .ignored
        )
        XCTAssertEqual(reducer.receiveFeedback(requestID: first), .ignored)
        XCTAssertEqual(reducer.receiveInactive(requestID: first), .ignored)
        XCTAssertEqual(reducer.state, .preparing(second))
    }

    func testLateReadyCannotReopenCancelledRequest() {
        let first = coordinatorRequest(206)
        var reducer = M720AddModeReducer()
        reducer.begin(first, at: 0)
        reducer.cancel(first)

        XCTAssertEqual(
            reducer.receivePreparationResult(requestID: first, result: .ready),
            .ignored
        )
        XCTAssertEqual(reducer.state, .idle)
    }

    func testAddModeReducerIgnoresLateFeedbackAndInactiveAfterFinish() {
        let requestID = coordinatorRequest(207)
        var reducer = M720AddModeReducer()
        reducer.begin(requestID, at: 0)
        reducer.receivePreparationResult(requestID: requestID, result: .ready)
        reducer.finishAfterSaving(requestID)

        XCTAssertEqual(reducer.receiveFeedback(requestID: requestID), .ignored)
        XCTAssertEqual(reducer.receiveInactive(requestID: requestID), .ignored)
        XCTAssertEqual(reducer.state, .idle)
    }

    func testAddModeReducerRenewsEveryTwoSeconds() {
        let requestID = coordinatorRequest(208)
        var reducer = M720AddModeReducer()
        reducer.begin(requestID, at: 10)

        XCTAssertEqual(reducer.timerFired(at: 11.999), .none)
        XCTAssertEqual(reducer.timerFired(at: 12), .renew(requestID))
        XCTAssertEqual(reducer.timerFired(at: 13.999), .none)
        XCTAssertEqual(reducer.timerFired(at: 14), .renew(requestID))
    }

    func testAddModeReducerTimesOutPreparingLocallyAfterFiveSeconds() {
        let requestID = coordinatorRequest(209)
        var reducer = M720AddModeReducer()
        reducer.begin(requestID, at: 20)

        XCTAssertEqual(reducer.timerFired(at: 22), .renew(requestID))
        XCTAssertEqual(reducer.timerFired(at: 24), .renew(requestID))
        XCTAssertEqual(reducer.timerFired(at: 24.999), .none)
        XCTAssertEqual(reducer.timerFired(at: 25), .deadline(requestID))
        XCTAssertEqual(reducer.state, .idle)
    }

    func testAddModeReducerReadyClearsLocalDeadlineButKeepsLeaseRenewal() {
        let requestID = coordinatorRequest(210)
        var reducer = M720AddModeReducer()
        reducer.begin(requestID, at: 30)
        reducer.receivePreparationResult(requestID: requestID, result: .ready)

        XCTAssertEqual(reducer.timerFired(at: 32), .renew(requestID))
        XCTAssertEqual(reducer.timerFired(at: 34), .renew(requestID))
        XCTAssertEqual(reducer.timerFired(at: 35), .none)
        XCTAssertEqual(reducer.state, .recording(requestID))
    }

    func testAddModeReducerTerminalPreparationResultsReturnToIdle() {
        let outcomes: [M720PreparationOutcome] = [
            .failed(.timeout),
            .conflict,
            .cancelled,
        ]

        for (index, outcome) in outcomes.enumerated() {
            let requestID = coordinatorRequest(211 + index)
            var reducer = M720AddModeReducer()
            reducer.begin(requestID, at: 0)

            XCTAssertEqual(
                reducer.receivePreparationResult(requestID: requestID, result: outcome),
                .handled
            )
            XCTAssertEqual(reducer.state, .idle)
        }
    }

    func testAddModeClientBeginIsNonblockingAndUsesTypedPrepareRequest() throws {
        let harness = AddModeClientHarness(requestIDs: [coordinatorRequest(220)])

        harness.client.begin()

        XCTAssertEqual(harness.client.state, .preparing(coordinatorRequest(220)))
        XCTAssertTrue(harness.sentMessages.isEmpty)
        XCTAssertEqual(harness.timers.map(\.delay), [2, 5])
        XCTAssertEqual(harness.timers.map(\.repeats), [true, false])

        harness.drainIPC()

        let sent = try XCTUnwrap(harness.sentMessages.single)
        XCTAssertEqual(sent.name, M720IPCMessage.prepareAddMode)
        XCTAssertTrue(sent.waitForReply)
        XCTAssertEqual(try M720IPCRequest.decode(sent.payload).requestID, coordinatorRequest(220))
    }

    func testAddModeClientOverlappingBeginUsesFreshIDAndIgnoresStaleReady() {
        let first = coordinatorRequest(221)
        let second = coordinatorRequest(222)
        let harness = AddModeClientHarness(requestIDs: [first, second])

        harness.client.begin()
        harness.client.begin()
        harness.client.handlePreparationResult(
            M720PreparationResult(requestID: first, outcome: .ready, deviceTokens: []).payload
        )

        XCTAssertEqual(harness.client.state, .preparing(second))
        XCTAssertTrue(harness.timers.prefix(2).allSatisfy(\.isCancelled))

        harness.client.handlePreparationResult(
            M720PreparationResult(requestID: second, outcome: .ready, deviceTokens: []).payload
        )
        XCTAssertEqual(harness.client.state, .recording(second))
    }

    func testAddModeClientCancelStopsTimersBeforeInvalidatingAndSendsCorrelatedCancel() throws {
        let requestID = coordinatorRequest(223)
        let harness = AddModeClientHarness(requestIDs: [requestID])
        var timersWereCancelledAtIdle = false
        harness.client.onStateChange = { state in
            if state == .idle {
                timersWereCancelledAtIdle = harness.timers.allSatisfy(\.isCancelled)
            }
        }
        harness.client.begin()
        harness.drainIPC()

        harness.client.cancel()

        XCTAssertEqual(harness.client.state, .idle)
        XCTAssertTrue(timersWereCancelledAtIdle)
        harness.drainIPC()
        let sent = try XCTUnwrap(harness.sentMessages.last)
        XCTAssertEqual(sent.name, M720IPCMessage.cancelPreparation)
        XCTAssertEqual(try M720IPCRequest.decode(sent.payload).requestID, requestID)
    }

    func testAddModeClientRoutesOnlyCorrelatedFeedbackAndFinishesAfterSaving() throws {
        let requestID = coordinatorRequest(224)
        let staleID = coordinatorRequest(225)
        let harness = AddModeClientHarness(requestIDs: [requestID])
        var feedbacks: [NSDictionary] = []
        harness.client.onFeedback = { feedbacks.append($0) }
        harness.client.begin()
        harness.client.handlePreparationResult(
            M720PreparationResult(requestID: requestID, outcome: .ready, deviceTokens: []).payload
        )

        harness.client.handleFeedback(M720AddModeFeedback(
            requestID: staleID,
            feedback: ["button": 7]
        ).payload)
        harness.client.handleFeedback(M720AddModeFeedback(
            requestID: requestID,
            feedback: ["button": 8]
        ).payload)

        XCTAssertEqual(feedbacks.count, 1)
        XCTAssertEqual(feedbacks.single?["button"] as? Int, 8)
        harness.client.finishAfterSaving()
        XCTAssertEqual(harness.client.state, .idle)
        harness.drainIPC()
        let sent = try XCTUnwrap(harness.sentMessages.last)
        XCTAssertEqual(sent.name, M720IPCMessage.finishAddMode)
        XCTAssertEqual(try M720IPCRequest.decode(sent.payload).requestID, requestID)
    }

    func testAddModeClientRenewsAtTwoSecondsAndTimesOutPreparingAtFive() throws {
        let requestID = coordinatorRequest(226)
        let harness = AddModeClientHarness(requestIDs: [requestID])
        var failures: [M720StableErrorCode] = []
        harness.client.onFailure = { failures.append($0) }
        harness.client.begin()
        harness.drainIPC()

        harness.now = 2
        harness.timer(delay: 2).fire()
        harness.drainIPC()
        XCTAssertEqual(harness.sentMessages.last?.name, M720IPCMessage.renewLease)
        XCTAssertEqual(
            try M720IPCRequest.decode(harness.sentMessages.last?.payload).requestID,
            requestID
        )

        harness.now = 5
        harness.timer(delay: 5).fire()
        XCTAssertEqual(harness.client.state, .idle)
        XCTAssertEqual(failures, [.timeout])
        harness.drainIPC()
        XCTAssertEqual(harness.sentMessages.last?.name, M720IPCMessage.cancelPreparation)
    }

    func testAddModeClientRejectedAcknowledgementFailsCurrentRequestOnMain() {
        let requestID = coordinatorRequest(227)
        let harness = AddModeClientHarness(requestIDs: [requestID])
        harness.reply = M720IPCAcknowledgement.rejected(.unsupported).payload
        var failures: [M720StableErrorCode] = []
        harness.client.onFailure = { failures.append($0) }

        harness.client.begin()
        XCTAssertEqual(harness.client.state, .preparing(requestID))
        harness.drainIPC()

        XCTAssertEqual(harness.client.state, .idle)
        XCTAssertEqual(failures, [.unsupported])
    }

    func testAddModeClientCurrentInactiveStopsRecordingAndLateInactiveIsIgnored() {
        let first = coordinatorRequest(228)
        let second = coordinatorRequest(229)
        let harness = AddModeClientHarness(requestIDs: [first, second])
        harness.client.begin()
        harness.client.begin()
        harness.client.handlePreparationResult(
            M720PreparationResult(requestID: second, outcome: .ready, deviceTokens: []).payload
        )

        harness.client.handleStateChange(
            M720AddModeStateChange(requestID: first, reason: .cancelled).payload
        )
        XCTAssertEqual(harness.client.state, .recording(second))

        harness.client.handleStateChange(
            M720AddModeStateChange(requestID: second, reason: .deviceSetChanged).payload
        )
        XCTAssertEqual(harness.client.state, .idle)
    }

    func testAddModeClientIgnoresMalformedStaleEnvelopeButFailsMalformedCurrentEnvelope() {
        let first = coordinatorRequest(236)
        let second = coordinatorRequest(237)
        let harness = AddModeClientHarness(requestIDs: [first, second])
        var failures: [M720StableErrorCode] = []
        harness.client.onFailure = { failures.append($0) }
        harness.client.begin()
        harness.client.begin()

        harness.client.handlePreparationResult([
            "requestID": first.uuidString,
            "state": "not-a-state",
        ])
        XCTAssertEqual(harness.client.state, .preparing(second))
        XCTAssertTrue(failures.isEmpty)

        harness.client.handlePreparationResult([
            "requestID": second.uuidString,
            "state": "not-a-state",
        ])
        XCTAssertEqual(harness.client.state, .idle)
        XCTAssertEqual(failures, [.protocol])
    }

    func testCaptureAlertReducerDedupesConflictUntilStateChanges() {
        let token = coordinatorToken(230)
        let conflict = M720CaptureState(
            deviceToken: token,
            status: .conflict,
            requiredCIDs: [0x005B],
            requestID: nil
        )
        let active = M720CaptureState(
            deviceToken: token,
            status: .active,
            requiredCIDs: [0x005B],
            requestID: nil
        )
        var reducer = M720CaptureAlertReducer()

        XCTAssertTrue(reducer.shouldPresent(conflict))
        XCTAssertFalse(reducer.shouldPresent(conflict))
        XCTAssertFalse(reducer.shouldPresent(active))
        XCTAssertTrue(reducer.shouldPresent(conflict))
    }

    func testCaptureAlertReducerKeysDedupeByDeviceStateAndError() {
        let first = coordinatorToken(231)
        let second = coordinatorToken(232)
        var reducer = M720CaptureAlertReducer()

        XCTAssertTrue(reducer.shouldPresent(M720CaptureState(
            deviceToken: first,
            status: .conflict,
            requiredCIDs: [],
            requestID: nil
        )))
        XCTAssertTrue(reducer.shouldPresent(M720CaptureState(
            deviceToken: second,
            status: .conflict,
            requiredCIDs: [],
            requestID: nil
        )))
        XCTAssertFalse(reducer.shouldPresent(M720CaptureState(
            deviceToken: first,
            status: .conflict,
            requiredCIDs: [0x00C4],
            requestID: coordinatorRequest(233)
        )))
    }

    func testCaptureAlertReducerShowsStaleTokenDisconnectedOnlyOnce() {
        let token = coordinatorToken(234)
        var reducer = M720CaptureAlertReducer()

        XCTAssertTrue(reducer.shouldPresentRetryError(
            deviceToken: token,
            errorCode: .disconnected
        ))
        XCTAssertFalse(reducer.shouldPresentRetryError(
            deviceToken: token,
            errorCode: .disconnected
        ))
        XCTAssertTrue(reducer.shouldPresentRetryError(
            deviceToken: token,
            errorCode: .protocol
        ))
    }

    func testCaptureAlertReducerSnapshotRemovalAllowsFutureConflict() {
        let token = coordinatorToken(235)
        let conflict = M720CaptureState(
            deviceToken: token,
            status: .conflict,
            requiredCIDs: [],
            requestID: nil
        )
        var reducer = M720CaptureAlertReducer()

        XCTAssertEqual(reducer.replaceSnapshot([conflict]).map(\.deviceToken), [token])
        XCTAssertTrue(reducer.replaceSnapshot([]).isEmpty)
        XCTAssertEqual(reducer.replaceSnapshot([conflict]).map(\.deviceToken), [token])
    }

    func testCoordinatorPrepareAcknowledgesBeforeWorkAndAggregatesFrozenParticipants() throws {
        let first = coordinatorToken(1)
        let second = coordinatorToken(2)
        let harness = CoordinatorHarness(participants: [
            M720PreparationParticipant(deviceToken: first, exactRequiredCIDs: [0x005B]),
            M720PreparationParticipant(deviceToken: second, exactRequiredCIDs: [0x005D, 0x00D0]),
        ])
        let requestID = coordinatorRequest(1)

        XCTAssertEqual(try harness.prepare(requestID), .accepted)
        XCTAssertTrue(harness.controller.operations.isEmpty)
        XCTAssertTrue(harness.messages.isEmpty)
        XCTAssertTrue(harness.trace.isEmpty)

        harness.executor.drainAll()
        let begin = try XCTUnwrap(harness.controller.operations.single)
        XCTAssertEqual(begin.kind, .begin)
        XCTAssertEqual(begin.snapshot?.participants.map(\.deviceToken), [first, second])
        XCTAssertEqual(begin.targetCIDs, Set(M720Profile.cidToButton.keys))
        XCTAssertTrue(harness.messages.isEmpty)

        harness.controller.complete(.begin, with: .ready)
        XCTAssertEqual(harness.preparationResults(for: requestID).map(\.outcome), [.ready])
        XCTAssertEqual(harness.preparationResults(for: requestID).single?.deviceTokens, [first, second])
        XCTAssertEqual(harness.trace, ["controller.begin", "remap.enable", "send.addModePreparationResult"])
    }

    func testCoordinatorNoParticipantPathStillStartsOnlyAfterAcknowledgement() throws {
        let harness = CoordinatorHarness()
        let requestID = coordinatorRequest(2)

        XCTAssertEqual(try harness.prepare(requestID), .accepted)
        XCTAssertTrue(harness.trace.isEmpty)
        harness.executor.drainAll()
        XCTAssertEqual(harness.controller.operations.map(\.kind), [.begin])
        harness.controller.complete(.begin, with: .ready)

        XCTAssertEqual(harness.preparationResults(for: requestID).map(\.outcome), [.ready])
        XCTAssertEqual(harness.trace, ["controller.begin", "remap.enable", "send.addModePreparationResult"])
    }

    func testCoordinatorEnvironmentDisabledAtAcceptanceVerifiesNativeThenCancels() throws {
        let harness = CoordinatorHarness(
            environmentEnabled: false,
            participants: [M720PreparationParticipant(
                deviceToken: coordinatorToken(3),
                exactRequiredCIDs: [0x005B]
            )]
        )
        let requestID = coordinatorRequest(3)

        XCTAssertEqual(try harness.prepare(requestID), .accepted)
        harness.executor.drainAll()
        harness.controller.complete(.begin, with: .ready)

        XCTAssertEqual(harness.controller.operations.map(\.kind), [.restore])
        XCTAssertFalse(harness.trace.contains("remap.enable"))
        XCTAssertTrue(harness.preparationResults(for: requestID).isEmpty)
        harness.controller.complete(.restore, with: .ready)

        XCTAssertEqual(harness.preparationResults(for: requestID).map(\.outcome), [.cancelled])
        XCTAssertEqual(harness.controller.clearOwners, [harness.generatedOwners[0]])
    }

    func testCoordinatorCancelBeforeAndAfterReadyUseUniqueTerminalShapes() throws {
        do {
            let harness = CoordinatorHarness(oneParticipant: coordinatorToken(4))
            let requestID = coordinatorRequest(4)
            XCTAssertEqual(try harness.prepare(requestID), .accepted)
            harness.executor.drainAll()

            XCTAssertEqual(try harness.cancel(requestID), .accepted)
            XCTAssertEqual(harness.controller.operations.map(\.kind), [.begin])
            harness.executor.drainAll()
            XCTAssertEqual(harness.controller.operations.map(\.kind), [.begin, .restore])
            harness.controller.complete(.restore, with: .ready)

            XCTAssertEqual(harness.preparationResults(for: requestID).map(\.outcome), [.cancelled])
            XCTAssertTrue(harness.inactiveStates(for: requestID).isEmpty)
        }

        do {
            let harness = CoordinatorHarness(oneParticipant: coordinatorToken(5))
            let requestID = coordinatorRequest(5)
            XCTAssertEqual(try harness.prepare(requestID), .accepted)
            harness.executor.drainAll()
            harness.controller.complete(.begin, with: .ready)
            XCTAssertEqual(try harness.cancel(requestID), .accepted)
            harness.executor.drainAll()
            harness.controller.complete(.restore, with: .ready)

            XCTAssertEqual(harness.preparationResults(for: requestID).map(\.outcome), [.ready])
            XCTAssertEqual(harness.inactiveStates(for: requestID).map(\.reason), [.cancelled])
        }
    }

    func testCoordinatorAcceptedCancelFencesQueuedStartAndReadyBeforeReturning() throws {
        do {
            let harness = CoordinatorHarness(oneParticipant: coordinatorToken(69))
            let requestID = coordinatorRequest(69)

            XCTAssertEqual(try harness.prepare(requestID), .accepted)
            XCTAssertEqual(try harness.cancel(requestID), .accepted)
            XCTAssertEqual(try harness.renew(requestID), .rejected(.cancelled))
            harness.executor.drainAll()

            XCTAssertTrue(harness.controller.operations.isEmpty)
            XCTAssertFalse(harness.trace.contains("controller.begin"))
            XCTAssertFalse(harness.trace.contains("remap.enable"))
            XCTAssertEqual(harness.preparationResults(for: requestID).map(\.outcome), [.cancelled])
        }

        do {
            let harness = CoordinatorHarness(oneParticipant: coordinatorToken(70))
            let requestID = coordinatorRequest(70)

            XCTAssertEqual(try harness.prepare(requestID), .accepted)
            harness.executor.drainAll()
            let queuedReady = try XCTUnwrap(harness.controller.takeCompletion(.begin))
            harness.executor.enqueue { queuedReady(.ready) }

            XCTAssertEqual(try harness.cancel(requestID), .accepted)
            XCTAssertEqual(try harness.renew(requestID), .rejected(.cancelled))
            harness.executor.drainAll()

            XCTAssertFalse(harness.trace.contains("remap.enable"))
            XCTAssertTrue(harness.preparationResults(for: requestID).isEmpty)
            XCTAssertEqual(harness.controller.operations.map(\.kind), [.restore])
            harness.controller.complete(.restore, with: .ready)
            XCTAssertEqual(harness.preparationResults(for: requestID).map(\.outcome), [.cancelled])
        }
    }

    func testCoordinatorAcceptedOverlapFencesQueuedReadyBeforeReturning() throws {
        let harness = CoordinatorHarness(oneParticipant: coordinatorToken(71))
        let first = coordinatorRequest(71)
        let second = coordinatorRequest(72)

        XCTAssertEqual(try harness.prepare(first), .accepted)
        harness.executor.drainAll()
        let queuedReady = try XCTUnwrap(harness.controller.takeCompletion(.begin))
        harness.executor.enqueue { queuedReady(.ready) }

        XCTAssertEqual(try harness.prepare(second), .accepted)
        XCTAssertEqual(try harness.renew(first), .rejected(.cancelled))
        harness.executor.drainAll()

        XCTAssertFalse(harness.trace.contains("remap.enable"))
        XCTAssertTrue(harness.preparationResults(for: first).isEmpty)
        XCTAssertEqual(harness.controller.operations.map(\.kind), [.restore])
        harness.controller.complete(.restore, with: .ready)

        XCTAssertEqual(harness.preparationResults(for: first).map(\.outcome), [.cancelled])
        XCTAssertEqual(harness.controller.operations.map(\.kind), [.begin])
        XCTAssertEqual(harness.controller.operations.single?.ownerID, harness.generatedOwners[1])
    }

    func testCoordinatorThirdPrepareReplacesPendingAfterAckAndWaitsForVerifiedRollback() throws {
        let harness = CoordinatorHarness(oneParticipant: coordinatorToken(6))
        let first = coordinatorRequest(6)
        let second = coordinatorRequest(7)
        let third = coordinatorRequest(8)

        XCTAssertEqual(try harness.prepare(first), .accepted)
        harness.executor.drainAll()
        XCTAssertEqual(try harness.prepare(second), .accepted)
        XCTAssertEqual(try harness.prepare(third), .accepted)
        XCTAssertTrue(harness.preparationResults(for: second).isEmpty)

        harness.executor.drainAll()
        XCTAssertEqual(harness.preparationResults(for: second).map(\.outcome), [.cancelled])
        XCTAssertEqual(harness.controller.operations.map(\.kind), [.begin, .restore])
        XCTAssertTrue(harness.preparationResults(for: first).isEmpty)

        harness.controller.complete(.restore, with: .ready)
        XCTAssertEqual(harness.preparationResults(for: first).map(\.outcome), [.cancelled])
        XCTAssertEqual(harness.controller.operations.map(\.kind), [.begin, .begin])
        XCTAssertEqual(harness.controller.operations.last?.ownerID, harness.generatedOwners[2])
        XCTAssertNotEqual(harness.generatedOwners[0], harness.generatedOwners[2])
        XCTAssertTrue(harness.preparationResults(for: third).isEmpty)
    }

    func testCoordinatorRollbackFailureTerminatesRecordingAndLatestPendingWithoutNewTakeover() throws {
        let harness = CoordinatorHarness(oneParticipant: coordinatorToken(7))
        let active = coordinatorRequest(9)
        let replaced = coordinatorRequest(10)
        let latest = coordinatorRequest(11)
        XCTAssertEqual(try harness.prepare(active), .accepted)
        harness.executor.drainAll()
        harness.controller.complete(.begin, with: .ready)

        XCTAssertEqual(try harness.prepare(replaced), .accepted)
        XCTAssertEqual(try harness.prepare(latest), .accepted)
        harness.executor.drainAll()
        harness.controller.complete(.restore, with: .failed(.conflict))

        XCTAssertEqual(harness.preparationResults(for: active).map(\.outcome), [.ready])
        XCTAssertEqual(harness.inactiveStates(for: active).map(\.reason), [.cancelled])
        XCTAssertEqual(harness.preparationResults(for: replaced).map(\.outcome), [.cancelled])
        XCTAssertEqual(harness.preparationResults(for: latest).map(\.outcome), [.conflict])
        XCTAssertEqual(harness.trace.filter { $0 == "controller.begin" }.count, 1)
        XCTAssertTrue(harness.controller.clearOwners.isEmpty)
    }

    func testCoordinatorDeadlineLeaseRenewalAndAppDeathMapToDistinctTerminals() throws {
        do {
            let harness = CoordinatorHarness(oneParticipant: coordinatorToken(8))
            let requestID = coordinatorRequest(12)
            XCTAssertEqual(try harness.prepare(requestID), .accepted)
            harness.executor.drainAll()
            harness.scheduler.advance(by: 4)
            XCTAssertEqual(try harness.renew(requestID), .accepted)
            harness.scheduler.advance(by: 1)
            harness.controller.complete(.restore, with: .ready)
            XCTAssertEqual(
                harness.preparationResults(for: requestID).map(\.outcome),
                [.failed(.timeout)]
            )
        }

        do {
            let harness = CoordinatorHarness(oneParticipant: coordinatorToken(9))
            let requestID = coordinatorRequest(13)
            XCTAssertEqual(try harness.prepare(requestID), .accepted)
            harness.executor.drainAll()
            harness.controller.complete(.begin, with: .ready)
            harness.scheduler.advance(by: 4)
            XCTAssertEqual(try harness.renew(requestID), .accepted)
            harness.scheduler.advance(by: 4)
            XCTAssertTrue(harness.controller.operations.isEmpty)
            harness.scheduler.advance(by: 1)
            harness.controller.complete(.restore, with: .ready)
            XCTAssertEqual(harness.preparationResults(for: requestID).map(\.outcome), [.ready])
            XCTAssertEqual(harness.inactiveStates(for: requestID).map(\.reason), [.appUnavailable])
        }

        do {
            let harness = CoordinatorHarness(oneParticipant: coordinatorToken(10))
            let requestID = coordinatorRequest(14)
            XCTAssertEqual(try harness.prepare(requestID), .accepted)
            harness.executor.drainAll()
            harness.appDidTerminate?()
            harness.controller.complete(.restore, with: .ready)
            XCTAssertEqual(
                harness.preparationResults(for: requestID).map(\.outcome),
                [.failed(.appUnavailable)]
            )
        }
    }

    func testCoordinatorFixedDeadlineWinsWhenLeaseTimerFiresFirst() throws {
        do {
            let harness = CoordinatorHarness(oneParticipant: coordinatorToken(66))
            let requestID = coordinatorRequest(66)
            XCTAssertEqual(try harness.prepare(requestID), .accepted)
            harness.executor.drainAll()
            harness.scheduler.advanceClock(by: 5)

            harness.scheduler.fireLatestDueTask()
            XCTAssertEqual(harness.controller.operations.map(\.kind), [.begin])
            XCTAssertTrue(harness.preparationResults(for: requestID).isEmpty)

            harness.scheduler.fireEarliestDueTask()
            XCTAssertEqual(harness.controller.operations.map(\.kind), [.begin, .restore])
            harness.controller.complete(.restore, with: .ready)
            XCTAssertEqual(
                harness.preparationResults(for: requestID).map(\.outcome),
                [.failed(.timeout)]
            )
        }

        do {
            let harness = CoordinatorHarness(oneParticipant: coordinatorToken(67))
            let active = coordinatorRequest(67)
            let pending = coordinatorRequest(68)
            XCTAssertEqual(try harness.prepare(active), .accepted)
            harness.executor.drainAll()
            harness.controller.complete(.begin, with: .ready)
            XCTAssertEqual(try harness.prepare(pending), .accepted)
            harness.executor.drainAll()
            harness.scheduler.advanceClock(by: 5)

            harness.scheduler.fireLatestDueTask()
            XCTAssertTrue(harness.preparationResults(for: pending).isEmpty)

            harness.scheduler.fireEarliestDueTask()
            XCTAssertEqual(
                harness.preparationResults(for: pending).map(\.outcome),
                [.failed(.timeout)]
            )
        }
    }

    func testCoordinatorPendingPreparationHasItsOwnFixedDeadlineAndUniqueTerminal() throws {
        let harness = CoordinatorHarness(oneParticipant: coordinatorToken(19))
        let active = coordinatorRequest(17)
        let pending = coordinatorRequest(18)
        XCTAssertEqual(try harness.prepare(active), .accepted)
        harness.executor.drainAll()
        harness.controller.complete(.begin, with: .ready)
        harness.scheduler.advance(by: 1)

        XCTAssertEqual(try harness.prepare(pending), .accepted)
        harness.executor.drainAll()
        XCTAssertEqual(harness.controller.operations.map(\.kind), [.restore])
        harness.scheduler.advance(by: 5)

        XCTAssertEqual(
            harness.preparationResults(for: pending).map(\.outcome),
            [.failed(.timeout)]
        )
        harness.controller.complete(.restore, with: .ready)
        XCTAssertEqual(harness.inactiveStates(for: active).map(\.reason), [.cancelled])
        XCTAssertEqual(harness.preparationResults(for: pending).count, 1)
        XCTAssertTrue(harness.controller.operations.isEmpty)
    }

    func testCoordinatorContextChangeDuringRollbackRetriesSameOwnerWithoutBlockingLease() throws {
        let fixtures: [(
            change: M720PreparationContextChange,
            transient: M720StableErrorCode,
            outcome: M720PreparationOutcome
        )] = [
            (.deviceSetChanged(revision: 2), .deviceSetChanged, .failed(.deviceSetChanged)),
            (.environmentChanged(enabled: false), .cancelled, .cancelled),
        ]

        for (index, fixture) in fixtures.enumerated() {
            let harness = CoordinatorHarness(oneParticipant: coordinatorToken(40 + index))
            let requestID = coordinatorRequest(40 + index)
            XCTAssertEqual(try harness.prepare(requestID), .accepted)
            harness.executor.drainAll()
            XCTAssertEqual(try harness.cancel(requestID), .accepted)
            harness.executor.drainAll()
            let owner = try XCTUnwrap(
                harness.controller.operations.first(where: { $0.kind == .restore })?.ownerID
            )

            harness.controller.onPreparationContextChange?(fixture.change)
            harness.controller.complete(.restore, with: .failed(fixture.transient))

            XCTAssertEqual(harness.trace.filter { $0 == "controller.restore" }.count, 2)
            XCTAssertEqual(
                harness.controller.operations.last(where: { $0.kind == .restore })?.ownerID,
                owner
            )
            XCTAssertTrue(harness.preparationResults(for: requestID).isEmpty)
            harness.controller.complete(.restore, with: .ready)

            XCTAssertEqual(
                harness.preparationResults(for: requestID).map(\.outcome),
                [fixture.outcome]
            )
            XCTAssertEqual(harness.controller.clearOwners, [owner])
        }
    }

    func testCoordinatorPreReadyRollbackFailureUsesRollbackErrorAsTerminal() throws {
        let fixtures: [(M720StableErrorCode, M720PreparationOutcome)] = [
            (.conflict, .conflict),
            (.disconnected, .failed(.disconnected)),
        ]
        for (index, fixture) in fixtures.enumerated() {
            let harness = CoordinatorHarness(oneParticipant: coordinatorToken(50 + index))
            let requestID = coordinatorRequest(50 + index)
            XCTAssertEqual(try harness.prepare(requestID), .accepted)
            harness.executor.drainAll()
            XCTAssertEqual(try harness.cancel(requestID), .accepted)
            harness.executor.drainAll()
            harness.controller.complete(.restore, with: .failed(fixture.0))

            XCTAssertEqual(harness.preparationResults(for: requestID).map(\.outcome), [fixture.1])
            XCTAssertTrue(harness.inactiveStates(for: requestID).isEmpty)
        }
    }

    func testCoordinatorBlockedLeaseFailsActiveAndLatestPendingWithoutAnotherBegin() throws {
        let harness = CoordinatorHarness(oneParticipant: coordinatorToken(60))
        let blocked = coordinatorRequest(60)
        XCTAssertEqual(try harness.prepare(blocked), .accepted)
        harness.executor.drainAll()
        XCTAssertEqual(try harness.cancel(blocked), .accepted)
        harness.executor.drainAll()
        harness.controller.complete(.restore, with: .failed(.conflict))
        XCTAssertEqual(harness.preparationResults(for: blocked).map(\.outcome), [.conflict])

        let active = coordinatorRequest(61)
        let pending = coordinatorRequest(62)
        XCTAssertEqual(try harness.prepare(active), .accepted)
        XCTAssertEqual(try harness.prepare(pending), .accepted)
        harness.executor.drainAll()

        XCTAssertEqual(harness.preparationResults(for: active).map(\.outcome), [.conflict])
        XCTAssertEqual(harness.preparationResults(for: pending).map(\.outcome), [.conflict])
        XCTAssertEqual(harness.trace.filter { $0 == "controller.begin" }.count, 1)
    }

    func testCoordinatorReservedSupersedeFenceSkipsObsoleteTakeover() throws {
        let harness = CoordinatorHarness(oneParticipant: coordinatorToken(63))
        let obsolete = coordinatorRequest(63)
        let latest = coordinatorRequest(64)

        XCTAssertEqual(try harness.prepare(obsolete), .accepted)
        XCTAssertEqual(try harness.prepare(latest), .accepted)
        XCTAssertTrue(harness.controller.operations.isEmpty)
        harness.executor.drainAll()

        XCTAssertEqual(harness.preparationResults(for: obsolete).map(\.outcome), [.cancelled])
        XCTAssertEqual(harness.controller.operations.map(\.kind), [.begin])
        XCTAssertEqual(harness.controller.operations.single?.ownerID, harness.generatedOwners[1])
        XCTAssertFalse(harness.trace.contains("controller.restore"))
    }

    func testCoordinatorDeviceAndEnvironmentChangesFenceOldCompletions() throws {
        do {
            let harness = CoordinatorHarness(oneParticipant: coordinatorToken(11))
            let requestID = coordinatorRequest(15)
            XCTAssertEqual(try harness.prepare(requestID), .accepted)
            harness.executor.drainAll()
            let lateTakeover = try XCTUnwrap(harness.controller.operations.single?.completion)
            harness.controller.onPreparationContextChange?(.deviceSetChanged(revision: 2))
            harness.controller.complete(.restore, with: .ready)
            lateTakeover(.ready)

            XCTAssertEqual(
                harness.preparationResults(for: requestID).map(\.outcome),
                [.failed(.deviceSetChanged)]
            )
            XCTAssertEqual(harness.preparationResults(for: requestID).count, 1)
        }

        do {
            let harness = CoordinatorHarness(oneParticipant: coordinatorToken(12))
            let requestID = coordinatorRequest(16)
            XCTAssertEqual(try harness.prepare(requestID), .accepted)
            harness.executor.drainAll()
            harness.controller.onPreparationContextChange?(.environmentChanged(enabled: false))
            harness.controller.complete(.restore, with: .ready)
            XCTAssertEqual(harness.preparationResults(for: requestID).map(\.outcome), [.cancelled])
        }
    }

    func testCoordinatorParticipantFailuresMapAfterRollbackAndLateCallbacksDoNothing() throws {
        let cases: [(M720StableErrorCode, M720PreparationOutcome)] = [
            (.conflict, .conflict),
            (.disconnected, .failed(.disconnected)),
            (.unsupported, .failed(.unsupported)),
            (.protocol, .failed(.protocol)),
        ]
        for (index, fixture) in cases.enumerated() {
            let harness = CoordinatorHarness(oneParticipant: coordinatorToken(20 + index))
            let requestID = coordinatorRequest(20 + index)
            XCTAssertEqual(try harness.prepare(requestID), .accepted)
            harness.executor.drainAll()
            let lateTakeover = try XCTUnwrap(harness.controller.operations.single?.completion)
            harness.controller.complete(.begin, with: .failed(fixture.0))
            harness.controller.complete(.restore, with: .ready)
            lateTakeover(.ready)

            XCTAssertEqual(harness.preparationResults(for: requestID).map(\.outcome), [fixture.1])
            XCTAssertEqual(harness.preparationResults(for: requestID).count, 1)
        }
    }

    func testCoordinatorFinishOrdersReloadVerificationClearAndSavedPublication() throws {
        let harness = CoordinatorHarness(oneParticipant: coordinatorToken(30))
        let requestID = coordinatorRequest(30)
        XCTAssertEqual(try harness.prepare(requestID), .accepted)
        harness.executor.drainAll()
        harness.controller.complete(.begin, with: .ready)
        harness.trace.removeAll()

        XCTAssertEqual(try harness.finish(requestID), .accepted)
        XCTAssertTrue(harness.trace.isEmpty)
        harness.executor.drainAll()
        XCTAssertEqual(harness.trace, ["remap.disable", "config.reload", "controller.update"])
        harness.controller.complete(.update, with: .ready)

        XCTAssertEqual(
            harness.trace,
            ["remap.disable", "config.reload", "controller.update", "controller.clear", "send.addModeStateChanged"]
        )
        XCTAssertEqual(harness.inactiveStates(for: requestID).map(\.reason), [.saved])
    }

    func testCoordinatorFinishRetriesCurrentSavedVerificationWhenClearSeesNewerSavedPolicy() throws {
        let harness = CoordinatorHarness(oneParticipant: coordinatorToken(31))
        harness.controller.clearResults = [false, true]
        let requestID = coordinatorRequest(31)
        XCTAssertEqual(try harness.prepare(requestID), .accepted)
        harness.executor.drainAll()
        harness.controller.complete(.begin, with: .ready)
        XCTAssertEqual(try harness.finish(requestID), .accepted)
        harness.executor.drainAll()

        harness.controller.complete(.update, with: .ready)
        XCTAssertEqual(harness.controller.operations.map(\.kind), [.update])
        XCTAssertTrue(harness.inactiveStates(for: requestID).isEmpty)
        harness.controller.complete(.update, with: .ready)
        XCTAssertEqual(harness.inactiveStates(for: requestID).map(\.reason), [.saved])
        XCTAssertEqual(
            harness.controller.clearOwners,
            [harness.generatedOwners[0], harness.generatedOwners[0]]
        )
    }

    func testCoordinatorAcceptedFinishCancelsLeaseExpiryBeforeQueuedFinishWork() throws {
        let harness = CoordinatorHarness(oneParticipant: coordinatorToken(65))
        let requestID = coordinatorRequest(65)
        XCTAssertEqual(try harness.prepare(requestID), .accepted)
        harness.executor.drainAll()
        harness.controller.complete(.begin, with: .ready)
        harness.scheduler.advance(by: 4)

        XCTAssertEqual(try harness.finish(requestID), .accepted)
        harness.scheduler.advance(by: 1)
        XCTAssertTrue(harness.controller.operations.isEmpty)
        XCTAssertTrue(harness.inactiveStates(for: requestID).isEmpty)

        harness.executor.drainAll()
        XCTAssertEqual(harness.controller.operations.map(\.kind), [.update])
        harness.controller.complete(.update, with: .ready)
        XCTAssertEqual(harness.inactiveStates(for: requestID).map(\.reason), [.saved])
    }

    func testCoordinatorAcceptedFinishFencesAppTerminationBeforeQueuedWork() throws {
        let harness = CoordinatorHarness(oneParticipant: coordinatorToken(76))
        let requestID = coordinatorRequest(76)
        XCTAssertEqual(try harness.prepare(requestID), .accepted)
        harness.executor.drainAll()
        harness.controller.complete(.begin, with: .ready)
        harness.trace.removeAll()

        XCTAssertEqual(try harness.finish(requestID), .accepted)
        harness.appDidTerminate?()
        harness.executor.drainAll()

        XCTAssertEqual(
            harness.trace,
            ["remap.disable", "config.reload", "controller.update"]
        )
        harness.controller.complete(.update, with: .ready)
        XCTAssertEqual(harness.inactiveStates(for: requestID).map(\.reason), [.saved])
    }

    func testCoordinatorAcceptedFinishFencesContextChangeBeforeQueuedWork() throws {
        let harness = CoordinatorHarness(oneParticipant: coordinatorToken(77))
        let requestID = coordinatorRequest(77)
        XCTAssertEqual(try harness.prepare(requestID), .accepted)
        harness.executor.drainAll()
        harness.controller.complete(.begin, with: .ready)
        harness.trace.removeAll()

        XCTAssertEqual(try harness.finish(requestID), .accepted)
        harness.controller.onPreparationContextChange?(.deviceSetChanged(revision: 2))
        harness.executor.drainAll()

        XCTAssertEqual(
            harness.trace,
            ["remap.disable", "config.reload", "controller.update"]
        )
        harness.controller.complete(.update, with: .ready)
        XCTAssertEqual(harness.inactiveStates(for: requestID).map(\.reason), [.saved])
    }

    func testCoordinatorFinishRetriesVerificationAfterInFlightContextChange() throws {
        let harness = CoordinatorHarness(oneParticipant: coordinatorToken(78))
        let requestID = coordinatorRequest(78)
        XCTAssertEqual(try harness.prepare(requestID), .accepted)
        harness.executor.drainAll()
        harness.controller.complete(.begin, with: .ready)
        XCTAssertEqual(try harness.finish(requestID), .accepted)
        harness.executor.drainAll()

        harness.controller.onPreparationContextChange?(.deviceSetChanged(revision: 2))
        harness.controller.complete(.update, with: .failed(.deviceSetChanged))

        XCTAssertEqual(harness.controller.operations.map(\.kind), [.update])
        XCTAssertTrue(harness.inactiveStates(for: requestID).isEmpty)
        harness.controller.complete(.update, with: .ready)
        XCTAssertEqual(harness.inactiveStates(for: requestID).map(\.reason), [.saved])
    }

    func testCoordinatorFinishVerificationFailureKeepsBlockedLeaseAndNoSavedInactive() throws {
        let harness = CoordinatorHarness(oneParticipant: coordinatorToken(32))
        let requestID = coordinatorRequest(32)
        XCTAssertEqual(try harness.prepare(requestID), .accepted)
        harness.executor.drainAll()
        harness.controller.complete(.begin, with: .ready)
        XCTAssertEqual(try harness.finish(requestID), .accepted)
        harness.executor.drainAll()
        harness.controller.complete(.update, with: .failed(.conflict))

        XCTAssertTrue(harness.inactiveStates(for: requestID).isEmpty)
        XCTAssertTrue(harness.controller.clearOwners.isEmpty)
        XCTAssertEqual(harness.preparationResults(for: requestID).map(\.outcome), [.ready])
    }

    func testCoordinatorForwardsOnlyFirstRecordingFeedbackWithoutClosingAddMode() throws {
        let harness = CoordinatorHarness(oneParticipant: coordinatorToken(33))
        let requestID = coordinatorRequest(33)
        let feedback: NSDictionary = ["trigger": ["button": 6]]
        XCTAssertEqual(try harness.prepare(requestID), .accepted)
        harness.executor.drainAll()
        harness.coordinator.submitFeedback(feedback)
        XCTAssertTrue(harness.feedbackMessages.isEmpty)
        harness.controller.complete(.begin, with: .ready)
        harness.trace.removeAll()

        harness.coordinator.submitFeedback(feedback)
        harness.coordinator.submitFeedback(["trigger": ["button": 7]])

        harness.executor.drainAll()

        XCTAssertEqual(harness.feedbackMessages.count, 1)
        let sent = try XCTUnwrap(harness.feedbackMessages.single)
        let decoded = try M720AddModeFeedback.decode(sent.payload)
        XCTAssertEqual(decoded.requestID, requestID)
        XCTAssertTrue(decoded.feedback.isEqual(feedback))
        XCTAssertFalse(harness.trace.contains("remap.disable"))
    }

    func testCoordinatorMarshalsConcurrentFeedbackAndHonorsCancelAndFinishFences() throws {
        func submitConcurrently(
            to coordinator: M720AddModeCoordinator,
            count: Int = 16
        ) {
            let group = DispatchGroup()
            let queue = DispatchQueue(
                label: "M720AddModeIPCTests.feedback",
                attributes: .concurrent
            )
            for button in 0..<count {
                group.enter()
                queue.async {
                    coordinator.submitFeedback(["trigger": ["button": button]])
                    group.leave()
                }
            }
            XCTAssertEqual(group.wait(timeout: .now() + 2), .success)
        }

        do {
            let harness = CoordinatorHarness(oneParticipant: coordinatorToken(73))
            let requestID = coordinatorRequest(73)
            XCTAssertEqual(try harness.prepare(requestID), .accepted)
            harness.executor.drainAll()
            harness.controller.complete(.begin, with: .ready)
            harness.trace.removeAll()

            submitConcurrently(to: harness.coordinator)
            XCTAssertTrue(harness.feedbackMessages.isEmpty)
            XCTAssertEqual(try harness.cancel(requestID), .accepted)
            harness.executor.drainAll()

            XCTAssertTrue(harness.feedbackMessages.isEmpty)
            XCTAssertEqual(harness.controller.operations.map(\.kind), [.restore])
        }

        do {
            let harness = CoordinatorHarness(oneParticipant: coordinatorToken(74))
            let requestID = coordinatorRequest(74)
            XCTAssertEqual(try harness.prepare(requestID), .accepted)
            harness.executor.drainAll()
            harness.controller.complete(.begin, with: .ready)
            harness.trace.removeAll()

            submitConcurrently(to: harness.coordinator)
            XCTAssertTrue(harness.feedbackMessages.isEmpty)
            XCTAssertEqual(try harness.finish(requestID), .accepted)
            harness.executor.drainAll()

            XCTAssertTrue(harness.feedbackMessages.isEmpty)
            XCTAssertEqual(harness.controller.operations.map(\.kind), [.update])
        }

        do {
            let harness = CoordinatorHarness(oneParticipant: coordinatorToken(75))
            let requestID = coordinatorRequest(75)
            XCTAssertEqual(try harness.prepare(requestID), .accepted)
            harness.executor.drainAll()
            harness.controller.complete(.begin, with: .ready)
            harness.trace.removeAll()

            submitConcurrently(to: harness.coordinator)
            XCTAssertTrue(harness.feedbackMessages.isEmpty)
            harness.executor.drainAll()

            XCTAssertEqual(harness.feedbackMessages.count, 1)
        }
    }

    func testCoordinatorRawRoutesRejectMalformedSynchronouslyAndRetryCaptureExactlyOnce() throws {
        let harness = CoordinatorHarness(oneParticipant: coordinatorToken(34))
        XCTAssertEqual(
            try M720IPCAcknowledgement.decode(harness.coordinator.prepare(withPayload: "bad")),
            .rejected(.protocol)
        )
        XCTAssertEqual(
            try M720IPCAcknowledgement.decode(harness.coordinator.cancelPreparation(withPayload: nil)),
            .rejected(.protocol)
        )
        XCTAssertEqual(
            try M720IPCAcknowledgement.decode(harness.coordinator.renewLease(withPayload: "bad")),
            .rejected(.protocol)
        )
        XCTAssertEqual(
            try M720IPCAcknowledgement.decode(harness.coordinator.finishAddMode(withPayload: "bad")),
            .rejected(.protocol)
        )
        XCTAssertEqual(
            try M720IPCAcknowledgement.decode(harness.coordinator.retryCapture(withPayload: "bad")),
            .rejected(.protocol)
        )
        XCTAssertEqual(
            try M720IPCAcknowledgement.decode(harness.coordinator.captureStates(withPayload: "bad")),
            .rejected(.protocol)
        )
        XCTAssertTrue(harness.executor.blocks.isEmpty)

        let requestID = coordinatorRequest(34)
        let token = coordinatorToken(34)
        harness.controller.retryResults = [false, true]
        XCTAssertEqual(
            try harness.retry(requestID: requestID, token: token),
            .rejected(.disconnected)
        )
        XCTAssertEqual(try harness.retry(requestID: requestID, token: token), .accepted)
        XCTAssertEqual(harness.controller.retryCalls.count, 2)

        harness.controller.onStableStateChange?(M720ControllerSessionSnapshot(
            deviceToken: token,
            state: .active,
            errorCode: nil,
            requiredCIDs: [0x005B],
            requestID: requestID
        ))
        XCTAssertEqual(harness.captureStateMessages.count, 1)
        XCTAssertEqual(
            try M720CaptureState.decode(harness.captureStateMessages[0].payload).requestID,
            requestID
        )
    }

    func testCoordinatorCaptureSnapshotRouteIsReadOnlyAndStrict() throws {
        let token = coordinatorToken(35)
        let harness = CoordinatorHarness()
        harness.controller.stateSnapshots = [M720ControllerSessionSnapshot(
            deviceToken: token,
            state: .nativeReady,
            errorCode: nil,
            requiredCIDs: [],
            requestID: nil
        )]

        let payload = harness.coordinator.captureStates(withPayload: nil)
        XCTAssertEqual(try M720CaptureStates.decode(payload).states.map(\.deviceToken), [token])
        XCTAssertEqual(
            try M720IPCAcknowledgement.decode(
                harness.coordinator.captureStates(withPayload: [:] as NSDictionary)
            ),
            .rejected(.protocol)
        )
        XCTAssertTrue(harness.trace.isEmpty)
    }

    private func coordinatorRequest(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "30000000-0000-0000-0000-%012d", value))!
    }

    private func coordinatorToken(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "40000000-0000-0000-0000-%012d", value))!
    }
}

private final class CoordinatorHarness {
    let controller: CoordinatorFakeController
    let scheduler = CoordinatorManualScheduler()
    let executor = CoordinatorManualExecutor()
    var messages: [CoordinatorSentMessage] = []
    var trace: [String] = []
    var appDidTerminate: (() -> Void)?
    var generatedOwners: [UUID] = []
    private let messageLock = NSLock()

    lazy var coordinator = M720AddModeCoordinator(
        controller: controller,
        scheduler: scheduler,
        ownerFactory: { [unowned self] in
            let owner = UUID(uuidString: String(
                format: "50000000-0000-0000-0000-%012d",
                generatedOwners.count + 1
            ))!
            generatedOwners.append(owner)
            return owner
        },
        enqueueStart: { [unowned executor] block in executor.enqueue(block) },
        enableAddMode: { [unowned self] in
            trace.append("remap.enable")
            return true
        },
        disableAddMode: { [unowned self] in
            trace.append("remap.disable")
        },
        reloadSavedConfiguration: { [unowned self] in
            trace.append("config.reload")
        },
        sendMessage: { [unowned self] name, payload in
            messageLock.lock()
            defer { messageLock.unlock() }
            trace.append("send.\(name)")
            messages.append(CoordinatorSentMessage(name: name, payload: payload))
        },
        observeMainAppTermination: { [unowned self] action in
            appDidTerminate = action
        }
    )

    init(
        environmentEnabled: Bool = true,
        participants: [M720PreparationParticipant] = []
    ) {
        controller = CoordinatorFakeController(snapshot: M720PreparationSnapshot(
            deviceSetRevision: 1,
            environmentEnabled: environmentEnabled,
            participants: participants
        ))
        controller.trace = { [weak self] value in self?.trace.append(value) }
        _ = coordinator
    }

    convenience init(oneParticipant token: UUID) {
        self.init(participants: [M720PreparationParticipant(
            deviceToken: token,
            exactRequiredCIDs: [0x005B]
        )])
    }

    func prepare(_ requestID: UUID) throws -> M720IPCAcknowledgement {
        try M720IPCAcknowledgement.decode(coordinator.prepare(
            withPayload: M720IPCRequest(requestID: requestID).payload
        ))
    }

    func cancel(_ requestID: UUID) throws -> M720IPCAcknowledgement {
        try M720IPCAcknowledgement.decode(coordinator.cancelPreparation(
            withPayload: M720IPCRequest(requestID: requestID).payload
        ))
    }

    func renew(_ requestID: UUID) throws -> M720IPCAcknowledgement {
        try M720IPCAcknowledgement.decode(coordinator.renewLease(
            withPayload: M720IPCRequest(requestID: requestID).payload
        ))
    }

    func finish(_ requestID: UUID) throws -> M720IPCAcknowledgement {
        try M720IPCAcknowledgement.decode(coordinator.finishAddMode(
            withPayload: M720IPCRequest(requestID: requestID).payload
        ))
    }

    func retry(requestID: UUID, token: UUID) throws -> M720IPCAcknowledgement {
        try M720IPCAcknowledgement.decode(coordinator.retryCapture(
            withPayload: M720RetryCaptureRequest(
                requestID: requestID,
                deviceToken: token
            ).payload
        ))
    }

    func preparationResults(for requestID: UUID) -> [M720PreparationResult] {
        messages.compactMap { message in
            guard message.name == M720IPCMessage.preparationResult,
                  let decoded = try? M720PreparationResult.decode(message.payload),
                  decoded.requestID == requestID
            else { return nil }
            return decoded
        }
    }

    func inactiveStates(for requestID: UUID) -> [M720AddModeStateChange] {
        messages.compactMap { message in
            guard message.name == M720IPCMessage.addModeStateChanged,
                  let decoded = try? M720AddModeStateChange.decode(message.payload),
                  decoded.requestID == requestID
            else { return nil }
            return decoded
        }
    }

    var feedbackMessages: [CoordinatorSentMessage] {
        messages.filter { $0.name == "addModeFeedback" }
    }

    var captureStateMessages: [CoordinatorSentMessage] {
        messages.filter { $0.name == M720IPCMessage.captureStateChanged }
    }
}

private struct CoordinatorSentMessage {
    let name: String
    let payload: NSDictionary
}

private struct AddModeClientSentMessage {
    let name: String
    let payload: NSDictionary?
    let waitForReply: Bool
}

private final class AddModeClientManualTimer: M720AddModeClientTimer {
    let delay: TimeInterval
    let repeats: Bool
    let action: () -> Void
    private(set) var isCancelled = false

    init(delay: TimeInterval, repeats: Bool, action: @escaping () -> Void) {
        self.delay = delay
        self.repeats = repeats
        self.action = action
    }

    func cancel() { isCancelled = true }

    func fire() {
        guard !isCancelled else { return }
        action()
        if !repeats { isCancelled = true }
    }
}

private final class AddModeClientHarness {
    var now: TimeInterval = 0
    var reply: Any? = M720IPCAcknowledgement.accepted.payload
    private var requestIDs: [UUID]
    private var ipcBlocks: [() -> Void] = []
    private(set) var sentMessages: [AddModeClientSentMessage] = []
    private(set) var timers: [AddModeClientManualTimer] = []

    lazy var client = M720AddModeClient(
        requestIDFactory: { [unowned self] in self.requestIDs.removeFirst() },
        now: { [unowned self] in self.now },
        sendMessage: { [unowned self] name, payload, waitForReply in
            self.sentMessages.append(AddModeClientSentMessage(
                name: name,
                payload: payload,
                waitForReply: waitForReply
            ))
            return self.reply
        },
        executeIPC: { [unowned self] block in self.ipcBlocks.append(block) },
        executeMain: { block in block() },
        makeTimer: { [unowned self] delay, repeats, action in
            let timer = AddModeClientManualTimer(
                delay: delay,
                repeats: repeats,
                action: action
            )
            self.timers.append(timer)
            return timer
        }
    )

    init(requestIDs: [UUID]) {
        self.requestIDs = requestIDs
    }

    func drainIPC() {
        while !ipcBlocks.isEmpty {
            ipcBlocks.removeFirst()()
        }
    }

    func timer(delay: TimeInterval) -> AddModeClientManualTimer {
        guard let timer = timers.first(where: { $0.delay == delay && !$0.isCancelled }) else {
            fatalError("Missing active timer at delay \(delay)")
        }
        return timer
    }
}

private final class CoordinatorFakeController: M720AddModeController {
    struct Operation {
        enum Kind: Equatable { case begin, restore, update }

        let kind: Kind
        let ownerID: UUID
        let snapshot: M720PreparationSnapshot?
        let targetCIDs: Set<UInt16>?
        let completion: (M720TemporaryPolicyResult) -> Void
    }

    var onPreparationContextChange: ((M720PreparationContextChange) -> Void)?
    var onStableStateChange: ((M720ControllerSessionSnapshot) -> Void)?
    var snapshot: M720PreparationSnapshot
    var stateSnapshots: [M720ControllerSessionSnapshot] = []
    var operations: [Operation] = []
    var beginAccepted = true
    var restoreAccepted = true
    var updateAccepted = true
    var clearResults: [Bool] = [true]
    var clearOwners: [UUID] = []
    var retryResults: [Bool] = []
    var retryCalls: [(UUID, UUID)] = []
    var trace: ((String) -> Void)?

    init(snapshot: M720PreparationSnapshot) {
        self.snapshot = snapshot
    }

    func capturePreparationSnapshot() -> M720PreparationSnapshot { snapshot }

    func beginTemporaryPolicyLease(
        ownerID: UUID,
        snapshot: M720PreparationSnapshot,
        targetCIDs: Set<UInt16>,
        completion: @escaping (M720TemporaryPolicyResult) -> Void
    ) -> Bool {
        guard beginAccepted else { return false }
        trace?("controller.begin")
        operations.append(Operation(
            kind: .begin,
            ownerID: ownerID,
            snapshot: snapshot,
            targetCIDs: targetCIDs,
            completion: completion
        ))
        return true
    }

    func restoreTemporaryPolicyLease(
        ownerID: UUID,
        completion: @escaping (M720TemporaryPolicyResult) -> Void
    ) -> Bool {
        guard restoreAccepted else { return false }
        trace?("controller.restore")
        operations.append(Operation(
            kind: .restore,
            ownerID: ownerID,
            snapshot: nil,
            targetCIDs: nil,
            completion: completion
        ))
        return true
    }

    func updateTemporaryPolicyLeaseToCurrentSaved(
        ownerID: UUID,
        completion: @escaping (M720TemporaryPolicyResult) -> Void
    ) -> Bool {
        guard updateAccepted else { return false }
        trace?("controller.update")
        operations.append(Operation(
            kind: .update,
            ownerID: ownerID,
            snapshot: nil,
            targetCIDs: nil,
            completion: completion
        ))
        return true
    }

    func clearTemporaryPolicyLease(ownerID: UUID) -> Bool {
        trace?("controller.clear")
        clearOwners.append(ownerID)
        return clearResults.isEmpty ? true : clearResults.removeFirst()
    }

    func captureStateSnapshots() -> [M720ControllerSessionSnapshot] { stateSnapshots }

    func retryCapture(deviceToken: UUID, requestID: UUID?) -> Bool {
        guard let requestID else { return false }
        retryCalls.append((deviceToken, requestID))
        return retryResults.isEmpty ? false : retryResults.removeFirst()
    }

    func complete(_ kind: Operation.Kind, with result: M720TemporaryPolicyResult) {
        guard let completion = takeCompletion(kind) else { return }
        completion(result)
    }

    func takeCompletion(
        _ kind: Operation.Kind
    ) -> ((M720TemporaryPolicyResult) -> Void)? {
        guard let index = operations.firstIndex(where: { $0.kind == kind }) else {
            XCTFail("Missing \(kind) operation")
            return nil
        }
        let operation = operations.remove(at: index)
        return operation.completion
    }
}

private final class CoordinatorManualExecutor {
    private let lock = NSLock()
    private var storedBlocks: [() -> Void] = []

    var blocks: [() -> Void] {
        lock.lock()
        defer { lock.unlock() }
        return storedBlocks
    }

    func enqueue(_ block: @escaping () -> Void) {
        lock.lock()
        storedBlocks.append(block)
        lock.unlock()
    }

    func drainAll() {
        while true {
            lock.lock()
            guard !storedBlocks.isEmpty else {
                lock.unlock()
                return
            }
            let block = storedBlocks.removeFirst()
            lock.unlock()
            block()
        }
    }
}

private final class CoordinatorManualScheduler: M720AddModeScheduling {
    private final class Task: M720AddModeScheduledTask {
        let deadline: TimeInterval
        let order: Int
        let action: () -> Void
        var isCancelled = false
        var didFire = false

        init(deadline: TimeInterval, order: Int, action: @escaping () -> Void) {
            self.deadline = deadline
            self.order = order
            self.action = action
        }

        func cancel() { isCancelled = true }
    }

    private(set) var now: TimeInterval = 0
    private var nextOrder = 0
    private var tasks: [Task] = []

    func schedule(
        after delay: TimeInterval,
        action: @escaping () -> Void
    ) -> M720AddModeScheduledTask {
        nextOrder += 1
        let task = Task(deadline: now + delay, order: nextOrder, action: action)
        tasks.append(task)
        return task
    }

    func advance(by interval: TimeInterval) {
        now += interval
        while fireEarliestDueTask() {}
    }

    func advanceClock(by interval: TimeInterval) {
        now += interval
    }

    @discardableResult
    func fireEarliestDueTask() -> Bool {
        fireDueTask(latest: false)
    }

    @discardableResult
    func fireLatestDueTask() -> Bool {
        fireDueTask(latest: true)
    }

    private func fireDueTask(latest: Bool) -> Bool {
        let due = tasks
            .filter { !$0.isCancelled && !$0.didFire && $0.deadline <= now }
            .sorted {
                ($0.deadline, $0.order) < ($1.deadline, $1.order)
            }
        guard let task = latest ? due.last : due.first else { return false }
        task.didFire = true
        task.action()
        return true
    }
}

private extension Array {
    var single: Element? { count == 1 ? first : nil }
}
