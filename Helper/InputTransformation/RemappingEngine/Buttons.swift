//
// --------------------------------------------------------------------------
// Buttons.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

import Cocoa

@objc class Buttons: NSObject {

    static let clickCycle = ClickCycle()
    static let modifiers = ButtonModifiers()
    
    @objc static func handleButtonInputWithButton(device: Device, button: NSNumber, downNotUp mouseDown: Bool) -> MFEventPassThroughEvaluation {
        
        /// Get modifications
        
        let remaps = TransformationManager.remaps()
        var devID: NSNumber? = device.uniqueID()
        let modifiers = ModifierManager.getActiveModifiers(forDevice: &devID, filterButton: button, event: nil)
        /// ^ We wouldn't need to filter button if we changed the order of updating modifiers and sending triggers depending on mouseDown or mouseUp
        let modifications = RemapsOverrider.effectiveRemapsMethod()(remaps, modifiers)
        
        /// Decide passthrough
        let effectExists = ButtonLandscapeAssessor.effectExists(forButton: button, remaps: remaps, modificationsActingOnButton: modifications)
        if !effectExists {
            return kMFEventPassThroughApproval
        }
        
        /// Dispatch through clickCycle

        clickCycle.handleClick(device: device, button: ButtonNumber(truncating: button), downNotUp: mouseDown) { modifierPhase, clickLevel, device, buttonNumber in
            
            ///
            /// Update modifiers
            ///
            
            self.modifiers.update(device: device, button: ButtonNumber(truncating: button), clickLevel: clickLevel, downNotUp: mouseDown)
            
        } triggerCallback: { triggerPhase, clickLevel, device, buttonNumber in
            
            ///
            /// Send triggers
            ///
            
            /// Asses 'mappingLandscape'
            
            var clickActionOfThisLevelExists: ObjCBool = false
            var effectForMouseDownStateOfThisLevelExists: ObjCBool = false
            var effectOfGreaterLevelExists: ObjCBool = false
            
            ButtonLandscapeAssessor.assessMappingLandscape(withButton: button as NSNumber, level: clickLevel as NSNumber, modificationsActingOnThisButton: modifications, remaps: remaps, thisClickDoBe: &clickActionOfThisLevelExists, thisDownDoBe: &effectForMouseDownStateOfThisLevelExists, greaterDoBe: &effectOfGreaterLevelExists)
            
            /// Create trigger -> action map based on mappingLandscape
            
            var map: [ClickCycleTriggerPhase: (String, String)] = [:]
            
            if clickActionOfThisLevelExists.boolValue {
                if effectOfGreaterLevelExists.boolValue {
                    map[.levelExpired] = ("click", "combined")
                } else if effectForMouseDownStateOfThisLevelExists.boolValue {
                    map[.release] = ("click", "combined")
                    map[.releaseFromHold] = ("click", "combined")
                } else {
                    map[.press] = ("click", "start")
                    map[.release] = ("click", "end")
                    map[.releaseFromHold] = ("click", "end")
                    map[.cancel] = ("click", "end")
                    map[.cancelFromHold] = ("click", "end")
                }
            }
            
            if effectForMouseDownStateOfThisLevelExists.boolValue {
                map[.hold] = ("hold", "start")
                map[.releaseFromHold] = ("hold", "end")
                map[.cancelFromHold] = ("hold", "end")
            }
            
            /// Get action for current trigger
            ///     This code is horrible to write in Swift. Deal with remapsDict in Objc whenever possible
            
            /// Get actionArray
            guard let (duration, startOrEnd) = map[triggerPhase] else { return }
            let modifications = modifications as? [NSNumber: [NSNumber: [String: [Any]]]]
            guard let actionArray = modifications?[button]?[clickLevel as NSNumber]?[duration] else { return } /// click/hold action does exist for this button + level
            guard var actionArray = actionArray as? [[AnyHashable: Any]] else { return }
            
            /// Add modificationPrecondition info for addMode. See TransformationManager -> AddMode for context
            if actionArray[0][kMFActionDictKeyType] as! String == kMFActionDictTypeAddModeFeedback {
                actionArray[0][kMFRemapsKeyModificationPrecondition] = modifiers
            }
            
            /// Execute actionArray
            if startOrEnd == "start" || startOrEnd == "combined" {
                /// TODO: Make the `Action` class take `startOrEnd` param
                Actions.executeActionArray(actionArray)
            }
            
            /// Notify triggering button
            ///     TODO: Not sure this works
            self.handleButtonHasHadDirectEffect(device: device, button: button)
            
            /// Notify modifiers (Probably unnecessary, because the only modifiers that can be "deactivated" are buttons. And since there's only one clickCycle the other buttons should already be zombified)
            ModifierManager.handleModifiersHaveHadEffect(withDevice: device.uniqueID(), activeModifiers: modifiers)
        }

        return kMFEventPassThroughRefusal
    }
    
    @objc static func handleButtonHasHadDirectEffect(device: Device, button: NSNumber) {
        if self.clickCycle.isActiveFor(device: device.uniqueID(), button: button) {
            self.clickCycle.kill()
        }
        self.modifiers.kill(device: device, button: ButtonNumber(truncating: button))
    }
    
    @objc static func handleButtonHasHadEffectAsModifier(device: Device, button: NSNumber) {
        if self.clickCycle.isActiveFor(device: device.uniqueID(), button: button) {
            self.clickCycle.zombify()
        }
    }
    
}
