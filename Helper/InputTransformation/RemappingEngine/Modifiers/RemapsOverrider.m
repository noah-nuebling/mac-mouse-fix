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
    
    /// Treat simple case separately for optimization
    
    if ([activeModifiers isEqual: @{}]) {
//        DDLogDebug(@"activeFlags in subsetOverride: %@", [SharedUtility binaryRepresentation:0]); /// Debug
        return remaps[@{}];
    }
    
    /// Get values from active modifiers
    
    CGEventFlags activeFlags = ((NSNumber *)activeModifiers[kMFModificationPreconditionKeyKeyboard]).unsignedLongLongValue;
    NSArray *activeButtons = (NSArray *)activeModifiers[kMFModificationPreconditionKeyButtons];
    
    /// Debug
    
//    DDLogDebug(@"activeFlags in subsetOverride: %@", [SharedUtility binaryRepresentation:(int)activeFlags]);
    
    /// Get subset sizes
    
    NSMutableArray<NSDictionary *> *precondsAndSizes = [NSMutableArray array];
    
    for (NSDictionary *precond in remaps.allKeys) {
        
        /// Keyboard mod flags
        
        CGEventFlags flags = ((NSNumber *)precond[kMFModificationPreconditionKeyKeyboard]).unsignedLongLongValue;
        
        /// Check if subset
        BOOL flagsAreSubset = (flags & activeFlags) == flags;
        if (!flagsAreSubset) continue;
        
        /// Get subset size
        int64_t flagsSubsetSize = 0;
        while (flags != 0) {
            flagsSubsetSize += flags & 1;
            flags >>= 1;
        }
        
        /// Button mods
        
        NSArray *buttons = precond[kMFModificationPreconditionKeyButtons];
        
        BOOL buttonsAreSubsequence = NO;
        int64_t buttonSubsequenceLength = 0;
        
        if (buttons.count == 0) {
            /// Treat zero case separately for optimization
            
            buttonsAreSubsequence = YES;
            buttonSubsequenceLength = 0;
            
        } else {
            
            int buttonIndex = 0;
            
            for (int activeButtonIndex = 0; activeButtonIndex < buttons.count; activeButtonIndex++) {
                
                /// Break prematurely
                ///     For optimtization
                long buttonsLeft = buttons.count - buttonIndex;
                long activeButtonsLeft = activeButtons.count - activeButtonIndex;
                if (buttonsLeft > activeButtonsLeft) { /// Cuttons can't be a subsequence of activeButtons
                    buttonsAreSubsequence = NO;
                    buttonSubsequenceLength = 0;
                    break;
                };
                
                /// Get buttons dicts
                ///     for checking equality
                NSDictionary *buttonDict = buttons[buttonIndex];
                NSDictionary *activeButtonDict = activeButtons[activeButtonIndex];
                
                /// Do logical things that make sense
                if ([buttonDict isEqual:activeButtonDict]) {
                    buttonIndex++;
                } else {
                    buttonIndex = 0;
                }
                
                /// Validate
                assert(!(buttonIndex > buttons.count));
                
                /// Check if found subsequence
                if (buttonIndex == buttons.count) {
                    buttonsAreSubsequence = YES;
                    buttonSubsequenceLength = activeButtons.count;
                    break;
                }
            }
        }
        
        /// Combine info about  flags and buttons
        
        assert(flagsAreSubset);
        if (!buttonsAreSubsequence) continue;
        
        [precondsAndSizes addObject:@{
            @"precond": precond,
            @"size": @(flagsSubsetSize + buttonSubsequenceLength),
        }];
    }
    
    /// Sort preconditions (that are subsets of activeModifiers) by size
    
    [precondsAndSizes sortUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
        NSNumber *size1 = obj1[@"size"];
        NSNumber *size2 = obj2[@"size"];
        return [size1 compare:size2];
    }];
    
    /// Debug
    
//    DDLogDebug(@"precondsAndSizes in subsetOverride: %@", precondsAndSizes);
    
    /// Apply modifications in order of their precond size
    
    NSDictionary *combinedModifications = [NSMutableDictionary dictionary];
    
    for (NSDictionary *precondAndSize in precondsAndSizes) {
        NSDictionary *precond = precondAndSize[@"precond"];
        NSDictionary *modification = remaps[precond];
        
        combinedModifications = [SharedUtility dictionaryWithOverridesAppliedFrom:modification to:combinedModifications];
        /// ^ Would be more efficient to have an in-place override function for this
    }
    
    /// Debug
    
//    DDLogDebug(@"combinedModifications in subsetOverride: %@", combinedModifications);
    
    /// Return
    
    return combinedModifications;
}

@end
