//
// --------------------------------------------------------------------------
// Buttons.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

/// TODO?: Use dispatchQueue.
///     I'm not sure the DispatchQueue is neccesary, because all the interaction with this class are naturally spaced out in time, so there's a very low chance of race conditions)

import Cocoa
import CocoaLumberjackSwift

@objc class Buttons: NSObject {
    
    /// Ivars
    static var queue: DispatchQueue = DispatchQueue(label: "com.nuebling.mac-mouse-fix.buttons", qos: .userInteractive, attributes: [], autoreleaseFrequency: .inherit, target: nil)
    static private var clickCycle = ClickCycle(buttonQueue: DispatchQueue(label: "replace this"))
    static private var modifiers = ButtonModifiers()
    
    /// Init
    private static var isInitialized = false
    private static func coolInitialize() {
        isInitialized = true
        clickCycle = ClickCycle(buttonQueue: queue)
    }
    
    /// Main interface
    
    @objc static func handleInput(device: Device, button: NSNumber, downNotUp mouseDown: Bool, event: CGEvent) -> MFEventPassThroughEvaluation {
        
        var passThroughEvaluation = kMFEventPassThroughRefusal
            
            /// Init
        if !isInitialized { coolInitialize() }
        
        /// Get modifications
        let remaps = TransformationManager.remaps() /// This is apparently super slow because Swift needs to convert the dict. Much slower than all the redundant buttonLandscapeAssessor calculations.
        var deviceAsOptional = device as Device?
        let modifiers = ModifierManager.getActiveModifiers(for: &deviceAsOptional, filterButton: button, event: event)
        /// ^ We wouldn't need to filter button if we changed the order of updating modifiers and sending triggers depending on mouseDown or mouseUp
        let modifications = RemapsOverrider.effectiveRemapsMethod()(remaps, modifiers)
        
        /// Decide passthrough
        let effectExists = ButtonLandscapeAssessor.effectExists(forButton: button, remaps: remaps, modificationsActingOnButton: modifications)
        let waitingForRelease = clickCycle.waitingForRelease(device: device, button: ButtonNumber(truncating: button))
        if !effectExists && !waitingForRelease { /// We could also check if an effect exists by checking maxClickLevel == 0
            passThroughEvaluation = kMFEventPassThroughApproval
            return kMFEventPassThroughApproval
        }
        
        /// Get max clickLevel
        ///     This recalculates some stuff from the main assessment. -> Consider restructuring
        var maxClickLevel = 0
        if mouseDown {
            maxClickLevel = ButtonLandscapeAssessor.maxLevel(forButton: button, remaps: remaps, modificationsActingOnThisButton: modifications)
        } /// On mouseUp, the clickCycle should ignore the maxClickLevel anyways
        
        /// Dispatch through clickCycle
        clickCycle.handleClick(device: device, button: ButtonNumber(truncating: button), downNotUp: mouseDown, maxClickLevel: maxClickLevel,
                               modifierCallback: { modifierPhase, clickLevel, device, buttonNumber in
            
            ///
            /// Update modifiers
            /// TODO: Consider merging this with the main callback and using the `releaseCallback` to make it work properly
                
            self.modifiers.update(device: device, button: ButtonNumber(truncating: button), clickLevel: clickLevel, downNotUp: mouseDown)
            
            /// Debug
            DDLogDebug("modifierCallback - lvl: \(clickLevel), phase: \(modifierPhase), btn: \(buttonNumber), dev: \"\(device.name())\"")
            
        }, triggerCallback: { triggerPhase, clickLevel, device, buttonNumber, releaseCallback in
            
            ///
            /// Send triggers
            ///
            
            /// Debug
            DDLogDebug("triggerCallback - lvl: \(clickLevel), phase: \(triggerPhase), btn: \(buttonNumber), dev: \"\(device.name())\"")
            
            /// Asses 'mappingLandscape'
            var clickActionOfThisLevelExists: ObjCBool = false
            var effectForMouseDownStateOfThisLevelExists: ObjCBool = false
            var effectOfGreaterLevelExists: ObjCBool = false
            
            ButtonLandscapeAssessor.assessMappingLandscape(withButton: button as NSNumber, level: clickLevel as NSNumber, modificationsActingOnThisButton: modifications, remaps: remaps, thisClickDoBe: &clickActionOfThisLevelExists, thisDownDoBe: &effectForMouseDownStateOfThisLevelExists, greaterDoBe: &effectOfGreaterLevelExists)
            
            /// Create trigger -> action map based on mappingLandscape
            ///     The idea about the releaseCallback is that we still want to finish what we started, but not start anything new if the clickCycle is killed
            
            var map: [ClickCycleTriggerPhase: (String, MFActionPhase)] = [:]
            
            /// Map for click actions
            if clickActionOfThisLevelExists.boolValue {
                if effectOfGreaterLevelExists.boolValue {
                    map[.levelExpired]          = ("click", kMFActionPhaseCombined)
                } else if effectForMouseDownStateOfThisLevelExists.boolValue {
                    map[.release]               = ("click", kMFActionPhaseCombined)
                    map[.releaseFromHold]       = ("click", kMFActionPhaseCombined)
                } else {
                    map[.press]                 = ("click", kMFActionPhaseStart)
                }
            }
            
            /// Map for hold actions
            if effectForMouseDownStateOfThisLevelExists.boolValue {
                map[.hold]                  = ("hold", kMFActionPhaseStart)
            }
            
            /// Get action for current trigger
            ///     This code is horrible to write in Swift. Deal with remapsDict in Objc whenever possible
            
            /// Get actionArray
            guard
                let (duration, startOrEnd) = map[triggerPhase],
                let m1 = modifications[button] as? [AnyHashable: Any],
                let m2 = m1[clickLevel as NSNumber] as? [AnyHashable: Any],
                let m3 = m2[duration],
                var actionArray = m3 as? [[AnyHashable: Any]] /// Not nil -> a click/hold action does exist for this button + level + duration
            else {
                return
            }
            
            /// Add modifiers to actionArray for addMode. See TransformationManager -> AddMode for context
            if actionArray[0][kMFActionDictKeyType] as! String == kMFActionDictTypeAddModeFeedback {
                var deviceOptional: Device? = device
                let realModifiers = ModifierManager.getActiveModifiers(for: &deviceOptional, filterButton: button as NSNumber, event: nil, despiteAddMode: true)
                actionArray[0][kMFRemapsKeyModificationPrecondition] = realModifiers
            }
            
            /// Execute actionArray
            if startOrEnd == kMFActionPhaseCombined {
                Actions.executeActionArray(actionArray, phase: kMFActionPhaseCombined)
            } else if startOrEnd == kMFActionPhaseStart {
                Actions.executeActionArray(actionArray, phase: kMFActionPhaseStart)
                releaseCallback = {
                    DDLogDebug("triggerCallback - unconditionalRelease button \(button)")
                    Actions.executeActionArray(actionArray, phase: kMFActionPhaseEnd)
                }
            }
            
            /// Notify triggering button
            ///     This not necessary for levelExpired and .releaseFromHold, because we already know that the clickCycle has beend killed
            ///     -> Might be better to make this an assert
            
            if triggerPhase != .levelExpired && triggerPhase != .releaseFromHold {
                self.handleButtonHasHadDirectEffect_Unsafe(device: device, button: button)
            }
            
            /// Notify modifiers
            ///     (Probably unnecessary, because the only modifiers that can be "deactivated" are buttons. And since there's only one clickCycle, any buttons modifying the current one should already be zombified)
            ModifierManager.handleModificationHasBeenUsed(with: device, activeModifiers: modifiers)
        })
        
        return passThroughEvaluation
    }
    
    
    /// Effect feedback
    
    @objc static func handleButtonHasHadDirectEffect(device: Device, button: NSNumber) {
        handleButtonHasHadDirectEffect_Unsafe(device: device, button: button)
    }
    
    @objc static func handleButtonHasHadDirectEffect_Unsafe(device: Device, button: NSNumber) {
        /// Validate
        /// Might wanna `assert(clickCycleIsActive)`
        assert(isInitialized)
        /// Do stuff
        if self.clickCycle.isActiveFor(device: device.uniqueID(), button: button) {
            self.clickCycle.kill()
        }
        self.modifiers.kill(device: device, button: ButtonNumber(truncating: button)) /// Not sure abt this
    }
    
    @objc static func handleButtonHasHadEffectAsModifier(device: Device, button: NSNumber) {
        handleButtonHasHadEffectAsModifier_Unsafe(device: device, button: button)
    }
    
    @objc static func handleButtonHasHadEffectAsModifier_Unsafe(device: Device, button: NSNumber) {
        /// Validate
        /// Might wanna `assert(buttonIsHeld)`
        assert(isInitialized)
        /// Do stuff
        if self.clickCycle.isActiveFor(device: device.uniqueID(), button: button) {
            self.clickCycle.kill()
        }
    }
    
    /// Interface for accessing submodules
    
    @objc static func getActiveButtonModifiers_Unsafe(devicePtr: UnsafeMutablePointer<Device?>) -> [[String: Int]] {
        var result: [[String: Int]] = []
        var device = devicePtr.pointee
        result = modifiers.getActiveButtonModifiersForDevice(device: &device)
        devicePtr.pointee = device
        return result
    }
    
}
