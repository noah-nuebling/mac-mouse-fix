//
// --------------------------------------------------------------------------
// ClickCycle.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Cocoa

enum ClickCycleTriggerPhase: Int {
    case none = -1
    case press = 0
    case hold = 1
    case levelExpired = 2
    case release = 3
    case releaseFromHold = 4
}

enum ClickCycleModifierPhase: Int {
    case none = -1
    case press = 0
    case release = 1
}

typealias ButtonNumber = Int
typealias ClickLevel = Int
typealias UnconditionalReleaseCallback = (() -> Void)
typealias ClickCycleTriggerCallback = (
    ClickCycleTriggerPhase,
    ClickLevel,
    Device,
    ButtonNumber,
    inout [UnconditionalReleaseCallback]
) -> Void
typealias ClickCycleModifierCallback = (
    ClickCycleModifierPhase,
    ClickLevel,
    Device,
    ButtonNumber
) -> Void

private enum ButtonPressState {
    case down
    case up
    case held
}

private struct ClickCycleState {
    let key: ButtonInputKey
    let generation: UInt64
    let device: Device
    var pressState: ButtonPressState
    var clickLevel: ClickLevel
    let levelExpiryDeadline: TimeInterval
    var downTimer: HIDPPCancellation?
    var upTimer: HIDPPCancellation?
}

final class ClickCycle: NSObject {
    let buttonQueue: DispatchQueue

    private let scheduler: HIDPPScheduler
    private var state: ClickCycleState?
    private var generations: [ButtonInputKey: UInt64] = [:]
    private var releaseCallbacks: [ButtonInputKey: [UnconditionalReleaseCallback]] = [:]

    convenience init(buttonQueue: DispatchQueue) {
        self.init(
            buttonQueue: buttonQueue,
            scheduler: DispatchHIDPPScheduler(queue: buttonQueue)
        )
    }

    init(buttonQueue: DispatchQueue, scheduler: HIDPPScheduler) {
        self.buttonQueue = buttonQueue
        self.scheduler = scheduler
        super.init()
    }

    func kill() {
        DDLogDebug("triggerCallback - kill")
        guard let current = state else { return }
        _ = advanceGeneration(for: current.key)
        cancelTimers(current)
        state = nil
    }

    func forceKill() {
        assertionFailure("forceKill() is not implemented")
    }

    func cancel(key: ButtonInputKey) {
        _ = advanceGeneration(for: key)

        if let current = state, current.key == key {
            cancelTimers(current)
            state = nil
        }

        drainReleaseCallbacks(for: key)
    }

    func waitingForRelease(device: Device, button: ButtonNumber) -> Bool {
        releaseCallbacks[ButtonInputKey(device: device, button: button)] != nil
    }

    func isActiveFor(device: Device, button: ButtonNumber) -> Bool {
        state?.key == ButtonInputKey(device: device, button: button)
    }

    func isActiveFor(button: NSNumber) -> Bool {
        state?.key.button == ButtonNumber(truncating: button)
    }

    func handleClick(
        device: Device,
        button: ButtonNumber,
        downNotUp mouseDown: Bool,
        maxClickLevel: Int,
        triggerCallback: @escaping ClickCycleTriggerCallback
    ) {
        let key = ButtonInputKey(device: device, button: button)
        if mouseDown {
            handleDown(
                key: key,
                device: device,
                maxClickLevel: maxClickLevel,
                triggerCallback: triggerCallback
            )
        } else {
            handleUp(
                key: key,
                device: device,
                triggerCallback: triggerCallback
            )
        }
    }

    private func handleDown(
        key: ButtonInputKey,
        device: Device,
        maxClickLevel: Int,
        triggerCallback: @escaping ClickCycleTriggerCallback
    ) {
        precondition(maxClickLevel > 0)

        let previousClickLevel: ClickLevel
        if let current = state, current.key == key {
            previousClickLevel = current.clickLevel
            _ = advanceGeneration(for: key)
            cancelTimers(current)
            state = nil
        } else {
            previousClickLevel = 0
            kill()
        }

        let generation = advanceGeneration(for: key)
        let clickLevel = Math.intCycle(
            x: previousClickLevel + 1,
            lower: 1,
            upper: maxClickLevel
        )
        let expiryDeadline = scheduler.now + 0.26
        state = ClickCycleState(
            key: key,
            generation: generation,
            device: device,
            pressState: .down,
            clickLevel: clickLevel,
            levelExpiryDeadline: expiryDeadline,
            downTimer: nil,
            upTimer: nil
        )

        invokeTrigger(
            triggerCallback,
            phase: .press,
            clickLevel: clickLevel,
            device: device,
            key: key
        )

        guard isCurrent(key: key, generation: generation) else { return }
        scheduleHold(
            key: key,
            generation: generation,
            clickLevel: clickLevel,
            device: device,
            triggerCallback: triggerCallback
        )
        scheduleExpiry(
            key: key,
            generation: generation,
            clickLevel: clickLevel,
            device: device,
            deadline: expiryDeadline,
            triggerCallback: triggerCallback
        )
    }

    private func handleUp(
        key: ButtonInputKey,
        device: Device,
        triggerCallback: @escaping ClickCycleTriggerCallback
    ) {
        guard
            let current = state,
            current.key == key,
            current.pressState != .up
        else {
            drainReleaseCallbacks(for: key)
            return
        }

        let releaseFromHold = current.pressState == .held
        let generation = advanceGeneration(for: key)
        cancelTimers(current)
        state = ClickCycleState(
            key: key,
            generation: generation,
            device: device,
            pressState: .up,
            clickLevel: current.clickLevel,
            levelExpiryDeadline: current.levelExpiryDeadline,
            downTimer: nil,
            upTimer: nil
        )

        drainReleaseCallbacks(for: key)

        guard isCurrent(key: key, generation: generation) else { return }
        invokeTrigger(
            triggerCallback,
            phase: releaseFromHold ? .releaseFromHold : .release,
            clickLevel: current.clickLevel,
            device: device,
            key: key
        )

        guard isCurrent(key: key, generation: generation) else { return }
        if releaseFromHold {
            kill()
        } else {
            scheduleExpiry(
                key: key,
                generation: generation,
                clickLevel: current.clickLevel,
                device: device,
                deadline: current.levelExpiryDeadline,
                triggerCallback: triggerCallback
            )
        }
    }

    private func scheduleHold(
        key: ButtonInputKey,
        generation: UInt64,
        clickLevel: ClickLevel,
        device: Device,
        triggerCallback: @escaping ClickCycleTriggerCallback
    ) {
        let cancellation = scheduler.schedule(after: 0.25) { [weak self] in
            guard let self, self.isCurrent(key: key, generation: generation) else { return }

            self.invokeTrigger(
                triggerCallback,
                phase: .hold,
                clickLevel: clickLevel,
                device: device,
                key: key
            )

            guard self.isCurrent(key: key, generation: generation) else { return }
            self.state?.pressState = .held
            self.state?.upTimer?.cancel()
            self.state?.upTimer = nil
        }

        if isCurrent(key: key, generation: generation) {
            state?.downTimer = cancellation
        } else {
            cancellation.cancel()
        }
    }

    private func scheduleExpiry(
        key: ButtonInputKey,
        generation: UInt64,
        clickLevel: ClickLevel,
        device: Device,
        deadline: TimeInterval,
        triggerCallback: @escaping ClickCycleTriggerCallback
    ) {
        let remaining = max(0, deadline - scheduler.now)
        let cancellation = scheduler.schedule(after: remaining) { [weak self] in
            guard let self, self.isCurrent(key: key, generation: generation) else { return }

            self.invokeTrigger(
                triggerCallback,
                phase: .levelExpired,
                clickLevel: clickLevel,
                device: device,
                key: key
            )

            if self.isCurrent(key: key, generation: generation) {
                self.kill()
            }
        }

        if isCurrent(key: key, generation: generation) {
            state?.upTimer = cancellation
        } else {
            cancellation.cancel()
        }
    }

    private func invokeTrigger(
        _ triggerCallback: ClickCycleTriggerCallback,
        phase: ClickCycleTriggerPhase,
        clickLevel: ClickLevel,
        device: Device,
        key: ButtonInputKey
    ) {
        var callbacks: [UnconditionalReleaseCallback] = []
        triggerCallback(phase, clickLevel, device, key.button, &callbacks)
        if !callbacks.isEmpty {
            releaseCallbacks[key, default: []].append(contentsOf: callbacks)
        }
    }

    private func drainReleaseCallbacks(for key: ButtonInputKey) {
        let callbacks = releaseCallbacks.removeValue(forKey: key) ?? []
        callbacks.forEach { $0() }
    }

    private func cancelTimers(_ state: ClickCycleState) {
        state.downTimer?.cancel()
        state.upTimer?.cancel()
    }

    private func isCurrent(key: ButtonInputKey, generation: UInt64) -> Bool {
        state?.key == key &&
            state?.generation == generation &&
            generations[key] == generation
    }

    @discardableResult
    private func advanceGeneration(for key: ButtonInputKey) -> UInt64 {
        let generation = (generations[key] ?? 0) &+ 1
        generations[key] = generation
        return generation
    }
}
