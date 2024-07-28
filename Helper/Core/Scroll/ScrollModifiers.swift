//
// --------------------------------------------------------------------------
// ScrollModifiersSwift.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Cocoa


extension MFScrollModificationResult: Hashable {
    
    /// Make hashable so we can use this as dict key for cache
    
    public static func == (lhs: MFScrollModificationResult, rhs: MFScrollModificationResult) -> Bool {
        return lhs.inputMod == rhs.inputMod && lhs.effectMod == rhs.effectMod
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(inputMod.rawValue)
        hasher.combine(effectMod.rawValue)
    }
    
}

@objc class ScrollModifiers: NSObject {

    static var activeModifications = NSDictionary()
    
    @objc public static func currentModifications(event: CGEvent) -> MFScrollModificationResult {
        
        /// Debug
        
//        DDLogDebug("ScrollMods being evaluated...")
        
        /// Declare and init result
        
        let emptyResult = MFScrollModificationResult.init(inputMod: kMFScrollInputModificationNone,
                                                          effectMod: kMFScrollEffectModificationNone)
        var result = emptyResult
        
        /// Get currently active scroll remaps
        
//        let modifyingDevice: Device = HelperState.shared.activeDevice!;
        let activeModifiers = Modifiers.modifiers(with: event)
//        let baseRemaps = Remap.remaps;
        
        /// Debug
//        DDLogDebug("activeFlags in ScrollModifers: \(SharedUtility.binaryRepresentation((activeModifiers[kMFModificationPreconditionKeyKeyboard] as? NSNumber)?.uint32Value ?? 0))") /// This is unbelievably slow for some reason
        
        self.activeModifications = Remap.modifications(withModifiers: activeModifiers) ?? NSDictionary()
        
        guard let modifiedScrollDict = activeModifications[kMFTriggerScroll] else {
            return result; /// There are no active scroll modifications
        }
        guard let modifiedScrollDict = modifiedScrollDict as? NSDictionary else {
            assert(false) /// Invalid state
            return result;
        }
        
        /// Input modification
        
        if let inputModification = modifiedScrollDict[kMFModifiedScrollDictKeyInputModificationType] as? String {
                
            switch inputModification {
                
            case kMFModifiedScrollInputModificationTypePrecisionScroll:
                result.inputMod = kMFScrollInputModificationPrecise
            case kMFModifiedScrollInputModificationTypeQuickScroll:
                result.inputMod = kMFScrollInputModificationQuick
            default:
                fatalError("Unknown modifiedSrollDict type found in remaps")
            }
        }
        
        /// Effect modification
        
        if let effectModification = modifiedScrollDict[kMFModifiedScrollDictKeyEffectModificationType] as? String {
            
            switch effectModification {
                
            case kMFModifiedScrollEffectModificationTypeZoom:
                result.effectMod = kMFScrollEffectModificationZoom
            case kMFModifiedScrollEffectModificationTypeHorizontalScroll:
                result.effectMod = kMFScrollEffectModificationHorizontalScroll
            case kMFModifiedScrollEffectModificationTypeRotate:
                result.effectMod = kMFScrollEffectModificationRotate
            case kMFModifiedScrollEffectModificationTypeFourFingerPinch:
                result.effectMod = kMFScrollEffectModificationFourFingerPinch
            case kMFModifiedScrollEffectModificationTypeCommandTab:
                result.effectMod = kMFScrollEffectModificationCommandTab
            case kMFModifiedScrollEffectModificationTypeThreeFingerSwipeHorizontal:
                result.effectMod = kMFScrollEffectModificationThreeFingerSwipeHorizontal
            case kMFModifiedScrollEffectModificationTypeAddModeFeedback:
                result.effectMod = kMFScrollEffectModificationAddModeFeedback
            default:
                fatalError("Unknown modifiedSrollDict type found in remaps")
            }
        }
        
        /// Feedback
        let resultIsEmpty = result.inputMod == emptyResult.inputMod && result.effectMod == emptyResult.effectMod
        if !resultIsEmpty {
            
            /// Notify modifiers
            Modifiers.handleModificationHasBeenUsed()
            
            /// Send addMode feedback
            if result.effectMod == kMFScrollEffectModificationAddModeFeedback {
                let payload = modifiedScrollDict.mutableCopy() as! NSMutableDictionary /// I think a shallow mutableCopy is enough
                payload.removeObject(forKey: kMFModifiedScrollDictKeyEffectModificationType)
                Remap.sendAddModeFeedback(payload)
            }
        }
        
        /// Debiug
        
//        DDLogDebug("ScrollMods: \(result.input), \(result.effect)")
        
        ///  Return
        
        return result
    
    }
    
//    @objc public static func reactToModiferChange(activeModifications: NSDictionary) {
//        /// This is called on every button press. Might be good to optimize this if it has any noticable performance impact.
//        
//        /// Deactivate app switcher - if appropriate
//        
//        let effectModKeyPath = "\(kMFTriggerScroll).\(kMFModifiedScrollDictKeyEffectModificationType)"
//        
//        let switcherActiveLastScroll = (self.activeModifications as NSDictionary).value(forKeyPath: effectModKeyPath) as? String == kMFModifiedScrollEffectModificationTypeCommandTab
//        let switcherActiveNow = activeModifications.value(forKeyPath: effectModKeyPath) as? String == kMFModifiedScrollEffectModificationTypeCommandTab
//        
//        if (switcherActiveLastScroll && !switcherActiveNow) {
//            /// AppSwitcher has been deactivated - notify Scroll.m
//            
//            Scroll.appSwitcherModificationHasBeenDeactivated();
//            self.activeModifications = activeModifications;
//        }
//    }
    
    /// Utility
    @objc static func scrollModsAreEqual(_ mods1: MFScrollModificationResult, other mods2: MFScrollModificationResult) -> Bool {
        return mods1.effectMod == mods2.effectMod && mods1.inputMod == mods2.inputMod
    }
    
}
