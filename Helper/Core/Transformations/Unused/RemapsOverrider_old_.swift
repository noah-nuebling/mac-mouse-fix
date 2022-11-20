//
// --------------------------------------------------------------------------
// RemapOverrider.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

/// This is the precursor to RemapSwizzler

/// Tried to do this in Swift, but it's way easier to just do in objc so we don't have to work around the Swift typesystem


import Foundation

@objc class RemapsOverrider: NSObject {
    /// Note: We've since moved this functionality to an Objc class, because we found these things are easier to do in Objc than in Swift
    ///     When we're dealing with this big nested unsafe data structure that is the remapDict, Swift typesystem and forced safety are just annoying.
    ///
    /// This class provides methods for obtaining combined remaps based on a remaps dict and some active modifiers.
    ///     These *combined* remaps are also sometimes called *effective remaps* or *remaps for current modifiers*
    ///     If this doesn't make sense, see an example of the remaps dict structure in TransformationManager.m
    
    
    @objc class func effectiveRemapsMethod() -> MFEffectiveRemapsMethod {
        /// Primitive remaps overriding method. Siimply takes the base (with an empty modification precondition) remaps and overrides it with the remaps which have a modificationPrecondition of exactly `activeModifiers`
        /// Returns a block
        ///     - Which takes 2 arguments: `remaps` and `activeModifiers`
        ///     - The block takes the default remaps (with an empty precondition) and overrides it with the remappings defined for a precondition of `activeModifiers`.
        
        return { (remaps: Dictionary<AnyHashable, Any>, activeModifiers: Dictionary<AnyHashable, Any>) -> Dictionary<AnyHashable, Any> in
            
            /// Convert to NS
            ///     Not sure how NSDictionary <-> Dictionary bridging works, so this might be bs. But I'm just trying to replicate the objc version
            
            let remapsNS = remaps as NSDictionary
            let activeModifiersNS = activeModifiers as NSDictionary
            let emptyDictNS = NSDictionary.init()
            
            let effectiveRemapsNS = remapsNS[emptyDictNS] as! NSDictionary
            var effectiveRemaps = effectiveRemapsNS as! [AnyHashable: Any] /// Swift type system stinky
            if activeModifiersNS.isNotEqual(to: emptyDictNS) {
                let remapsForActiveModifiersNS: NSDictionary? = (remapsNS[activeModifiersNS] as? NSDictionary)?.copy() as? NSDictionary
                if let activeMods = remapsForActiveModifiersNS {
                    let remapsForActiveModifiers: [AnyHashable: Any] = activeMods as! [AnyHashable: Any] /// I hate Swifts stupid type system so much
                    effectiveRemaps = SharedUtility.dictionaryWithOverridesApplied(from:remapsForActiveModifiers, to: effectiveRemaps)
                }
            }
            return effectiveRemaps
            
        }
        
        /// v Attempt at Swift implementation that uses Dictionary instead of casting between Dictionary and NSDictionary
        ///     This didn't work because you can't cast Dictionary to AnyHashable, so you can't use it as a key for a dictionary.... Swift is such a headache for so many thingsss.
        ///     The NSDictionary implementation is super duper cumbersome compared to the objc implementation.
        ///     Based on this, and because Swift is generally slower for most things than objc, I'll implement this class in objc instead.
        
//        return { (remaps: Dictionary<AnyHashable, Any>, activeModifiers: Dictionary<AnyHashable, Any>) -> Dictionary<AnyHashable, Any> in
//
//            let emptyDict: AnyHashable = ([:] as [AnyHashable:Any]) as! AnyHashable
//
//            /// Convert to NS
//            ///     Not sure how NSDictionary <-> Dictionary bridging works, so this might be bs. But I'm just trying to replicate the objc version
//
//            var effectiveRemaps = remaps[emptyDict] as! [AnyHashable: Any] /// Swift type system stinky
//            if !activeModifiers.isEmpty {
//                let remapsForActiveModifiers: Dictionary<AnyHashable, Any>? = remaps[(activeModifiers as! AnyHashable)] as? Dictionary
//                if let activeRemaps = remapsForActiveModifiers {
//                    let remapsForActiveModifiers: [AnyHashable: Any] = activeRemaps /// I hate Swifts stupid time system so much
//                    effectiveRemaps = SharedUtility.dictionaryWithOverridesApplied(from:remapsForActiveModifiers, to: effectiveRemaps)
//                }
//            }
//            return effectiveRemaps
//
//        }
        
            /// v Original objc implementation of the closure
            
//        ^NSDictionary *(NSDictionary *remaps, NSDictionary *activeModifiers) {
//            NSDictionary *effectiveRemaps = remaps[@{}];
//            NSDictionary *remapsForActiveModifiers = remaps[activeModifiers];
//            if ([activeModifiers isNotEqualTo:@{}]) {
//                effectiveRemaps = [SharedUtility dictionaryWithOverridesAppliedFrom:[remapsForActiveModifiers copy] to:effectiveRemaps]; // Why do we do ` - copy` here?
//            }
//            return effectiveRemaps;
//        };
    }
    
}
