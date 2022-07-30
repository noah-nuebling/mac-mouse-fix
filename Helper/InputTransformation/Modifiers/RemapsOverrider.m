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

/// MARK: Interface

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

/// MARK: Effective remaps methods

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
    ///     Then It creates one new precond array for each triggerType and only puts in the preconds that have that triggerType in their modification
    ///     For each trigger-specific precond array it then filters out all the preconds that are a subset of another precond in that trigger-specific precond array
    ///     Then, for each trigger-specific precond array, it takes all the modification dicts of each precond and overrides them into each other in the order of their precond size, from small to large
    /// I'm too lazy and stupid to describe why all this abstract stuff makes sense, but it leads the button and keyboard modifiers to always do the intuitive thing that you expect them to imo!
    
    /// Treat simple case separately for optimization
    
    if ([activeModifiers isEqual: @{}]) {
//        DDLogDebug(@"activeFlags in subsetOverride: %@", [SharedUtility binaryRepresentation:0]); /// Debug
        return remaps[@{}];
    }
    
    /// Debug
    
//    DDLogDebug(@"activeFlags in subsetOverride: %@", [SharedUtility binaryRepresentation:(int)activeFlags]);
    
    /// Get preconds that are a subset of activeModifiers
    
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
    
    /// Extract sorted preconds from precondsAndSizes
    
    NSMutableArray *preconds2 = [NSMutableArray array];
    
    for (NSDictionary *precondAndSize in precondsAndSizes) {
        [preconds2 addObject:precondAndSize[@"precond"]];
    }
    
    /// Split sorted preconds by trigger
    
    NSMutableArray *scrollPreconds = [NSMutableArray array];
    NSMutableArray *dragPreconds = [NSMutableArray array];
    NSMutableArray *buttonPreconds = [NSMutableArray array];
    
    for (NSDictionary *precond in preconds2) {
        
        NSDictionary *mod = remaps[precond];
        if (mod[kMFTriggerScroll] != nil) {
            [scrollPreconds addObject:precond];
        }
        if (mod[kMFTriggerDrag] != nil) {
            [dragPreconds addObject:precond];
        }
        BOOL precondHasNumberKey = NO;
        for (NSObject *key in precond.allKeys) {
            if ([key isKindOfClass:NSNumber.class]) {
                precondHasNumberKey = YES;
                break;
            }
        }
        if (precondHasNumberKey) {
            [buttonPreconds addObject:precond];
        }
    }
    
    /// Filter out preconds that are subsets of other preconds - per trigger
    
    NSArray *scrollPreconds2 = internalSubSetsFilteredOut(scrollPreconds);
    NSArray *dragPreconds2 = internalSubSetsFilteredOut(dragPreconds);
    NSArray *buttonPreconds2 = internalSubSetsFilteredOut(buttonPreconds);
    
    /// Apply modifications in order of their precond size
    
    NSDictionary *combinedScrollMods = [NSMutableDictionary dictionary];
    NSDictionary *combinedDragMods = [NSMutableDictionary dictionary];
    NSDictionary *combinedButtonMods = [NSMutableDictionary dictionary];
    
    /// Scroll
    for (NSDictionary *precond in scrollPreconds2) {
        NSDictionary *scrollModification = remaps[precond][kMFTriggerScroll];
        combinedScrollMods = [SharedUtility dictionaryWithOverridesAppliedFrom:scrollModification to:combinedScrollMods];
    }
    /// Drag
    combinedDragMods = remaps[dragPreconds2.lastObject][kMFTriggerDrag]; /// Drag mods can't be combined so far, so we can just use lastObject
    
    /// Buttons
    for (NSDictionary *precond in buttonPreconds2) {
        NSDictionary *modification = remaps[precond];
        combinedButtonMods = [SharedUtility dictionaryWithOverridesAppliedFrom:modification to:combinedButtonMods];
    }
    
    /// Combine everything back together
    
    NSMutableDictionary *combinedModifications = combinedButtonMods.mutableCopy;
    combinedModifications[kMFTriggerDrag] = combinedDragMods;
    combinedModifications[kMFTriggerScroll] = combinedScrollMods;
    
    /// Return
    
    return combinedModifications;
}

/// MARK: SubsetOverrride helpers

NSArray<NSDictionary *> *internalSubSetsFilteredOut(NSArray<NSDictionary *> *modifiers) {
    /// Will filter out any modifierDicts in `modifiers` that are a subset of another modifierDict in `modifiers`
    /// This function assumes that `modifiers` is sorted by subSetSize (See where this is called in subsetOverride() for example)
    ///     This is probably (hopefully) never gonna be called from anywhere else than subsetOverride()
    
    NSMutableArray *filteredModifiers = [NSMutableArray array];
    
    for (int i = 0; i < modifiers.count; i++) {
        
        NSDictionary *precond = modifiers[i];
        
        BOOL isSubsetOfOtherPrecond = NO;
        
        for (int j = i+1; j < modifiers.count; j++) {
            
            NSDictionary *otherPrecond = modifiers[j];
            
            if (isSubMod(otherPrecond, precond)) {
                isSubsetOfOtherPrecond = YES;
                break;
            }
        }
        
        if (!isSubsetOfOtherPrecond) {
            [filteredModifiers addObject:precond];
        }
    }
    
    return filteredModifiers;
}

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
