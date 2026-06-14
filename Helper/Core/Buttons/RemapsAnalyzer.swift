//
// --------------------------------------------------------------------------
// RemapsAnalyzer.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021 (Swiftified in 2026)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Foundation

@objc class RemapsAnalyzer: NSObject {
    
    @objc static func reload() {
        // Caching is disabled by design. We keep this method for compatibility with SwitchMaster.swift.
    }
    
    @objc static func modificationsModifyButtons(_ modifications: NSDictionary, maxButton: Int32) -> Bool {
        for key in modifications.allKeys {
            if let btn = key as? NSNumber {
                let button = btn.intValue
                if button <= maxButton {
                    return true
                }
            }
        }
        return false
    }
    
    @objc static func modificationsModifyScroll(_ modifications: NSDictionary) -> Bool {
        return modifications.object(forKey: kMFTriggerScroll) != nil
    }
    
    @objc static func modificationsModifyPointing(_ modifications: NSDictionary) -> Bool {
        return modifications.object(forKey: kMFTriggerDrag) != nil
    }
    
    @objc static func assessMappingLandscape(
        withButton button: NSNumber,
        level: NSNumber,
        modificationsActingOnThisButton: NSDictionary,
        remaps: NSDictionary,
        thisClickDoBe clickActionOfThisLevelExists: UnsafeMutablePointer<ObjCBool>,
        thisDownDoBe effectForMouseDownStateOfThisLevelExists: UnsafeMutablePointer<ObjCBool>,
        greaterDoBe effectOfGreaterLevelExists: UnsafeMutablePointer<ObjCBool>
    ) {
        let buttonDict = modificationsActingOnThisButton[button] as? NSDictionary
        let levelDict = buttonDict?[level] as? NSDictionary
        
        clickActionOfThisLevelExists.pointee = ObjCBool(levelDict?[kMFButtonTriggerDurationClick] != nil)
        
        effectForMouseDownStateOfThisLevelExists.pointee = ObjCBool(effectExistsForMouseDownState(button: button, level: level, remaps: remaps, modificationsActingOnThisButton: modificationsActingOnThisButton))
        
        effectOfGreaterLevelExists.pointee = ObjCBool(effectOfGreaterLevelExistsFor(button: button, level: level, remaps: remaps, modificationsActingOnThisButton: modificationsActingOnThisButton))
    }
    
    private static func effectExistsForMouseDownState(button: NSNumber, level: NSNumber, remaps: NSDictionary, modificationsActingOnThisButton: NSDictionary) -> Bool {
        let buttonDict = modificationsActingOnThisButton[button] as? NSDictionary
        let levelDict = buttonDict?[level] as? NSDictionary
        let holdActionExists = levelDict?[kMFButtonTriggerDurationHold] != nil
        let usedAsModifier = isModifier(button: button, level: level, remaps: remaps)
        return holdActionExists || usedAsModifier
    }
    
    private static func isModifier(button: NSNumber, level: NSNumber, remaps: NSDictionary) -> Bool {
        for key in remaps.allKeys {
            if let modificationPrecondition = key as? NSDictionary,
               let buttons = modificationPrecondition[kMFModificationPreconditionKeyButtons] as? NSArray {
                for i in 0..<buttons.count {
                    if let dict = buttons[i] as? NSDictionary,
                       let btnNum = dict[kMFButtonModificationPreconditionKeyButtonNumber] as? NSNumber,
                       let btnLvl = dict[kMFButtonModificationPreconditionKeyClickLevel] as? NSNumber {
                        if btnNum.isEqual(to: button) && btnLvl.isEqual(to: level) {
                            return true
                        }
                    }
                }
            }
        }
        return false
    }
    
    private static func effectOfGreaterLevelExistsFor(button: NSNumber, level: NSNumber, remaps: NSDictionary, modificationsActingOnThisButton: NSDictionary) -> Bool {
        return maxLevel(forButton: button, remaps: remaps, modificationsActingOnThisButton: modificationsActingOnThisButton) > level.intValue
    }
    
    @objc static func maxLevel(forButton button: NSNumber, remaps: NSDictionary, modificationsActingOnThisButton: NSDictionary) -> Int {
        let a = maxLevelForButtonInModifications(button: button, modificationsActingOnThisButton: modificationsActingOnThisButton)
        let b = maxLevelForButtonInModificationPreconditions(button: button, remaps: remaps)
        return max(a, b)
    }
    
    private static func maxLevelForButtonInModifications(button: NSNumber, modificationsActingOnThisButton: NSDictionary) -> Int {
        var maxLvl = 0
        if let buttonDict = modificationsActingOnThisButton[button] as? NSDictionary {
            for key in buttonDict.allKeys {
                if let thisLevelNS = key as? NSNumber {
                    let thisLevel = thisLevelNS.intValue
                    if thisLevel > maxLvl {
                        maxLvl = thisLevel
                    }
                }
            }
        }
        return maxLvl
    }
    
    private static func maxLevelForButtonInModificationPreconditions(button: NSNumber, remaps: NSDictionary) -> Int {
        var maxLvl = 0
        for key in remaps.allKeys {
            if let modificationPrecondition = key as? NSDictionary,
               let buttonMods = modificationPrecondition[kMFModificationPreconditionKeyButtons] as? NSArray {
                var buttonIndex: Int?
                for i in 0..<buttonMods.count {
                    if let dict = buttonMods[i] as? NSDictionary,
                       let btnNum = dict[kMFButtonModificationPreconditionKeyButtonNumber] as? NSNumber,
                       btnNum.isEqual(to: button) {
                        buttonIndex = i
                        break
                    }
                }
                if let idx = buttonIndex,
                   let dict = buttonMods[idx] as? NSDictionary,
                   let precondLvlNS = dict[kMFButtonModificationPreconditionKeyClickLevel] as? NSNumber {
                    let precondLvl = precondLvlNS.intValue
                    if precondLvl > maxLvl {
                        maxLvl = precondLvl
                    }
                }
            }
        }
        return maxLvl
    }
    
    @objc static func effectExists(forButton button: NSNumber, remaps: NSDictionary, modificationsActingOnButton: NSDictionary) -> Bool {
        let hasDirectEffect = modificationsActingOnButton[button] != nil
        if hasDirectEffect {
            return true
        }
        for key in remaps.allKeys {
            if let modificationPrecondition = key as? [AnyHashable : Any] {
                if SharedUtility.button(button, isPartOfModificationPrecondition: modificationPrecondition) {
                    return true
                }
            }
        }
        return false
    }
}
