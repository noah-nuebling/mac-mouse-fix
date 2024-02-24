//
// --------------------------------------------------------------------------
// RemapSwizzler.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "RemapSwizzler.h"
#import "Modifiers.h"
#import "DeviceManager.h"
#import "Remap.h"

#import "SharedUtility.h"

@implementation RemapSwizzler

/// MARK: - Notes

/// Instead of using this directly, use [Remap modificationsWithModifiers:]. It's faster since it caches results.

/// This class provides methods for obtaining combined remaps based on a remaps dict and some active modifiers.
///     These *combined* remaps are also sometimes called *effective remaps* or *remaps for current modifiers*, "activeModifications", "modificationsActingOnButton", etc.
///     If this doesn't make sense, see an example of the remaps dict structure in Remap.m

/// More rigorous explanation:
///     The `remaps` dict in the Remap class is a dict that is defined by the user in the UI and which represents a map from modifiers -> (triggers -> effects).
///     Elements of the righthand side of this map, (which are themselves maps from (triggers -> effects)) are also often called a `modification`, and elements of the lefthand side are called the `modificationPrecondition`. The modifiers that the user is currently holding down are also called the `activeModifiers`.
///
///     The remaps dict could be considered a function r with `r(modifiers) = modification`
///     Now the **RemapSwizzler** provides functions that swizzle up an original remaps function r based on some modifiers. They look like r'(r, modifiers) = modification, where r is the remaps dict.
///
///     Why do we need this? Why not just use the original function that the user defined directly and query the dictionary?
///
///     The main reason is this:
///         When there's a `modificationPrecondition` P which is a subset of the `activeModifiers`A, but isn't exactly equal A, then we still want to activate the `modification` M that belongs to P.
///         However we *don't* want to do that if there is a different `modification` M' which is incompatible with M and which has a `modificationPrecondition` P' that matches the `activeModifiers` A better than P.
///         In that case we would only want to activate M' and not M.
///         I can't explain why but this makes for much better and more flexible user experience.
///         To implement this behaviour we need the RemapSwizzler instead of just querying the remaps dict directly.
///         See `subsetSwizzler()` for the implementation.
///
///     But there's a second important usecase:
///     During **addMode**, we need to change this map from modifiers -> triggers -> effects, such that any combination of trigger T and modifiers M that the user can input, is mapped to `addModeFeedback_T_M`. But this would mean c o m b i n a t o r i c e x p l o s i o n if we wanted to store that all in the remaps dict in TransformationManger. So we came up with this weird solution:
///         Basically the Remap creates a map from `noModifiers -> anyTrigger -> addModeFeedback_T`, as a dictionary, which isn't that large because there aren't that many triggers, so we can list them all. Then we dynamically swizzle up that map in **RemapSwizzler** so it becomes the full `anyModifier -> anyTrigger -> addModeFeedback_T_M` map!
///         See `addModeSwizzler()` for the implementation of that.

/// MARK: Interface

+ (NSDictionary * _Nullable)swizzleRemaps:(NSDictionary *)remaps activeModifiers:(NSDictionary *)activeModifiers {
    
    if (Remap.addModeIsEnabled) {
        return addModeSwizzler(remaps, activeModifiers);
    } else {
        return subsetSwizzler(remaps, activeModifiers);
    }
}

/// MARK: Swizzlers

static NSDictionary *addModeSwizzler(NSDictionary *remaps, NSDictionary *activeModifierss) {

    /// See `Remap + enableAddMode` and top of this file for context.
    
    NSMutableDictionary *modification = [SharedUtility deepMutableCopyOf:remaps[@{}]]; /// Deep copying so caller can store value without it changing afterwards due to references
    NSMutableDictionary *activeModifiers = [SharedUtility deepMutableCopyOf:(id)activeModifierss]; /// I think we deep mutable copy so the UI doesn't crash
    
    if (activeModifiers.count > 0) { /// There need to be modifiers for drag and scroll triggers!
        modification[kMFTriggerDrag][kMFRemapsKeyModificationPrecondition] = activeModifiers;
        modification[kMFTriggerScroll][kMFRemapsKeyModificationPrecondition] = activeModifiers;
    } else {
        modification[kMFTriggerDrag] = nil;
        modification[kMFTriggerScroll] = nil;
    }
    
    for (int btn = 1; btn <= kMFMaxButtonNumber; btn++) {
        for (int lvl = 1; lvl <= 3; lvl++) {
            for (NSString *dur in @[kMFButtonTriggerDurationClick, kMFButtonTriggerDurationHold]) {
                modification[@(btn)][@(lvl)][dur][0][kMFRemapsKeyModificationPrecondition] = activeModifiers;
            }
        }
    }
    
    return modification;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-function"

static NSDictionary * _Nullable simpleSwizzler(NSDictionary *remaps, NSDictionary *activeModifiers) {
    /// This is unused now.
    /// Primitive remaps overriding method. Simply takes the base (with an empty modification precondition) remaps and overrides it with the remaps which have a modificationPrecondition of exactly `activeModifiers`
    
    NSDictionary *effectiveRemaps = remaps[@{}];
    NSDictionary *remapsForActiveModifiers = remaps[activeModifiers];
    if ([activeModifiers isNotEqualTo:@{}]) {
        effectiveRemaps = [SharedUtility dictionaryWithOverridesAppliedFrom:[remapsForActiveModifiers copy] to:effectiveRemaps]; /// Why do we do ` - copy` here?
    }
    return effectiveRemaps;
}
#pragma clang diagnostic pop

static NSDictionary *_Nullable subsetSwizzler(NSDictionary *remaps, NSDictionary *activeModifiers) {
    
    /// This allows combining modifiers
    /// Here's what it does
    ///     It takes all the modificationPreconditions from `remaps` that are a subset of `activeModifiers` and sorts them by how large of a subset they are
    ///     Then It creates one new precond array for each triggerType and only puts in the preconds that have that triggerType in their modification
    ///     For each trigger-specific precond array it then filters out all the preconds that are a subset of another precond in that trigger-specific precond array
    ///     Then, for each trigger-specific precond array, it takes all the modification dicts of each precond and overrides them into each other in the order of their precond size, from small to large
    /// I'm too lazy and stupid to describe why all this abstract stuff makes sense, but it leads the button and keyboard modifiers to always do the intuitive thing that you expect them to!
    
    /// Treat simple case separately for optimization
    
    if ([activeModifiers isEqual: @{}]) {
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
    ///     Note: I think a better name for 'precond size' would be 'precond specificity'
    
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
        for (NSObject *key in mod.allKeys) {
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
    ///     Notes:
    ///     - Why exactly are we doing this 'splitting up by trigger' thing? Couldn't we just override all the dicts into each other (without doing the internalSubsetsFilteredOut thing beforehand) and get the same result?
    ///         - I thought about it and: no - it's important that we do it this way. Think about the scenario, where Shift is horizontal scroll and Shift+Command is quickScroll. If we didn't do the 'internalSubsetsFilteredOut' thing, then Shift+Command would quickScroll *horizontally*. When the desired behaviour is to quickScroll vertically.
    
    NSArray *scrollPreconds2 = internalSubSetsFilteredOut(scrollPreconds);
    NSArray *dragPreconds2 = internalSubSetsFilteredOut(dragPreconds);
    NSArray *buttonPreconds2 = internalSubSetsFilteredOut(buttonPreconds);
    
    /// Apply modifications in order of their precond size
    
    NSDictionary *combinedScrollMods = [NSMutableDictionary dictionary];
    NSDictionary *combinedDragMods;
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
        
        /// This loop is pretty simple because we know that no button can occur in the sequence more than once
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
