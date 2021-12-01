//
// --------------------------------------------------------------------------
// RemapsOverrider.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "RemapsOverrider.h"
#import "ModifierManager.h"
#import "DeviceManager.h"
#import "TransformationManager.h"

#import "SharedUtility.h"

@implementation RemapsOverrider
/// This class provides methods for obtaining combined remaps based on a remaps dict and some active modifiers.
///     These *combined* remaps are also sometimes called *effective remaps* or *remaps for current modifiers*
///     If this doesn't make sense, see an example of the remaps dict structure in TransformationManager.m

+ (MFEffectiveRemapsMethod _Nonnull)effectiveRemapsMethod_Override {
    /// Primitive remaps overriding method. Siimply takes the base (with an empty modification precondition) remaps and overrides it with the remaps which have a modificationPrecondition of exactly `activeModifiers`
    /// Returns a block
    ///     - Which takes 2 arguments: `remaps` and `activeModifiers`
    ///     - The block takes the default remaps (with an empty precondition) and overrides it with the remappings defined for a precondition of `activeModifiers`.
    
    return ^NSDictionary *(NSDictionary *remaps, NSDictionary *activeModifiers) {
        NSDictionary *effectiveRemaps = remaps[@{}];
        NSDictionary *remapsForActiveModifiers = remaps[activeModifiers];
        if ([activeModifiers isNotEqualTo:@{}]) {
            effectiveRemaps = [SharedUtility dictionaryWithOverridesAppliedFrom:[remapsForActiveModifiers copy] to:effectiveRemaps]; // Why do we do ` - copy` here?
        }
        return effectiveRemaps;
    };
}

+ (NSDictionary  * _Nonnull )remapsForCurrentlyActiveModifiers {
    /// Convenience method. Unused
    
    NSDictionary *activeModifiers = [ModifierManager getActiveModifiersForDevice:nil filterButton:nil event:nil];
    NSDictionary *remaps = TransformationManager.remaps;
    
    return RemapsOverrider.effectiveRemapsMethod_Override(remaps, activeModifiers);
    
}

@end
