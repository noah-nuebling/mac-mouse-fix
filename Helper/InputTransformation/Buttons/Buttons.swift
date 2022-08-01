//
// --------------------------------------------------------------------------
// Buttons.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

/// TODO: Use the queue to make things thread safe.
///     (I don't think it matters though, because all the interaction with this class are naturally spaced out in time, so there's a very low chance of race conditions)

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
        
        /// Init
        if !isInitialized { coolInitialize() }
        
        /// Get modifications
        let remaps = TransformationManager.remaps() /// This is apparently super slow because Swift needs to convert the dict. Much slower than all the redundant buttonLandscapeAssessor calculations.
        var deviceOpt: Device? = device
        let modifiers = ModifierManager.getActiveModifiers(for: &deviceOpt, filterButton: button, event: event)
        /// ^ We wouldn't need to filter button if we changed the order of updating modifiers and sending triggers depending on mouseDown or mouseUp
        let modifications = RemapsOverrider.effectiveRemapsMethod()(remaps, modifiers)
        
        /// Decide passthrough
        let effectExists = ButtonLandscapeAssessor.effectExists(forButton: button, remaps: remaps, modificationsActingOnButton: modifications)
        if !effectExists {
            return kMFEventPassThroughApproval
        }
        
        /// Get max clickLevel
        ///     This recalculates some stuff from the main assessment. -> Consider restructuring
        var maxClickLevel = 0
        if mouseDown {
            maxClickLevel = ButtonLandscapeAssessor.maxLevel(forButton: button, remaps: remaps, modificationsActingOnThisButton: modifications)
        } /// On mouseUp, the clickCycle should ignore the maxClickLevel anyways
        
        /// Dispatch through clickCycle
        clickCycle.handleClick(device: device, button: ButtonNumber(truncating: button), downNotUp: mouseDown, maxClickLevel: maxClickLevel) { modifierPhase, clickLevel, device, buttonNumber in
            
            ///
            /// Update modifiers
            ///
            
            self.modifiers.update(device: device, button: ButtonNumber(truncating: button), clickLevel: clickLevel, downNotUp: mouseDown)
            
        } triggerCallback: { triggerPhase, clickLevel, device, buttonNumber in
            
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
            ///     The idea about the zombieRelease is that we still want to finish what we started, but not start anything new. So we still send the `end` triggers, but not the `combined` triggers when the release is zombified
            
            var map: [ClickCycleTriggerPhase: (String, String)] = [:]
            
            /// Map for click actions
            if clickActionOfThisLevelExists.boolValue {
                if effectOfGreaterLevelExists.boolValue {
                    map[.levelExpired]          = ("click", "combined")
                } else if effectForMouseDownStateOfThisLevelExists.boolValue {
                    map[.release]               = ("click", "combined")
                    map[.releaseFromHold]       = ("click", "combined")
                } else {
                    map[.press]                 = ("click", "start")
                    map[.release]               = ("click", "end")
                    map[.releaseFromHold]       = ("click", "end")
                    map[.zombieRelease]         = ("click", "end")
                    map[.zombieReleaseFromHold] = ("click", "end")
                }
            }
            
            /// Map for hold actions
            if effectForMouseDownStateOfThisLevelExists.boolValue {
                map[.hold]                  = ("hold", "start")
                map[.releaseFromHold]       = ("hold", "end")
                map[.zombieReleaseFromHold] = ("hold", "end")
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
            if startOrEnd == "start" || startOrEnd == "combined" {
                /// TODO: Make the `Action` class take `startOrEnd` param
                Actions.executeActionArray(actionArray)
            }
            
            /// Notify triggering button
            ///     This only necessary for .press and .release, because in all other cases, we already know that the clickCycle has already been killed.
            ///     In case of the zombified triggers it would be especially unnecessary, because the currently active clickCycle would be unrelated to the incoming trigger
            
            if triggerPhase == .press || triggerPhase == .release {
                self.handleButtonHasHadDirectEffect(device: device, button: button)
            }
            
            /// Notify modifiers
            ///     (Probably unnecessary, because the only modifiers that can be "deactivated" are buttons. And since there's only one clickCycle, any buttons modifying the current one should already be zombified)
//            ModifierManager.handleModifiersHaveHadEffect(with: device, activeModifiers: modifiers)
        }

        return kMFEventPassThroughRefusal
    }
    
    /// Effect feedback
    
    @objc static func handleButtonHasHadDirectEffect(device: Device, button: NSNumber) {
        
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
        
        /// Validate
        /// Might wanna `assert(buttonIsHeld)`
        assert(isInitialized)
        
        /// Do stuff
        if self.clickCycle.isActiveFor(device: device.uniqueID(), button: button) {
            self.clickCycle.kill()
        }
    }
    
    /// Interface for accessing submodules
    
    @objc static func getActiveButtonModifiers(devicePtr: UnsafeMutablePointer<Device?>) -> [[String: Int]] {
        
        var device = devicePtr.pointee
        let result = modifiers.getActiveButtonModifiersForDevice(device: &device)
        devicePtr.pointee = device
        return result
    }
    
}
