import Foundation
import IOKit.hid

struct UnifyingReceiverChannelTestHooks {
    let didCopyInputReport: () -> Void
    let didReleaseCallbackContext: () -> Void
    let didReleaseInputBuffer: () -> Void

    init(
        didCopyInputReport: @escaping () -> Void = {},
        didReleaseCallbackContext: @escaping () -> Void = {},
        didReleaseInputBuffer: @escaping () -> Void = {}
    ) {
        self.didCopyInputReport = didCopyInputReport
        self.didReleaseCallbackContext = didReleaseCallbackContext
        self.didReleaseInputBuffer = didReleaseInputBuffer
    }
}

final class UnifyingReceiverChannel {
    var onReceiverReport: ((Data) -> Void)?
    var onLinkEvent: ((UnifyingReceiverLinkEvent) -> Void)?

    private struct WeakSlotRoute {
        weak var transport: UnifyingReceiverSlotTransport?
        let token: UUID
    }

    private let io: HIDPPDeviceIO
    private let ioQueue: DispatchQueue
    private let sendGate = UnifyingReceiverSendGate()
    private var slotRoutes: [UInt8: WeakSlotRoute] = [:]
    private var inputBuffer: UnifyingReceiverInputBuffer?
    private var callbackContext: UnifyingReceiverCallbackContext?
    private var isInvalidated = false
    private var invalidationDrainStarted = false
    private var invalidationDrainFinished = false
    private var ioResourcesReleased = false
    private var invalidationWaiters: [() -> Void] = []

    init(
        io: HIDPPDeviceIO,
        ioQueue: DispatchQueue,
        testHooks: UnifyingReceiverChannelTestHooks = UnifyingReceiverChannelTestHooks()
    ) {
        dispatchPrecondition(condition: .onQueue(.main))
        self.io = io
        self.ioQueue = ioQueue

        let capacity = max(32, io.maximumInputReportSize)
        let inputBuffer = UnifyingReceiverInputBuffer(
            capacity: capacity,
            didRelease: testHooks.didReleaseInputBuffer
        )
        self.inputBuffer = inputBuffer
        let callbackContext = UnifyingReceiverCallbackContext(
            channel: self,
            bufferCapacity: capacity,
            didCopyInputReport: testHooks.didCopyInputReport,
            didRelease: testHooks.didReleaseCallbackContext
        )
        self.callbackContext = callbackContext
        io.registerInputReport(
            buffer: inputBuffer.pointer,
            length: inputBuffer.capacity,
            callback: unifyingReceiverInputReportCallback,
            context: Unmanaged.passUnretained(callbackContext).toOpaque()
        )
    }

    deinit {
        dispatchPrecondition(condition: .onQueue(.main))
        beginInvalidationIfNeeded()
        releaseIOResourcesIfNeeded()
    }

    func makeSlotTransport(slot: UInt8) -> UnifyingReceiverSlotTransport? {
        dispatchPrecondition(condition: .onQueue(.main))
        guard !isInvalidated,
              UnifyingReceiverProtocol.slotRange.contains(slot)
        else { return nil }

        if slotRoutes[slot]?.transport == nil {
            slotRoutes.removeValue(forKey: slot)
        }
        guard slotRoutes[slot] == nil else { return nil }

        let token = UUID()
        sendGate.activateSlot(token)
        let transport = UnifyingReceiverSlotTransport(
            slot: slot,
            token: token,
            channel: self
        )
        slotRoutes[slot] = WeakSlotRoute(transport: transport, token: token)
        return transport
    }

    func sendReceiver(
        _ report: Data,
        completion: @escaping (IOReturn) -> Void
    ) {
        guard Self.isReceiverReport(report),
              let ticket = sendGate.makeReceiverTicket()
        else {
            completeOnMain(
                Self.isReceiverReport(report) ? kIOReturnAborted : kIOReturnBadArgument,
                completion: completion
            )
            return
        }
        enqueueWrite(report, ticket: ticket, completion: completion)
    }

    func invalidate(completion: @escaping () -> Void) {
        dispatchPrecondition(condition: .onQueue(.main))
        if invalidationDrainFinished {
            DispatchQueue.main.async(execute: completion)
            return
        }
        invalidationWaiters.append(completion)
        guard !invalidationDrainStarted else { return }
        invalidationDrainStarted = true
        beginInvalidationIfNeeded()
        ioQueue.async { [self] in
            DispatchQueue.main.async { [self] in
                finishInvalidationDrain()
            }
        }
    }

    func invalidate() {
        invalidate(completion: {})
    }

    fileprivate func sendSlot(
        token: UUID,
        slot: UInt8,
        report: Data,
        completion: @escaping (IOReturn) -> Void
    ) {
        guard Self.isSlotReport(report, slot: slot),
              let ticket = sendGate.makeSlotTicket(token)
        else {
            completeOnMain(
                Self.isSlotReport(report, slot: slot) ? kIOReturnAborted : kIOReturnBadArgument,
                completion: completion
            )
            return
        }
        enqueueWrite(report, ticket: ticket, completion: completion)
    }

    fileprivate func removeSlot(
        slot: UInt8,
        token: UUID,
        completion: @escaping () -> Void
    ) {
        dispatchPrecondition(condition: .onQueue(.main))
        removeSlotRoute(slot: slot, token: token)
        ioQueue.async {
            DispatchQueue.main.async(execute: completion)
        }
    }

    fileprivate func abandonSlot(slot: UInt8, token: UUID) {
        dispatchPrecondition(condition: .onQueue(.main))
        removeSlotRoute(slot: slot, token: token)
    }

    fileprivate func deliver(_ report: Data, generation: UInt64) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard !isInvalidated else { return }
        let bytes = [UInt8](report)
        guard bytes.count >= 2 else { return }

        if bytes[1] == UnifyingReceiverProtocol.receiverDeviceIndex {
            onReceiverReport?(report)
            return
        }
        if bytes[0] == 0x10 {
            if let event = try? UnifyingReceiverProtocol.decodeLinkEvent(report) {
                onLinkEvent?(event)
            }
            return
        }
        guard bytes[0] == 0x11,
              let route = slotRoutes[bytes[1]],
              route.token == route.transport?.routeToken
        else { return }
        route.transport?.deliver(report)
    }

    private func enqueueWrite(
        _ report: Data,
        ticket: UnifyingReceiverSendGate.Ticket,
        completion: @escaping (IOReturn) -> Void
    ) {
        ioQueue.async { [self] in
            guard sendGate.beginWrite(ifCurrent: ticket) else {
                DispatchQueue.main.async { [self] in
                    withExtendedLifetime(self) {
                        completion(kIOReturnAborted)
                    }
                }
                return
            }
            let result = io.setOutputReport(
                reportID: CFIndex(report[0]),
                data: report
            )
            DispatchQueue.main.async { [self] in
                withExtendedLifetime(self) {
                    completion(result)
                }
            }
        }
    }

    private func removeSlotRoute(slot: UInt8, token: UUID) {
        sendGate.deactivateSlot(token)
        if slotRoutes[slot]?.token == token {
            slotRoutes.removeValue(forKey: slot)
        }
    }

    private func beginInvalidationIfNeeded() {
        guard !isInvalidated else { return }
        isInvalidated = true
        sendGate.invalidate()
        callbackContext?.invalidate()
        onReceiverReport = nil
        onLinkEvent = nil
        for route in slotRoutes.values {
            route.transport?.channelDidInvalidate()
        }
        slotRoutes.removeAll()
    }

    private func releaseIOResourcesIfNeeded() {
        guard !ioResourcesReleased else { return }
        ioResourcesReleased = true
        if let pointer = inputBuffer?.pointer,
           let capacity = inputBuffer?.capacity {
            io.unregisterInputReport(buffer: pointer, length: capacity)
        }
        callbackContext = nil
        inputBuffer = nil
    }

    private func finishInvalidationDrain() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard !invalidationDrainFinished else { return }
        releaseIOResourcesIfNeeded()
        invalidationDrainFinished = true
        let waiters = invalidationWaiters
        invalidationWaiters.removeAll()
        waiters.forEach { $0() }
    }

    private func completeOnMain(
        _ result: IOReturn,
        completion: @escaping (IOReturn) -> Void
    ) {
        DispatchQueue.main.async { completion(result) }
    }

    private static func isReceiverReport(_ report: Data) -> Bool {
        guard report.count == 7 || report.count == 20 else { return false }
        guard report[1] == UnifyingReceiverProtocol.receiverDeviceIndex else { return false }
        return (report.count == 7 && report[0] == 0x10) ||
            (report.count == 20 && report[0] == 0x11)
    }

    private static func isSlotReport(_ report: Data, slot: UInt8) -> Bool {
        report.count == 20 && report[0] == 0x11 && report[1] == slot
    }
}

final class UnifyingReceiverSlotTransport: HIDPPTransport {
    let deviceIndex: UInt8
    let acceptedResponseDeviceIndices: Set<UInt8>
    var onReport: ((Data) -> Void)?

    fileprivate let routeToken: UUID
    private let channel: UnifyingReceiverChannel
    private var invalidationStarted = false
    private var invalidationFinished = false
    private var invalidationWaiters: [() -> Void] = []

    fileprivate init(slot: UInt8, token: UUID, channel: UnifyingReceiverChannel) {
        deviceIndex = slot
        acceptedResponseDeviceIndices = [slot]
        routeToken = token
        self.channel = channel
    }

    deinit {
        dispatchPrecondition(condition: .onQueue(.main))
        if !invalidationStarted {
            channel.abandonSlot(slot: deviceIndex, token: routeToken)
        }
    }

    func send(_ report: Data, completion: @escaping (IOReturn) -> Void) {
        channel.sendSlot(
            token: routeToken,
            slot: deviceIndex,
            report: report,
            completion: completion
        )
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
        onReport = nil
        channel.removeSlot(
            slot: deviceIndex,
            token: routeToken
        ) { [weak self] in
            self?.finishInvalidation()
        }
    }

    fileprivate func deliver(_ report: Data) {
        guard !invalidationStarted else { return }
        onReport?(report)
    }

    fileprivate func channelDidInvalidate() {
        guard !invalidationFinished else { return }
        invalidationStarted = true
        invalidationFinished = true
        onReport = nil
        let waiters = invalidationWaiters
        invalidationWaiters.removeAll()
        waiters.forEach { $0() }
    }

    private func finishInvalidation() {
        guard !invalidationFinished else { return }
        invalidationFinished = true
        let waiters = invalidationWaiters
        invalidationWaiters.removeAll()
        waiters.forEach { $0() }
    }
}

private final class UnifyingReceiverInputBuffer {
    let pointer: UnsafeMutablePointer<UInt8>
    let capacity: Int
    private let didRelease: () -> Void

    init(capacity: Int, didRelease: @escaping () -> Void) {
        self.capacity = capacity
        self.didRelease = didRelease
        pointer = .allocate(capacity: capacity)
        pointer.initialize(repeating: 0, count: capacity)
    }

    deinit {
        pointer.deinitialize(count: capacity)
        pointer.deallocate()
        didRelease()
    }
}

private final class UnifyingReceiverCallbackContext {
    let bufferCapacity: Int
    private weak var channel: UnifyingReceiverChannel?
    private let lock = NSLock()
    private var generation: UInt64 = 0
    private let didCopyInputReport: () -> Void
    private let didRelease: () -> Void

    init(
        channel: UnifyingReceiverChannel,
        bufferCapacity: Int,
        didCopyInputReport: @escaping () -> Void,
        didRelease: @escaping () -> Void
    ) {
        self.channel = channel
        self.bufferCapacity = bufferCapacity
        self.didCopyInputReport = didCopyInputReport
        self.didRelease = didRelease
    }

    deinit {
        didRelease()
    }

    func didCopyReport() {
        didCopyInputReport()
    }

    func currentGeneration() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        return generation
    }

    func invalidate() {
        lock.lock()
        generation &+= 1
        channel = nil
        lock.unlock()
    }

    func deliver(_ report: Data, generation callbackGeneration: UInt64) {
        lock.lock()
        guard callbackGeneration == generation, let channel else {
            lock.unlock()
            return
        }
        lock.unlock()
        channel.deliver(report, generation: callbackGeneration)
    }
}

private let unifyingReceiverInputReportCallback: IOHIDReportCallback = {
    rawContext,
    result,
    _,
    _,
    reportID,
    report,
    reportLength in

    guard result == kIOReturnSuccess,
          reportLength > 0,
          let rawContext
    else { return }

    let context = Unmanaged<UnifyingReceiverCallbackContext>
        .fromOpaque(rawContext)
        .takeUnretainedValue()
    guard reportLength <= CFIndex(context.bufferCapacity) else { return }

    let copied = Data(bytes: report, count: Int(reportLength))
    context.didCopyReport()
    let callbackGeneration = context.currentGeneration()
    let expectedLength: Int
    switch reportID {
    case 0x10: expectedLength = 7
    case 0x11: expectedLength = 20
    default: return
    }
    guard copied.count == expectedLength,
          copied.first == UInt8(reportID)
    else { return }

    DispatchQueue.main.async { [weak context] in
        context?.deliver(copied, generation: callbackGeneration)
    }
}

private final class UnifyingReceiverSendGate {
    struct Ticket {
        let generation: UInt64
        let slotToken: UUID?
    }

    private let lock = NSLock()
    private var generation: UInt64 = 0
    private var invalidated = false
    private var activeSlotTokens: Set<UUID> = []

    func activateSlot(_ token: UUID) {
        lock.lock()
        if !invalidated {
            activeSlotTokens.insert(token)
        }
        lock.unlock()
    }

    func deactivateSlot(_ token: UUID) {
        lock.lock()
        activeSlotTokens.remove(token)
        lock.unlock()
    }

    func makeReceiverTicket() -> Ticket? {
        lock.lock()
        defer { lock.unlock() }
        guard !invalidated else { return nil }
        return Ticket(generation: generation, slotToken: nil)
    }

    func makeSlotTicket(_ token: UUID) -> Ticket? {
        lock.lock()
        defer { lock.unlock() }
        guard !invalidated, activeSlotTokens.contains(token) else { return nil }
        return Ticket(generation: generation, slotToken: token)
    }

    func beginWrite(ifCurrent ticket: Ticket) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !invalidated, ticket.generation == generation else { return false }
        guard let token = ticket.slotToken else { return true }
        return activeSlotTokens.contains(token)
    }

    func invalidate() {
        lock.lock()
        guard !invalidated else {
            lock.unlock()
            return
        }
        invalidated = true
        generation &+= 1
        activeSlotTokens.removeAll()
        lock.unlock()
    }
}
