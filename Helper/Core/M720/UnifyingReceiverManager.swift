import Foundation
import IOKit

protocol UnifyingReceiverChanneling: AnyObject {
    var onReceiverReport: ((Data) -> Void)? { get set }
    var onLinkEvent: ((UnifyingReceiverLinkEvent) -> Void)? { get set }

    func sendReceiver(_ report: Data, completion: @escaping (IOReturn) -> Void)
    func makeHIDPPSlotTransport(slot: UInt8) -> HIDPPTransport?
    func invalidate(completion: @escaping () -> Void)
}

extension UnifyingReceiverChannel: UnifyingReceiverChanneling {
    func makeHIDPPSlotTransport(slot: UInt8) -> HIDPPTransport? {
        makeSlotTransport(slot: slot) as UnifyingReceiverSlotTransport?
    }
}

struct M720UnifyingReceiverDevice: Equatable {
    let slot: UInt8
    let wirelessProductID: UInt16
    let serialNumber: String
}

protocol UnifyingReceiverManaging: AnyObject {
    var onLinkEvent: ((UnifyingReceiverLinkEvent) -> Void)? { get set }

    func prepare(
        completion: @escaping (
            Result<[M720UnifyingReceiverDevice], UnifyingReceiverManagerError>
        ) -> Void
    )
    func makeSlotTransport(slot: UInt8) -> HIDPPTransport?
    func requestConnectionSnapshot(
        completion: @escaping (Result<Void, UnifyingReceiverManagerError>) -> Void
    )
    func invalidate(completion: @escaping () -> Void)
}

enum UnifyingReceiverManagerError: Error, Equatable {
    case transport(IOReturn)
    case receiver(code: UInt8)
    case malformed
    case timeout
    case busy
    case invalidated
}

final class UnifyingReceiverManager: UnifyingReceiverManaging {
    var onLinkEvent: ((UnifyingReceiverLinkEvent) -> Void)? {
        get { channel.onLinkEvent }
        set { channel.onLinkEvent = newValue }
    }

    private let channel: UnifyingReceiverChanneling
    private let requests: UnifyingReceiverRequestPipeline
    private var originalNotificationFlags: UInt32?
    private var installedNotificationFlags: UInt32?
    private var notificationFlagsWereModified = false
    private var prepareInFlight = false
    private var invalidationStarted = false
    private var invalidationFinished = false
    private var invalidationWaiters: [() -> Void] = []

    init(channel: UnifyingReceiverChanneling, scheduler: HIDPPScheduler) {
        dispatchPrecondition(condition: .onQueue(.main))
        self.channel = channel
        requests = UnifyingReceiverRequestPipeline(
            channel: channel,
            scheduler: scheduler
        )
    }

    func prepare(
        completion: @escaping (
            Result<[M720UnifyingReceiverDevice], UnifyingReceiverManagerError>
        ) -> Void
    ) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard !invalidationStarted else {
            DispatchQueue.main.async { completion(.failure(.invalidated)) }
            return
        }
        guard !prepareInFlight else {
            DispatchQueue.main.async { completion(.failure(.busy)) }
            return
        }
        prepareInFlight = true

        if originalNotificationFlags != nil {
            enumerateM720Devices(slot: 1, found: []) { [weak self] result in
                self?.finishPrepare(result, completion: completion)
            }
            return
        }

        readNotificationFlags { [weak self] result in
            guard let self else { return }
            switch result {
            case let .success(flags):
                originalNotificationFlags = flags
                let installed = flags |
                    UnifyingReceiverProtocol.wirelessNotificationFlag
                installedNotificationFlags = installed
                guard installed != flags else {
                    enumerateM720Devices(slot: 1, found: []) { [weak self] result in
                        self?.finishPrepare(result, completion: completion)
                    }
                    return
                }
                writeNotificationFlags(installed) { [weak self] result in
                    guard let self else { return }
                    switch result {
                    case .success:
                        notificationFlagsWereModified = true
                        enumerateM720Devices(slot: 1, found: []) { [weak self] result in
                            self?.finishPrepare(result, completion: completion)
                        }
                    case let .failure(error):
                        finishPrepare(.failure(error), completion: completion)
                    }
                }
            case let .failure(error):
                finishPrepare(.failure(error), completion: completion)
            }
        }
    }

    func makeSlotTransport(slot: UInt8) -> HIDPPTransport? {
        dispatchPrecondition(condition: .onQueue(.main))
        guard !invalidationStarted else { return nil }
        return channel.makeHIDPPSlotTransport(slot: slot)
    }

    func requestConnectionSnapshot(
        completion: @escaping (Result<Void, UnifyingReceiverManagerError>) -> Void
    ) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard !invalidationStarted else {
            DispatchQueue.main.async { completion(.failure(.invalidated)) }
            return
        }
        let request = UnifyingReceiverProtocol.notifyConnectedDevicesRequest()
        requests.perform(
            request,
            matches: { Self.matchesShortResponse($0, request: request) },
            completion: { result in completion(result.map { _ in () }) }
        )
    }

    func restoreNotificationFlags(
        completion: @escaping (Result<Void, UnifyingReceiverManagerError>) -> Void
    ) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard !invalidationFinished else {
            DispatchQueue.main.async { completion(.failure(.invalidated)) }
            return
        }
        guard notificationFlagsWereModified,
              let original = originalNotificationFlags,
              let installed = installedNotificationFlags
        else {
            DispatchQueue.main.async { completion(.success(())) }
            return
        }

        readNotificationFlags { [weak self] result in
            guard let self else { return }
            switch result {
            case let .success(current) where current == installed:
                writeNotificationFlags(original) { [weak self] result in
                    if case .success = result {
                        self?.notificationFlagsWereModified = false
                    }
                    completion(result)
                }
            case .success:
                notificationFlagsWereModified = false
                completion(.success(()))
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }

    func invalidate(completion: @escaping () -> Void) {
        dispatchPrecondition(condition: .onQueue(.main))
        if invalidationFinished {
            DispatchQueue.main.async(execute: completion)
            return
        }
        invalidationWaiters.append(completion)
        guard !invalidationStarted else { return }
        invalidationStarted = true

        let finish: () -> Void = { [weak self] in
            guard let self else { return }
            requests.invalidate()
            channel.invalidate { [weak self] in
                self?.finishInvalidation()
            }
        }
        if notificationFlagsWereModified {
            restoreNotificationFlags { _ in finish() }
        } else {
            finish()
        }
    }

    private func finishPrepare(
        _ result: Result<[M720UnifyingReceiverDevice], UnifyingReceiverManagerError>,
        completion: @escaping (
            Result<[M720UnifyingReceiverDevice], UnifyingReceiverManagerError>
        ) -> Void
    ) {
        prepareInFlight = false
        completion(result)
    }

    private func enumerateM720Devices(
        slot: UInt8,
        found: [M720UnifyingReceiverDevice],
        completion: @escaping (
            Result<[M720UnifyingReceiverDevice], UnifyingReceiverManagerError>
        ) -> Void
    ) {
        guard UnifyingReceiverProtocol.slotRange.contains(slot) else {
            completion(.success(found.sorted { $0.slot < $1.slot }))
            return
        }

        let request: Data
        do {
            request = try UnifyingReceiverProtocol.pairingInformationRequest(slot: slot)
        } catch {
            completion(.failure(.malformed))
            return
        }
        requests.perform(
            request,
            matches: { Self.matchesReceiverInformation($0, subregister: 0x1F + slot) }
        ) { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(.receiver(code: 0x03)):
                enumerateM720Devices(
                    slot: slot + 1,
                    found: found,
                    completion: completion
                )
            case let .failure(error):
                completion(.failure(error))
            case let .success(response):
                let pairing: UnifyingReceiverPairingInformation
                do {
                    pairing = try UnifyingReceiverProtocol
                        .decodePairingInformation(response, slot: slot)
                } catch {
                    completion(.failure(.malformed))
                    return
                }
                guard pairing.wirelessProductID ==
                        M720Profile.unifyingWirelessProductID
                else {
                    enumerateM720Devices(
                        slot: slot + 1,
                        found: found,
                        completion: completion
                    )
                    return
                }
                readExtendedPairing(slot: slot) { [weak self] result in
                    guard let self else { return }
                    switch result {
                    case let .success(extended):
                        let device = M720UnifyingReceiverDevice(
                            slot: slot,
                            wirelessProductID: pairing.wirelessProductID,
                            serialNumber: extended.serialNumber
                        )
                        enumerateM720Devices(
                            slot: slot + 1,
                            found: found + [device],
                            completion: completion
                        )
                    case let .failure(error):
                        completion(.failure(error))
                    }
                }
            }
        }
    }

    private func readExtendedPairing(
        slot: UInt8,
        completion: @escaping (
            Result<UnifyingReceiverExtendedPairingInformation, UnifyingReceiverManagerError>
        ) -> Void
    ) {
        let request: Data
        do {
            request = try UnifyingReceiverProtocol
                .extendedPairingInformationRequest(slot: slot)
        } catch {
            completion(.failure(.malformed))
            return
        }
        requests.perform(
            request,
            matches: { Self.matchesReceiverInformation($0, subregister: 0x2F + slot) }
        ) { result in
            completion(result.flatMap { response in
                do {
                    return .success(try UnifyingReceiverProtocol
                        .decodeExtendedPairingInformation(response, slot: slot))
                } catch {
                    return .failure(.malformed)
                }
            })
        }
    }

    private func readNotificationFlags(
        completion: @escaping (Result<UInt32, UnifyingReceiverManagerError>) -> Void
    ) {
        let request = UnifyingReceiverProtocol.notificationFlagsReadRequest()
        requests.perform(
            request,
            matches: { Self.matchesShortResponse($0, request: request) }
        ) { result in
            completion(result.flatMap { response in
                do {
                    return .success(try UnifyingReceiverProtocol
                        .decodeNotificationFlags(response))
                } catch {
                    return .failure(.malformed)
                }
            })
        }
    }

    private func writeNotificationFlags(
        _ flags: UInt32,
        completion: @escaping (Result<Void, UnifyingReceiverManagerError>) -> Void
    ) {
        let request = UnifyingReceiverProtocol.notificationFlagsWriteRequest(flags)
        requests.perform(
            request,
            matches: { Self.matchesShortResponse($0, request: request) }
        ) { result in
            completion(result.map { _ in () })
        }
    }

    private func finishInvalidation() {
        guard !invalidationFinished else { return }
        invalidationFinished = true
        let waiters = invalidationWaiters
        invalidationWaiters.removeAll()
        waiters.forEach { $0() }
    }

    private static func matchesShortResponse(_ data: Data, request: Data) -> Bool {
        data.count == 7 &&
            data[0] == 0x10 && data[1] == 0xFF &&
            data[2] == request[2] && data[3] == request[3]
    }

    private static func matchesReceiverInformation(
        _ data: Data,
        subregister: UInt8
    ) -> Bool {
        data.count == 20 &&
            data[0] == 0x11 && data[1] == 0xFF &&
            data[2] == 0x83 && data[3] == 0xB5 &&
            data[4] == subregister
    }
}

private final class UnifyingReceiverRequestPipeline {
    private final class Request {
        let token: UInt64
        let report: Data
        let matches: (Data) -> Bool
        let completion: (Result<Data, UnifyingReceiverManagerError>) -> Void
        var timeoutCancellation: HIDPPCancellation?

        init(
            token: UInt64,
            report: Data,
            matches: @escaping (Data) -> Bool,
            completion: @escaping (Result<Data, UnifyingReceiverManagerError>) -> Void
        ) {
            self.token = token
            self.report = report
            self.matches = matches
            self.completion = completion
        }
    }

    private let channel: UnifyingReceiverChanneling
    private let scheduler: HIDPPScheduler
    private var pending: [Request] = []
    private var current: Request?
    private var nextToken: UInt64 = 0
    private var invalidated = false

    init(channel: UnifyingReceiverChanneling, scheduler: HIDPPScheduler) {
        self.channel = channel
        self.scheduler = scheduler
        channel.onReceiverReport = { [weak self] report in
            self?.handle(report)
        }
    }

    func perform(
        _ report: Data,
        matches: @escaping (Data) -> Bool,
        completion: @escaping (Result<Data, UnifyingReceiverManagerError>) -> Void
    ) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard !invalidated else {
            DispatchQueue.main.async { completion(.failure(.invalidated)) }
            return
        }
        let request = Request(
            token: nextToken,
            report: report,
            matches: matches,
            completion: completion
        )
        nextToken &+= 1
        pending.append(request)
        pump()
    }

    func invalidate() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard !invalidated else { return }
        invalidated = true
        channel.onReceiverReport = nil
        let active = current
        let queued = pending
        current = nil
        pending.removeAll()
        active?.timeoutCancellation?.cancel()
        active?.completion(.failure(.invalidated))
        queued.forEach { $0.completion(.failure(.invalidated)) }
    }

    private func pump() {
        guard !invalidated, current == nil, !pending.isEmpty else { return }
        let request = pending.removeFirst()
        current = request
        channel.sendReceiver(request.report) { [weak self, weak request] result in
            guard let self,
                  let request,
                  !invalidated,
                  current === request
            else { return }
            guard result == kIOReturnSuccess else {
                completeCurrent(.failure(.transport(result)))
                return
            }
            let token = request.token
            request.timeoutCancellation = scheduler.schedule(after: 1.0) { [weak self] in
                DispatchQueue.main.async { [weak self] in
                    guard let self,
                          !invalidated,
                          current?.token == token
                    else { return }
                    completeCurrent(.failure(.timeout))
                }
            }
        }
    }

    private func handle(_ report: Data) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard !invalidated, let request = current else { return }
        if let error = try? UnifyingReceiverProtocol.decodeError(report),
           error.command == request.report[2],
           error.address == request.report[3] {
            completeCurrent(.failure(.receiver(code: error.code)))
            return
        }
        guard request.matches(report) else { return }
        completeCurrent(.success(report))
    }

    private func completeCurrent(
        _ result: Result<Data, UnifyingReceiverManagerError>
    ) {
        guard let request = current else { return }
        request.timeoutCancellation?.cancel()
        current = nil
        request.completion(result)
        pump()
    }
}
