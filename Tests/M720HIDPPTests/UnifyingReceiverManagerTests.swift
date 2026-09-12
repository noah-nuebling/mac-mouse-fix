import Foundation
import IOKit
import XCTest
@testable import Mac_Mouse_Fix_Helper

final class UnifyingReceiverManagerTests: XCTestCase {
    func testPreparePreservesFlagsEnumeratesAllSlotsAndReturnsRealM720Identity() {
        let scheduler = ManualScheduler()
        let channel = ScriptedReceiverChannel()
        channel.pairedDevices = [
            1: (wirelessProductID: 0x405E, serialNumber: "9965E67C"),
            4: (wirelessProductID: 0x1234, serialNumber: "IGNORED000"),
        ]
        channel.notificationFlags = 0x080000
        let manager = UnifyingReceiverManager(channel: channel, scheduler: scheduler)
        let prepared = expectation(description: "receiver prepared")
        var result: Result<[M720UnifyingReceiverDevice], UnifyingReceiverManagerError>?

        manager.prepare { value in
            result = value
            prepared.fulfill()
        }
        wait(for: [prepared], timeout: 2)

        guard case let .success(devices)? = result else {
            XCTFail("receiver preparation failed: \(String(describing: result))")
            return
        }
        XCTAssertEqual(devices, [
            M720UnifyingReceiverDevice(
                slot: 1,
                wirelessProductID: 0x405E,
                serialNumber: "9965E67C"
            ),
        ])
        XCTAssertEqual(channel.notificationFlags, 0x080100)
        XCTAssertEqual(
            channel.requests.filter { $0.count == 7 && $0[2] == 0x83 && $0[3] == 0xB5 }
                .map { $0[4] },
            [0x20, 0x30, 0x21, 0x22, 0x23, 0x24, 0x25]
        )
        XCTAssertFalse(
            channel.requests.contains(try! UnifyingReceiverProtocol.extendedPairingInformationRequest(slot: 4)),
            "non-M720 slots must not be queried beyond their WPID"
        )
    }

    func testRequestsCurrentConnectionSnapshotAfterHandlerCanBeInstalled() {
        let channel = ScriptedReceiverChannel()
        let manager = UnifyingReceiverManager(
            channel: channel,
            scheduler: ManualScheduler()
        )
        let prepared = expectation(description: "prepared")
        manager.prepare { _ in prepared.fulfill() }
        wait(for: [prepared], timeout: 2)
        var delivered: [UnifyingReceiverLinkEvent] = []
        manager.onLinkEvent = { delivered.append($0) }
        channel.connectionSnapshotEvents = [
            .linkChanged(slot: 1, wirelessProductID: 0x405E, online: true),
        ]
        let requested = expectation(description: "snapshot requested")

        manager.requestConnectionSnapshot { result in
            if case let .failure(error) = result {
                XCTFail("snapshot request failed: \(error)")
            }
            requested.fulfill()
        }
        wait(for: [requested], timeout: 1)

        XCTAssertEqual(delivered, channel.connectionSnapshotEvents)
        XCTAssertEqual(
            channel.requests.last,
            UnifyingReceiverProtocol.notifyConnectedDevicesRequest()
        )
    }

    func testRestoreWritesOriginalFlagsOnlyWhenInstalledValueIsStillCurrent() {
        let channel = ScriptedReceiverChannel()
        channel.notificationFlags = 0x000004
        let manager = UnifyingReceiverManager(
            channel: channel,
            scheduler: ManualScheduler()
        )
        let prepared = expectation(description: "prepared")
        manager.prepare { _ in prepared.fulfill() }
        wait(for: [prepared], timeout: 2)
        XCTAssertEqual(channel.notificationFlags, 0x000104)
        let restored = expectation(description: "restored")

        manager.restoreNotificationFlags { result in
            if case let .failure(error) = result {
                XCTFail("flag restore failed: \(error)")
            }
            restored.fulfill()
        }
        wait(for: [restored], timeout: 1)

        XCTAssertEqual(channel.notificationFlags, 0x000004)
        XCTAssertEqual(
            Array(channel.requests.suffix(2)),
            [
                UnifyingReceiverProtocol.notificationFlagsReadRequest(),
                UnifyingReceiverProtocol.notificationFlagsWriteRequest(0x000004),
            ]
        )
    }

    func testRestoreDoesNotClobberFlagsChangedByAnotherProcess() {
        let channel = ScriptedReceiverChannel()
        let manager = UnifyingReceiverManager(
            channel: channel,
            scheduler: ManualScheduler()
        )
        let prepared = expectation(description: "prepared")
        manager.prepare { _ in prepared.fulfill() }
        wait(for: [prepared], timeout: 2)
        XCTAssertEqual(channel.notificationFlags, 0x000100)
        channel.notificationFlags = 0x000900
        let requestCountBeforeRestore = channel.requests.count
        let restored = expectation(description: "restore compare completed")

        manager.restoreNotificationFlags { result in
            if case let .failure(error) = result {
                XCTFail("flag comparison failed: \(error)")
            }
            restored.fulfill()
        }
        wait(for: [restored], timeout: 1)

        XCTAssertEqual(channel.notificationFlags, 0x000900)
        XCTAssertEqual(
            Array(channel.requests.dropFirst(requestCountBeforeRestore)),
            [UnifyingReceiverProtocol.notificationFlagsReadRequest()]
        )
    }

    func testForeignReceiverResponseIsIgnoredUntilExactSubregisterArrives() {
        let channel = ScriptedReceiverChannel()
        channel.injectForeignPairingResponseBeforeExact = true
        channel.pairedDevices = [
            1: (wirelessProductID: 0x405E, serialNumber: "9965E67C"),
        ]
        let manager = UnifyingReceiverManager(
            channel: channel,
            scheduler: ManualScheduler()
        )
        let prepared = expectation(description: "exact response wins")
        var devices: [M720UnifyingReceiverDevice] = []

        manager.prepare { result in
            devices = (try? result.get()) ?? []
            prepared.fulfill()
        }
        wait(for: [prepared], timeout: 2)

        XCTAssertEqual(devices.map(\.slot), [1])
    }

    func testRequestTimeoutAndInvalidationAreStable() {
        let scheduler = ManualScheduler()
        let channel = ScriptedReceiverChannel()
        channel.dropAllResponses = true
        let manager = UnifyingReceiverManager(channel: channel, scheduler: scheduler)
        let timedOut = expectation(description: "request timed out")
        var timeoutError: UnifyingReceiverManagerError?

        manager.prepare { result in
            if case let .failure(error) = result { timeoutError = error }
            timedOut.fulfill()
        }
        drainMainQueue()
        scheduler.advance(by: 1.0)
        wait(for: [timedOut], timeout: 1)
        XCTAssertEqual(timeoutError, .timeout)

        let invalidated = expectation(description: "manager invalidated")
        manager.invalidate { invalidated.fulfill() }
        wait(for: [invalidated], timeout: 1)
        XCTAssertEqual(channel.invalidateCallCount, 1)

        let rejected = expectation(description: "new request rejected")
        manager.prepare { result in
            XCTAssertEqual(result, .failure(.invalidated))
            rejected.fulfill()
        }
        wait(for: [rejected], timeout: 1)
    }

    private func drainMainQueue() {
        let drained = expectation(description: "main queue drained")
        DispatchQueue.main.async { drained.fulfill() }
        wait(for: [drained], timeout: 1)
    }
}

private final class ScriptedReceiverChannel: UnifyingReceiverChanneling {
    typealias Device = (wirelessProductID: UInt16, serialNumber: String)

    var onReceiverReport: ((Data) -> Void)?
    var onLinkEvent: ((UnifyingReceiverLinkEvent) -> Void)?
    var notificationFlags: UInt32 = 0
    var pairedDevices: [UInt8: Device] = [:]
    var connectionSnapshotEvents: [UnifyingReceiverLinkEvent] = []
    var injectForeignPairingResponseBeforeExact = false
    var dropAllResponses = false
    private(set) var requests: [Data] = []
    private(set) var invalidateCallCount = 0

    func sendReceiver(_ report: Data, completion: @escaping (IOReturn) -> Void) {
        requests.append(report)
        DispatchQueue.main.async {
            completion(kIOReturnSuccess)
            guard !self.dropAllResponses else { return }
            if self.injectForeignPairingResponseBeforeExact,
               report.count == 7,
               report[2] == 0x83,
               report[3] == 0xB5,
               (0x20...0x25).contains(report[4]) {
                var foreign = self.pairingResponse(
                    slot: report[4] == 0x25 ? 1 : report[4] - 0x1E,
                    device: (0x9999, "FOREIGN")
                )
                foreign[4] = report[4] == 0x25 ? 0x20 : report[4] + 1
                self.onReceiverReport?(Data(foreign))
            }
            guard let response = self.response(to: report) else { return }
            self.onReceiverReport?(response)
            if report == UnifyingReceiverProtocol.notifyConnectedDevicesRequest() {
                self.connectionSnapshotEvents.forEach { self.onLinkEvent?($0) }
            }
        }
    }

    func makeHIDPPSlotTransport(slot _: UInt8) -> HIDPPTransport? { nil }

    func invalidate(completion: @escaping () -> Void) {
        invalidateCallCount += 1
        onReceiverReport = nil
        onLinkEvent = nil
        DispatchQueue.main.async(execute: completion)
    }

    private func response(to report: Data) -> Data? {
        let bytes = [UInt8](report)
        guard bytes.count == 7 else { return nil }
        switch (bytes[2], bytes[3]) {
        case (0x81, 0x00):
            return Data([
                0x10, 0xFF, 0x81, 0x00,
                UInt8((notificationFlags >> 16) & 0xFF),
                UInt8((notificationFlags >> 8) & 0xFF),
                UInt8(notificationFlags & 0xFF),
            ])
        case (0x80, 0x00):
            notificationFlags = UInt32(bytes[4]) << 16 |
                UInt32(bytes[5]) << 8 |
                UInt32(bytes[6])
            return report
        case (0x80, 0x02):
            return report
        case (0x83, 0xB5):
            let subregister = bytes[4]
            if (0x20...0x25).contains(subregister) {
                let slot = subregister - 0x1F
                guard let device = pairedDevices[slot] else {
                    return Data([0x10, 0xFF, 0x8F, 0x83, 0xB5, 0x03, 0x00])
                }
                return Data(pairingResponse(slot: slot, device: device))
            }
            if (0x30...0x35).contains(subregister) {
                let slot = subregister - 0x2F
                guard let device = pairedDevices[slot] else {
                    return Data([0x10, 0xFF, 0x8F, 0x83, 0xB5, 0x03, 0x00])
                }
                return Data(extendedResponse(slot: slot, serial: device.serialNumber))
            }
            return nil
        default:
            return nil
        }
    }

    private func pairingResponse(slot: UInt8, device: Device) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 20)
        bytes[0] = 0x11
        bytes[1] = 0xFF
        bytes[2] = 0x83
        bytes[3] = 0xB5
        bytes[4] = 0x1F + slot
        bytes[7] = UInt8(device.wirelessProductID >> 8)
        bytes[8] = UInt8(device.wirelessProductID & 0xFF)
        return bytes
    }

    private func extendedResponse(slot: UInt8, serial: String) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 20)
        bytes[0] = 0x11
        bytes[1] = 0xFF
        bytes[2] = 0x83
        bytes[3] = 0xB5
        bytes[4] = 0x2F + slot
        let padded = serial.count == 8 ? serial : "00000000"
        for index in 0..<4 {
            let start = padded.index(padded.startIndex, offsetBy: index * 2)
            let end = padded.index(start, offsetBy: 2)
            bytes[5 + index] = UInt8(padded[start..<end], radix: 16) ?? 0
        }
        return bytes
    }
}
