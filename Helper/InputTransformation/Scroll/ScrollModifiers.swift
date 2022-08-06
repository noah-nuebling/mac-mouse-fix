//
// --------------------------------------------------------------------------
// ScrollModifiersSwift.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

import Cocoa
import CocoaLumberjackSwift

@objc class ScrollModifiers: NSObject {

    static var activeModifications: Dictionary<AnyHashable, Any> = [:];
    
    @objc public static func currentModifications(event: CGEvent) -> MFScrollModificationResult {
        
        /// Debug
        
//        DDLogDebug("ScrollMods being evaluated...")
        
        /// Declare and init result
        
        let emptyResult = MFScrollModificationResult.init(inputMod: kMFScrollInputModificationNone,
                                                          effectMod: kMFScrollEffectModificationNone)
        var result = emptyResult
        
        /// Get currently active scroll remaps
        
        let modifyingDevice: Device = State.activeDevice!;
        let activeModifiers = ModifierManager.getActiveModifiers(for: modifyingDevice, filterButton: nil, event: event)
        let baseRemaps = TransformationManager.remaps();
        
        /// Debug
//        DDLogDebug("activeFlags in ScrollModifers: \(SharedUtility.binaryRepresentation((activeModifiers[kMFModificationPreconditionKeyKeyboard] as? NSNumber)?.uint32Value ?? 0))") /// This is unbelievably slow for some reason
        
        self.activeModifications = RemapsOverrider.effectiveRemapsMethod()(baseRemaps, activeModifiers);
        
        guard let modifiedScrollDictUntyped = activeModifications[kMFTriggerScroll] else {
            return result; /// There are no active scroll modifications
        }
        let modifiedScrollDict = modifiedScrollDictUntyped as! Dictionary<AnyHashable, Any>
        
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
                
                var payload = modifiedScrollDict
                payload.removeValue(forKey: kMFModifiedScrollDictKeyEffectModificationType)
                payload[kMFRemapsKeyModificationPrecondition] = NSMutableDictionary(dictionary: ModifierManager.getActiveModifiers(for: State.activeDevice!, filterButton: nil, event: event, despiteAddMode: true))
                /// ^ Need to use NSMutableDictionary, otherwise Swift will make it immutable and mainApp will crash trying to build this payload into its remapArray
                ModifierManager.handleModificationHasBeenUsed(with: modifyingDevice)
                TransformationManager.concludeAddMode(withPayload: payload)
                
            default:
                fatalError("Unknown modifiedSrollDict type found in remaps")
            }
        }
        
        /// Feedback
        let resultIsEmpty = result.inputMod == emptyResult.inputMod && result.effectMod == emptyResult.effectMod
        if !resultIsEmpty {
            ModifierManager.handleModificationHasBeenUsed(with: modifyingDevice, activeModifiers: activeModifiers)
        }
        
        /// Debiug
        
//        DDLogDebug("ScrollMods: \(result.input), \(result.effect)")
        
        ///  Return
        
        return result
    
    }
    
    @objc public static func reactToModiferChange(activeModifications: Dictionary<AnyHashable, Any>) {
        /// This is called on every button press. Might be good to optimize this if it has any noticable performance impact.
        
        /// Deactivate app switcher - if appropriate
        
        let effectModKeyPath = "\(kMFTriggerScroll).\(kMFModifiedScrollDictKeyEffectModificationType)"
        
        let switcherActiveLastScroll = (self.activeModifications as NSDictionary).value(forKeyPath: effectModKeyPath) as? String == kMFModifiedScrollEffectModificationTypeCommandTab
        let switcherActiveNow = (activeModifications as NSDictionary).value(forKeyPath: effectModKeyPath) as? String == kMFModifiedScrollEffectModificationTypeCommandTab
        
        if (switcherActiveLastScroll && !switcherActiveNow) {
            /// AppSwitcher has been deactivated - notify Scroll.m
            
            Scroll.appSwitcherModificationHasBeenDeactivated();
            self.activeModifications = activeModifications;
        }
    }
    
    /// Utility
    @objc static func scrollModsAreEqual(_ mods1: MFScrollModificationResult, other mods2: MFScrollModificationResult) -> Bool {
        return mods1.effectMod == mods2.effectMod && mods1.inputMod == mods2.inputMod
    }
    
}
