//
// --------------------------------------------------------------------------
// Remap.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020 (Swift rewrite in 2026)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Foundation

@objc class Remap: NSObject {
    
    @objc static var _addModeIsEnabled: Bool = false
    
    @objc static var addModeIsEnabled: Bool {
        return _addModeIsEnabled
    }
    
    private static var _remaps: NSDictionary = NSDictionary()
    
    @objc static var remaps: NSDictionary {
        return _remaps
    }
    
    private static var _swizzleCache = NSMutableDictionary()
    
    private static func setRemaps(_ remapsDict: NSDictionary) {
        let isEqual = _remaps.isEqual(remapsDict)
        if isEqual {
            DDLogDebug("Remaps were set to the same value")
        } else {
            _remaps = remapsDict
            _swizzleCache.removeAllObjects()
            SwitchMaster.shared.remapsChanged(remaps: _remaps)
            RemapsAnalyzer.reload()
            DDLogDebug("Set remaps to: \(_remaps)")
        }
    }
    
    @objc public static func reload() {
        DDLogDebug("TRM set remaps to config")
        
        if _addModeIsEnabled {
            _addModeIsEnabled = false
        }
        
        let remapsDict = NSMutableDictionary()
        
        if let scrollKillSwitch = Config.configForKeyPath("General.scrollKillSwitch") as? Bool, scrollKillSwitch {
            // Disabled keyboard mods when scrollKillSwitch is on
        } else {
            let horizontal = (Config.configForKeyPath("Scroll.modifiers.horizontal") as? NSNumber)?.uintValue ?? 0
            let zoom = (Config.configForKeyPath("Scroll.modifiers.zoom") as? NSNumber)?.uintValue ?? 0
            let swift = (Config.configForKeyPath("Scroll.modifiers.swift") as? NSNumber)?.uintValue ?? 0
            let precise = (Config.configForKeyPath("Scroll.modifiers.precise") as? NSNumber)?.uintValue ?? 0
            
            if horizontal != 0 {
                let precondition = [kMFModificationPreconditionKeyKeyboard: NSNumber(value: horizontal)] as NSDictionary
                let effect = [kMFTriggerScroll: [kMFModifiedScrollDictKeyEffectModificationType: kMFModifiedScrollEffectModificationTypeHorizontalScroll]] as NSDictionary
                remapsDict.setObject(effect, forCoolKeyArray: [precondition])
            }
            if zoom != 0 {
                let precondition = [kMFModificationPreconditionKeyKeyboard: NSNumber(value: zoom)] as NSDictionary
                let effect = [kMFTriggerScroll: [kMFModifiedScrollDictKeyEffectModificationType: kMFModifiedScrollEffectModificationTypeZoom]] as NSDictionary
                remapsDict.setObject(effect, forCoolKeyArray: [precondition])
            }
            if swift != 0 {
                let precondition = [kMFModificationPreconditionKeyKeyboard: NSNumber(value: swift)] as NSDictionary
                let effect = [kMFTriggerScroll: [kMFModifiedScrollDictKeyInputModificationType: kMFModifiedScrollInputModificationTypeQuickScroll]] as NSDictionary
                remapsDict.setObject(effect, forCoolKeyArray: [precondition])
            }
            if precise != 0 {
                let precondition = [kMFModificationPreconditionKeyKeyboard: NSNumber(value: precise)] as NSDictionary
                let effect = [kMFTriggerScroll: [kMFModifiedScrollDictKeyInputModificationType: kMFModifiedScrollInputModificationTypePrecisionScroll]] as NSDictionary
                remapsDict.setObject(effect, forCoolKeyArray: [precondition])
            }
        }
        
        if let remapsTable = Config.configForKeyPath(kMFConfigKeyRemaps) as? NSArray {
            for item in remapsTable {
                guard let tableEntry = item as? NSDictionary else { continue }
                guard let modificationPrecondition = tableEntry[kMFRemapsKeyModificationPrecondition] as? NSDictionary else { continue }
                guard let trigger = tableEntry[kMFRemapsKeyTrigger] else { continue }
                
                var triggerKeyArray: [Any] = []
                if let triggerStr = trigger as? String {
                    triggerKeyArray = [triggerStr]
                    assert(triggerStr == kMFTriggerScroll || triggerStr == kMFTriggerDrag, "")
                } else if let triggerDict = trigger as? NSDictionary {
                    let duration = triggerDict[kMFButtonTriggerKeyDuration] as? String ?? ""
                    let level = (triggerDict[kMFButtonTriggerKeyClickLevel] as? NSNumber) ?? NSNumber(value: 0)
                    let buttonNum = (triggerDict[kMFButtonTriggerKeyButtonNumber] as? NSNumber) ?? NSNumber(value: 0)
                    triggerKeyArray = [buttonNum, level, duration]
                } else {
                    assert(false, "")
                }
                
                var effect = tableEntry[kMFRemapsKeyEffect] as? NSObject
                if trigger is NSDictionary {
                    if let eff = effect {
                        effect = [eff] as NSArray
                    }
                }
                
                let keyArray = [modificationPrecondition] + triggerKeyArray
                remapsDict.setObject(effect, forCoolKeyArray: keyArray)
            }
        }
        
        self.setRemaps(remapsDict)
    }
    
    @objc public static func enableAddMode() -> Bool {
        DDLogDebug("TRM set remaps to addMode")
        
        let triggerToEffectDict = NSMutableDictionary()
        
        let dragDict = [
            kMFModifiedDragDictKeyType: kMFModifiedDragTypeAddModeFeedback,
            kMFRemapsKeyTrigger: kMFTriggerDrag
        ] as NSDictionary
        triggerToEffectDict[kMFTriggerDrag] = dragDict
        
        let scrollDict = [
            kMFModifiedScrollDictKeyEffectModificationType: kMFModifiedScrollEffectModificationTypeAddModeFeedback,
            kMFRemapsKeyTrigger: kMFTriggerScroll
        ] as NSDictionary
        triggerToEffectDict[kMFTriggerScroll] = scrollDict
        
        for btn in 1...Int(kMFMaxButtonNumber) {
            for lvl in 1...3 {
                for dur in [kMFButtonTriggerDurationClick, kMFButtonTriggerDurationHold] {
                    let addModeFeedbackDict = [
                        kMFActionDictKeyType: kMFActionDictTypeAddModeFeedback,
                        kMFRemapsKeyTrigger: [
                            kMFButtonTriggerKeyButtonNumber: NSNumber(value: btn),
                            kMFButtonTriggerKeyClickLevel: NSNumber(value: lvl),
                            kMFButtonTriggerKeyDuration: dur
                        ] as NSDictionary
                    ] as NSDictionary
                    
                    let feedbackArray = [addModeFeedbackDict] as NSArray
                    let keyArray = [NSNumber(value: btn), NSNumber(value: lvl), dur] as NSArray
                    triggerToEffectDict.setObject(feedbackArray, forCoolKeyArray: keyArray as! [Any])
                }
            }
        }
        
        _addModeIsEnabled = true
        
        let remapsWrapper = [
            NSDictionary(): triggerToEffectDict
        ] as NSDictionary
        
        self.setRemaps(remapsWrapper)
        return true
    }
    
    @objc public static func disableAddMode() -> Bool {
        if _addModeIsEnabled {
            self.reload()
        }
        return true
    }
    
    @objc public static func sendAddModeFeedback(_ payload: NSDictionary) {
        DDLogDebug("Concluding addMode with payload: \(payload)")
        if !self.addModePayloadIsValid(payload) {
            return
        }
        
        _ = MFMessagePort.sendMessage("addModeFeedback", withPayload: payload, waitForReply: false)
    }
    
    @objc public static func addModePayloadIsValid(_ payload: NSDictionary) -> Bool {
        if let trigger = payload[kMFRemapsKeyTrigger] as? String {
            if trigger == kMFTriggerDrag || trigger == kMFTriggerScroll {
                if let precond = payload[kMFRemapsKeyModificationPrecondition] as? NSDictionary {
                    let buttonPreconds = precond[kMFModificationPreconditionKeyButtons] as? [Any]
                    if buttonPreconds == nil || buttonPreconds?.count == 0 {
                        return false
                    }
                } else {
                    return false
                }
            }
        }
        return true
    }
    
    @objc public static func modifications(withModifiers modifiers: NSDictionary) -> NSDictionary? {
        if let cached = _swizzleCache[modifiers] as? NSDictionary {
            return cached
        } else {
            DDLogDebug("Recalculating modifications for modifiers: \(modifiers)")
            if let new = RemapSwizzler.swizzleRemaps(_remaps as! [AnyHashable : Any], activeModifiers: modifiers as! [AnyHashable : Any]) {
                let newDict = new as NSDictionary
                _swizzleCache[modifiers] = newDict
                return newDict
            }
            return nil
        }
    }
}
