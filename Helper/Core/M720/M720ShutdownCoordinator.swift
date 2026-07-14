import Foundation

@objcMembers
final class M720ShutdownCoordinator: NSObject {
    typealias Cleanup = (@escaping () -> Void) -> Void

    enum State: Equatable {
        case idle
        case running
        case finished(Bool)
    }

    static let shared = M720ShutdownCoordinator.production()

    private let scheduler: HIDPPScheduler
    private let cleanup: Cleanup

    private(set) var state: State = .idle
    private var completions: [(Bool) -> Void] = []
    private var deadline: HIDPPCancellation?

    @nonobjc
    init(
        scheduler: HIDPPScheduler,
        cleanup: @escaping Cleanup
    ) {
        self.scheduler = scheduler
        self.cleanup = cleanup
        super.init()
    }

    func beginShutdown(completion: @escaping (Bool) -> Void) {
        precondition(Thread.isMainThread, "M720 shutdown must begin on the main thread")

        switch state {
        case let .finished(result):
            completion(result)
        case .running:
            completions.append(completion)
        case .idle:
            state = .running
            completions = [completion]
            deadline = scheduler.schedule(after: 3) { [weak self] in
                self?.finish(false)
            }
            cleanup { [weak self] in
                self?.finish(true)
            }
        }
    }

    private func finish(_ result: Bool) {
        guard state == .running else { return }
        state = .finished(result)
        deadline?.cancel()
        deadline = nil

        let callbacks = completions
        completions.removeAll()
        callbacks.forEach { $0(result) }
    }

    private static func production() -> M720ShutdownCoordinator {
        M720ShutdownCoordinator(
            scheduler: DispatchHIDPPScheduler(),
            cleanup: { completion in
                M720AddModeCoordinator.shared.beginShutdown()
                M720HIDPPController.shared.shutdown(completion: completion)
            }
        )
    }
}

@objc(M720SignalShutdownWaiter)
final class M720SignalShutdownWaiter: NSObject {
    typealias Cleanup = (@escaping (Bool) -> Void) -> Void
    typealias MainDispatcher = (@escaping () -> Void) -> Void
    typealias Wait = (DispatchSemaphore, TimeInterval) -> Bool

    private static let timeout: TimeInterval = 3
    private let dispatchToMain: MainDispatcher
    private let wait: Wait

    @nonobjc
    init(
        dispatchToMain: @escaping MainDispatcher,
        wait: @escaping Wait
    ) {
        self.dispatchToMain = dispatchToMain
        self.wait = wait
        super.init()
    }

    @nonobjc
    func waitForCleanup(_ startCleanup: @escaping Cleanup) -> Bool {
        let finished = DispatchSemaphore(value: 0)
        dispatchToMain {
            startCleanup { _ in finished.signal() }
        }
        return wait(finished, Self.timeout)
    }

    @objc(waitForCleanup:)
    static func waitForCleanupInProduction(_ startCleanup: @escaping Cleanup) -> Bool {
        precondition(!Thread.isMainThread, "Signal cleanup must never wait on the main thread")
        let waiter = M720SignalShutdownWaiter(
            dispatchToMain: { DispatchQueue.main.async(execute: $0) },
            wait: { semaphore, timeout in
                semaphore.wait(
                    timeout: .now() + .milliseconds(Int(timeout * 1_000))
                ) == .success
            }
        )
        return waiter.waitForCleanup(startCleanup)
    }
}
