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

/// Interface

+ (MFEffectiveRemapsMethod _Nonnull)effectiveRemapsMethod {
    /// Primitive remaps overriding method. Siimply takes the base (with an empty modification precondition) remaps and overrides it with the remaps which have a modificationPrecondition of exactly `activeModifiers`
    /// Returns a block
    ///     - Which takes 2 arguments: `remaps` and `activeModifiers`
    ///     - The block takes the default remaps (with an empty precondition) and overrides it with the remappings defined for a precondition of `activeModifiers`.
    
//    return simpleOverride;
    return subsetOverride;
}

+ (NSDictionary  * _Nonnull)remapsForCurrentlyActiveModifiers {
    /// Convenience method. Unused
    
    NSDictionary *activeModifiers = [ModifierManager getActiveModifiersForDevice:nil filterButton:nil event:nil];
    NSDictionary *remaps = TransformationManager.remaps;
    
    return RemapsOverrider.effectiveRemapsMethod(remaps, activeModifiers);
    
}

/// Effective remaps methods

static NSDictionary *simpleOverride(NSDictionary *remaps, NSDictionary *activeModifiers) {

    NSDictionary *effectiveRemaps = remaps[@{}];
    NSDictionary *remapsForActiveModifiers = remaps[activeModifiers];
    if ([activeModifiers isNotEqualTo:@{}]) {
        effectiveRemaps = [SharedUtility dictionaryWithOverridesAppliedFrom:[remapsForActiveModifiers copy] to:effectiveRemaps]; // Why do we do ` - copy` here?
    }
    return effectiveRemaps;
}

static NSDictionary *subsetOverride(NSDictionary *remaps, NSDictionary *activeModifiers) {
    
    /// This allows combining modifiers
    /// Here's what it does
    ///     It takes all the modificationPreconditions from `remaps` that are a subset of `activeModifiers` and sorts them by how large of a subset they are
    ///     It then takes all the modification dicts of these modificationPreconditiions and overrides them into each other in the order of their modificationPreconditions size, from small to large
    /// TODO: ^ This desctiption is outdated. Update.
    
    /// Treat simple case separately for optimization
    
    if ([activeModifiers isEqual: @{}]) {
//        DDLogDebug(@"activeFlags in subsetOverride: %@", [SharedUtility binaryRepresentation:0]); /// Debug
        return remaps[@{}];
    }
    
    /// Debug
    
//    DDLogDebug(@"activeFlags in subsetOverride: %@", [SharedUtility binaryRepresentation:(int)activeFlags]);
    
    /// Filter out preconds that aren't a subset of activeModifiers
    
    NSMutableArray *preconds = [NSMutableArray array];
    
    for (NSDictionary *precond in remaps.allKeys) {
        if (isSubMod(activeModifiers, precond)) {
            [preconds addObject:precond];
        }
    }
    
    /// Get precond sizes
    
    NSMutableArray<NSDictionary *> *precondsAndSizes = [NSMutableArray array];
    
    for (NSDictionary *precond in preconds) {
        
        CGEventFlags flags = ((NSNumber *)precond[kMFModificationPreconditionKeyKeyboard]).unsignedLongLongValue;
        int64_t flagsSubsetSize = 0;
        while (flags != 0) {
            flagsSubsetSize += flags & 1;
            flags >>= 1;
        }
        
        NSArray *buttons = precond[kMFModificationPreconditionKeyButtons];
        int64_t buttonSubsequenceLength = buttons.count;
        
        [precondsAndSizes addObject:@{
            @"precond": precond,
            @"size": @(flagsSubsetSize + buttonSubsequenceLength),
        }];
    }
    
    /// Sort preconditions by size
    
    [precondsAndSizes sortUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
        NSNumber *size1 = obj1[@"size"];
        NSNumber *size2 = obj2[@"size"];
        return [size1 compare:size2];
    }];

    /// Filter out preconds that are subsets of other preconds
    
    NSMutableArray *preconds2 = [NSMutableArray array];
    
    for (int i = 0; i < precondsAndSizes.count; i++) {
        
        NSDictionary *precond = precondsAndSizes[i][@"precond"];
        
        BOOL isSubsetOfOtherPrecond = NO;
        
        for (int j = i+1; j < precondsAndSizes.count; j++) {
            
            NSDictionary *otherPrecond = precondsAndSizes[j][@"precond"];
            
            if (isSubMod(otherPrecond, precond)) {
                isSubsetOfOtherPrecond = YES;
                break;
            }
        }
        
        if (!isSubsetOfOtherPrecond) {
            [preconds2 addObject:precond];
        }
    }
    
    
    /// Apply modifications in order of their precond size
    
    NSDictionary *combinedModifications = [NSMutableDictionary dictionary];
    
    for (NSDictionary *precond in preconds2) {
        NSDictionary *modification = remaps[precond];
        combinedModifications = [SharedUtility dictionaryWithOverridesAppliedFrom:modification to:combinedModifications];
        /// ^ Would be more efficient to have an in-place override function for this
    }
    
    /// Debug
    
//    DDLogDebug(@"combinedModifications in subsetOverride: %@", combinedModifications);
    
    /// Return
    
    return combinedModifications;
}

/// SubsetOverrride helpers

BOOL isSubMod(NSDictionary *modifiers, NSDictionary *potentialSubModifiers) {
    
    /// Treat zero case separately
    ///     For optimtization
    
    if (potentialSubModifiers.count == 0) return YES;
    
    /// Keyboard flags
    
    CGEventFlags flags = ((NSNumber *)modifiers[kMFModificationPreconditionKeyKeyboard]).unsignedLongLongValue;
    CGEventFlags subFlags = ((NSNumber *)potentialSubModifiers[kMFModificationPreconditionKeyKeyboard]).unsignedLongLongValue;
    
    if (!isSubBits(flags, subFlags)) return NO;
    
    /// Buttons
    
    NSArray *buttons = modifiers[kMFModificationPreconditionKeyButtons];
    NSArray *subButtons = potentialSubModifiers[kMFModificationPreconditionKeyButtons];
    
    if (!isSubSequence(buttons, subButtons)) return NO;
    
    /// Is subSet!
    
    return YES;
}

BOOL isSubBits(int64_t bits, int64_t potentialSubBits) {
    return (potentialSubBits & bits) == potentialSubBits;
}

BOOL isSubSequence(NSArray *sequence, NSArray *potentialSubSequence) {
    
    /// Treat zero case separately for optimization
    
    if (potentialSubSequence.count == 0) return YES;
    
    /// Main logic
    
    int subIndex = 0;
    
    for (int index = 0; index < sequence.count; index++) {
        
        /// This loop is pretty siimple because we know that no button can occor in the sequence more than once
        ///     Otherwise it would be more involved to determine subsequence
        
        /// Break prematurely
        ///     for optimtization
        long subItemsLeft = potentialSubSequence.count - subIndex;
        long itemsLeft = sequence.count - index;
        if (subItemsLeft > itemsLeft) { /// potentialSubSequence can't be a subsequence of sequence
            return NO;
        };
        
        /// Get items
        ///     for checking equality
        NSDictionary *subItem = potentialSubSequence[subIndex];
        NSDictionary *item = sequence[index];
        
        /// Do logical things that make sense
        if ([subItem isEqual:item]) {
            subIndex++;
        } else {
            subIndex = 0;
        }
        
        /// Validate
        assert(!(subIndex > potentialSubSequence.count));
        
        /// Check if found subsequence
        if (subIndex == potentialSubSequence.count) {
            return YES;
        }
    }
    
    return NO;
}

@end
