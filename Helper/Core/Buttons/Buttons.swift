//
// --------------------------------------------------------------------------
// Buttons.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Cocoa

enum ButtonInputSource: Equatable {
    case coreGraphics
    case hidpp
}

struct ButtonInputContext {
    let device: Device
    let button: ButtonNumber
    let downNotUp: Bool
    let modifiers: NSDictionary
    let source: ButtonInputSource
    let systemEvent: CGEvent?

    init(
        device: Device,
        button: ButtonNumber,
        downNotUp: Bool,
        modifiers: NSDictionary,
        source: ButtonInputSource,
        systemEvent: CGEvent?
    ) {
        self.device = device
        self.button = button
        self.downNotUp = downNotUp
        self.modifiers = NSDictionary(dictionary: modifiers)
        self.source = source
        self.systemEvent = systemEvent
    }
}

struct ButtonInputKey: Hashable {
    let deviceIdentity: ObjectIdentifier
    let button: ButtonNumber

    init(device: Device, button: ButtonNumber) {
        deviceIdentity = ObjectIdentifier(device)
        self.button = button
    }
}

private struct ButtonCycleSnapshot {
    let modifiers: NSDictionary
    let modifications: NSDictionary
    let remaps: NSDictionary
    let maxClickLevel: Int
    let triggerCallback: ClickCycleTriggerCallback
}

@objc class Buttons: NSObject {
    private static let queueKey = DispatchSpecificKey<Void>()
    static let queue: DispatchQueue = {
        let queue = DispatchQueue(
            label: "com.nuebling.mac-mouse-fix.buttons",
            qos: .userInteractive,
            attributes: [],
            autoreleaseFrequency: .inherit,
            target: nil
        )
        queue.setSpecific(key: queueKey, value: ())
        return queue
    }()

    private static var clickCycle: ClickCycle?
    private static var buttonModifiers = ButtonModifiers()
    private static var capturedSnapshots: [ButtonInputKey: ButtonCycleSnapshot] = [:]
    private static var isInitialized = false
    private static var _useButtonModifiers = false

    @objc static var useButtonModifiers: Bool {
        get { onQueue { _useButtonModifiers } }
        set { onQueue { _useButtonModifiers = newValue } }
    }

    static var modifiers = NSDictionary()
    static var modifications = NSDictionary()
    static var maxClickLevel: Int = -1

    @objc static func handleInput(
        device: Device,
        button: NSNumber,
        downNotUp: Bool,
        event: CGEvent
    ) -> MFEventPassThroughEvaluation {
        onQueue {
            let context = ButtonInputContext(
                device: device,
                button: ButtonNumber(truncating: button),
                downNotUp: downNotUp,
                modifiers: NSDictionary(dictionary: Modifiers.modifiers(with: event)),
                source: .coreGraphics,
                systemEvent: event
            )
            return handleInputOnQueue(context)
        }
    }

    static func handleInput(_ context: ButtonInputContext) -> MFEventPassThroughEvaluation {
        onQueue {
            handleInputOnQueue(context)
        }
    }

    @objc static func cancelInput(
        device: Device,
        button: NSNumber,
        completion: @escaping () -> Void
    ) {
        onQueue {
            initializeIfNeeded()
            let key = ButtonInputKey(
                device: device,
                button: ButtonNumber(truncating: button)
            )
            capturedSnapshots.removeValue(forKey: key)
            clickCycle?.cancel(key: key)
            completion()
        }
    }

    @objc static func handleButtonHasHadDirectEffect(device: Device, button: NSNumber) {
        onQueue {
            handleButtonHasHadDirectEffectOnQueue(device: device, button: button)
        }
    }

    @objc static func handleButtonHasHadDirectEffect_Unsafe(device: Device, button: NSNumber) {
        onQueue {
            handleButtonHasHadDirectEffectOnQueue(device: device, button: button)
        }
    }

    @objc static func handleButtonHasHadEffectAsModifier(button: NSNumber) {
        onQueue {
            handleButtonHasHadEffectAsModifierOnQueue(button: button)
        }
    }

    @objc static func handleButtonHasHadEffectAsModifier_Unsafe(button: NSNumber) {
        onQueue {
            handleButtonHasHadEffectAsModifierOnQueue(button: button)
        }
    }

    private static func handleInputOnQueue(
        _ context: ButtonInputContext
    ) -> MFEventPassThroughEvaluation {
        initializeIfNeeded()

        if context.downNotUp {
            let snapshot = resolveSnapshot(for: context)
            return routeResolvedInput(
                context,
                snapshot: snapshot,
                updateActiveDevice: true
            )
        }

        return routeResolvedInput(
            context,
            snapshot: nil,
            updateActiveDevice: true
        )
    }

    private static func routeResolvedInput(
        _ context: ButtonInputContext,
        snapshot candidateSnapshot: ButtonCycleSnapshot?,
        updateActiveDevice: Bool
    ) -> MFEventPassThroughEvaluation {
        let key = ButtonInputKey(device: context.device, button: context.button)

        if context.downNotUp {
            guard let snapshot = candidateSnapshot, snapshot.maxClickLevel > 0 else {
                return passThroughEvaluation(for: context.source, captured: false)
            }

            if updateActiveDevice,
               clickCycle?.isActiveFor(device: context.device, button: context.button) != true {
                HelperState.shared.activeDevice = context.device
            }

            capturedSnapshots[key] = snapshot
            modifiers = snapshot.modifiers
            modifications = snapshot.modifications
            maxClickLevel = snapshot.maxClickLevel
            clickCycle?.handleClick(
                device: context.device,
                button: context.button,
                downNotUp: true,
                maxClickLevel: snapshot.maxClickLevel,
                triggerCallback: snapshot.triggerCallback
            )
            return passThroughEvaluation(for: context.source, captured: true)
        }

        guard let snapshot = capturedSnapshots[key] else {
            return passThroughEvaluation(for: context.source, captured: false)
        }

        clickCycle?.handleClick(
            device: context.device,
            button: context.button,
            downNotUp: false,
            maxClickLevel: snapshot.maxClickLevel,
            triggerCallback: snapshot.triggerCallback
        )
        capturedSnapshots.removeValue(forKey: key)
        return passThroughEvaluation(for: context.source, captured: true)
    }

    private static func resolveSnapshot(for context: ButtonInputContext) -> ButtonCycleSnapshot {
        let button = NSNumber(value: context.button)
        let resolvedModifiers = NSDictionary(dictionary: context.modifiers)
        let resolvedRemaps = NSDictionary(dictionary: Remap.remaps)
        let resolvedModifications = NSDictionary(
            dictionary: Remap.modifications(withModifiers: resolvedModifiers) ?? NSDictionary()
        )
        let resolvedMaxClickLevel = RemapsAnalyzer.maxLevel(
            forButton: button,
            remaps: resolvedRemaps,
            modificationsActingOnThisButton: resolvedModifications
        )

        return ButtonCycleSnapshot(
            modifiers: resolvedModifiers,
            modifications: resolvedModifications,
            remaps: resolvedRemaps,
            maxClickLevel: resolvedMaxClickLevel,
            triggerCallback: productionTriggerCallback(
                button: button,
                modifications: resolvedModifications,
                remaps: resolvedRemaps
            )
        )
    }

    private static func productionTriggerCallback(
        button: NSNumber,
        modifications: NSDictionary,
        remaps: NSDictionary
    ) -> ClickCycleTriggerCallback {
        { triggerPhase, clickLevel, device, buttonNumber, onRelease in
            if useButtonModifiers, triggerPhase == .press {
                buttonModifiers.update(
                    withButton: MFMouseButtonNumber(button.uint32Value),
                    clickLevel: clickLevel,
                    downNotUp: true
                )
                onRelease.append {
                    buttonModifiers.update(
                        withButton: MFMouseButtonNumber(button.uint32Value),
                        clickLevel: clickLevel,
                        downNotUp: false
                    )
                }
            }

            DDLogDebug(
                "triggerCallback - lvl: \(clickLevel), phase: \(triggerPhase), " +
                    "btn: \(buttonNumber), dev: \"\(device.name())\""
            )

            var clickActionOfThisLevelExists: ObjCBool = false
            var effectForMouseDownStateOfThisLevelExists: ObjCBool = false
            var effectOfGreaterLevelExists: ObjCBool = false
            RemapsAnalyzer.assessMappingLandscape(
                withButton: button,
                level: clickLevel as NSNumber,
                modificationsActingOnThisButton: modifications,
                remaps: remaps,
                thisClickDoBe: &clickActionOfThisLevelExists,
                thisDownDoBe: &effectForMouseDownStateOfThisLevelExists,
                greaterDoBe: &effectOfGreaterLevelExists
            )

            var map: [ClickCycleTriggerPhase: (String, MFActionPhase)] = [:]
            if clickActionOfThisLevelExists.boolValue {
                if effectOfGreaterLevelExists.boolValue {
                    map[.levelExpired] = ("click", kMFActionPhaseCombined)
                } else if effectForMouseDownStateOfThisLevelExists.boolValue {
                    map[.release] = ("click", kMFActionPhaseCombined)
                } else {
                    map[.press] = ("click", kMFActionPhaseStart)
                }
            }
            if effectForMouseDownStateOfThisLevelExists.boolValue {
                map[.hold] = ("hold", kMFActionPhaseStart)
            }

            guard
                let (duration, startOrEnd) = map[triggerPhase],
                let levelMap = modifications.object(forKey: button) as? NSDictionary,
                let durationMap = levelMap.object(forKey: clickLevel) as? NSDictionary,
                let actionArray = durationMap.object(forKey: duration) as? NSArray
            else {
                return
            }

            TrialCounter.shared.handleUse()
            if startOrEnd == kMFActionPhaseCombined {
                Actions.executeActionArray(actionArray, phase: kMFActionPhaseCombined)
            } else if startOrEnd == kMFActionPhaseStart {
                Actions.executeActionArray(actionArray, phase: kMFActionPhaseStart)
                onRelease.append {
                    DDLogDebug("triggerCallback - unconditionalRelease button \(button)")
                    Actions.executeActionArray(actionArray, phase: kMFActionPhaseEnd)
                }
            }

            handleButtonHasHadDirectEffect_Unsafe(device: device, button: button)
            Modifiers.handleModificationHasBeenUsed()
        }
    }

    private static func passThroughEvaluation(
        for source: ButtonInputSource,
        captured: Bool
    ) -> MFEventPassThroughEvaluation {
        guard !captured, source == .coreGraphics else {
            return kMFEventPassThroughRefusal
        }
        return kMFEventPassThroughApproval
    }

    private static func handleButtonHasHadDirectEffectOnQueue(
        device: Device,
        button: NSNumber
    ) {
        assert(isInitialized)
        if clickCycle?.isActiveFor(
            device: device,
            button: ButtonNumber(truncating: button)
        ) == true {
            clickCycle?.kill()
        }
        if useButtonModifiers {
            buttonModifiers.killButton(MFMouseButtonNumber(rawValue: button.uint32Value))
        }
    }

    private static func handleButtonHasHadEffectAsModifierOnQueue(button: NSNumber) {
        assert(isInitialized)
        if clickCycle?.isActiveFor(button: button) == true {
            clickCycle?.kill()
        }
    }

    private static func initializeIfNeeded() {
        guard !isInitialized else { return }
        clickCycle = ClickCycle(buttonQueue: queue)
        isInitialized = true
    }

    private static func onQueue<T>(_ body: () -> T) -> T {
        if DispatchQueue.getSpecific(key: queueKey) != nil {
            return body()
        }
        return queue.sync(execute: body)
    }

#if DEBUG
    static func unitTestReset(scheduler: HIDPPScheduler) {
        requireUnitTestRuntime()
        onQueue {
            clickCycle = ClickCycle(buttonQueue: queue, scheduler: scheduler)
            capturedSnapshots.removeAll()
            modifiers = NSDictionary()
            modifications = NSDictionary()
            maxClickLevel = -1
            useButtonModifiers = false
            isInitialized = true
        }
    }

    static func unitTestHandleResolved(
        _ context: ButtonInputContext,
        maxClickLevel: Int,
        triggerCallback: @escaping ClickCycleTriggerCallback
    ) -> MFEventPassThroughEvaluation {
        requireUnitTestRuntime()
        return onQueue {
            initializeIfNeeded()
            let snapshot = ButtonCycleSnapshot(
                modifiers: NSDictionary(dictionary: context.modifiers),
                modifications: NSDictionary(),
                remaps: NSDictionary(),
                maxClickLevel: maxClickLevel,
                triggerCallback: triggerCallback
            )
            return routeResolvedInput(
                context,
                snapshot: snapshot,
                updateActiveDevice: false
            )
        }
    }

    private static func requireUnitTestRuntime() {
        precondition(
            ProcessInfo.processInfo.environment["MMF_M720_UNIT_TESTING"] != nil,
            "Button test seams are only valid in the hosted test process"
        )
    }
#endif
}
