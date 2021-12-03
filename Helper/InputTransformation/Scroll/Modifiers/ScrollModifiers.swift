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

    @objc class func currentScrollModifications() -> MFScrollModificationResult {
        
        /// Debug
        
//        DDLogDebug("ScrollMods being evaluated...")
        
        /// Declare and init result
        
        let emptyResult = MFScrollModificationResult.init(input: kMFScrollInputModificationNone,
                                                          effect: kMFScrollEffectModificationNone)
        var result = emptyResult
        
        /// Get currently active scroll remaps
        
        var modifyingDeviceID: NSNumber? = nil;
        let activeModifiers = ModifierManager.getActiveModifiers(forDevice: &modifyingDeviceID, filterButton: nil, event: nil)
        let baseRemaps = TransformationManager.remaps();
        
        let remapsForCurrentlyActiveModifiers = RemapsOverrider.effectiveRemapsMethod_Override()(baseRemaps, activeModifiers);
        
        guard let modifiedScrollDictUntyped = remapsForCurrentlyActiveModifiers[kMFTriggerScroll] else {
            return result; /// There are no active scroll modifications
        }
        let modifiedScrollDict = modifiedScrollDictUntyped as! Dictionary<AnyHashable, Any>
        
        /// Input modification
        
        if let inputModification = modifiedScrollDict[kMFModifiedScrollDictKeyInputModificationType] as? String {
                
            switch inputModification {
                
            case kMFModifiedScrollInputModificationTypePrecisionScroll:
                result.input = kMFScrollInputModificationPrecise
            case kMFModifiedScrollInputModificationTypeQuickScroll:
                result.input = kMFScrollInputModificationFast
            default:
                fatalError("Unknown modifiedSrollDict type found in remaps")
            }
        }
        
        /// Effect modification
        
        if let effectModification = modifiedScrollDict[kMFModifiedScrollDictKeyEffectModificationType] as? String {
            
            switch effectModification {
                
            case kMFModifiedScrollEffectModificationTypeZoom:
                result.effect = kMFScrollEffectModificationZoom
            case kMFModifiedScrollEffectModificationTypeHorizontalScroll:
                result.effect = kMFScrollEffectModificationHorizontalScroll
            case kMFModifiedScrollEffectModificationTypeRotate:
                result.effect = kMFScrollEffectModificationRotate
            case kMFModifiedScrollEffectModificationTypeFourFingerPinch:
                result.effect = kMFScrollEffectModificationFourFingerPinch
                
            case kMFModifiedScrollEffectModificationTypeAddModeFeedback:
                
                var payload = modifiedScrollDict
                payload.removeValue(forKey: kMFModifiedScrollDictKeyEffectModificationType)
                payload[kMFRemapsKeyModificationPrecondition] = NSMutableDictionary(dictionary: activeModifiers) /// Need to cast to mutable, otherwise Swift will make it immutable and mainApp will crash trying to build this payload into its remapArray
                TransformationManager.concludeAddMode(withPayload: payload)
                
            default:
                fatalError("Unknown modifiedSrollDict type found in remaps")
            }
        }
        
        /// Feedback
        let resultIsEmpty = result.input == emptyResult.input && result.effect == emptyResult.effect
        if !resultIsEmpty {
            ModifierManager.handleModifiersHaveHadEffect(withDevice: modifyingDeviceID, activeModifiers: activeModifiers)
            ModifiedDrag.modifiedScrollHasBeenUsed()
        }
        
        /// Debiug
        
//        DDLogDebug("ScrollMods: \(result.input), \(result.effect)")
        
        ///  Return
        
        return result
    
    }
}
