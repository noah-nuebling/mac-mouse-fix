//
// --------------------------------------------------------------------------
// ButtonLandscapeAssessor.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "ButtonLandscapeAssessor.h"
#import "TransformationManager.h"
#import "SharedUtility.h"
#import "ModifierManager.h"
//#import "Utility_Transformation.h"
#import "Mac_Mouse_Fix_Helper-Swift.h"

@implementation ButtonLandscapeAssessor

#pragma mark - Main Assess Button Landscape Function

/// Primarily used for `[ButtonTriggerHandler + handleButtonTriggerWithButton:...]` to help figure out when to fire clickEffects
/// `activeModifiers` are the active modifiers including `button` (We've since removed this argument since we didn't use it)
/// `activeModifiersActingOnThisButton` are the active modifiers with `button` filtered out
/// `effectiveRemapsMethod` is a block taking `remaps` and `activeModifiersActingOnThisButton` and returning what the effective remaps acting on the button are.
///     Should normally pass `[Utility Transform + effectiveRemapsMethod]` I think other stuff will break if we use sth else.
+ (void)assessMappingLandscapeWithButton:(NSNumber *)button
                                   level:(NSNumber *)level
                remapsActingOnThisButton:(NSDictionary *)remapsActingOnThisButton
                                  remaps:(NSDictionary *)remaps
                           thisClickDoBe:(BOOL *)clickActionOfThisLevelExists
                            thisDownDoBe:(BOOL *)effectForMouseDownStateOfThisLevelExists
                             greaterDoBe:(BOOL *)effectOfGreaterLevelExists {
    
    *clickActionOfThisLevelExists = remapsActingOnThisButton[button][level][kMFButtonTriggerDurationClick] != nil;
    *effectForMouseDownStateOfThisLevelExists = effectExistsForMouseDownState(button, level, remaps, remapsActingOnThisButton);
    *effectOfGreaterLevelExists = effectOfGreaterLevelExistsFor(button, level, remaps, remapsActingOnThisButton);
}

#pragma mark Helper functions for Main Assess Button Landscape Function

static BOOL effectExistsForMouseDownState(NSNumber *button, NSNumber *level, NSDictionary *remaps, NSDictionary *remapsActingOnThisButton) {
    BOOL holdActionExists = remapsActingOnThisButton[button][level][kMFButtonTriggerDurationHold] != nil;
    BOOL usedAsModifier = isPartOfModificationPrecondition(button, level, remaps);
    
    return holdActionExists || usedAsModifier;
}
static BOOL isPartOfModificationPrecondition(NSNumber *button, NSNumber *level, NSDictionary *remaps) {
    // TODO: Check if this still works after modification precondition refactor
        /// Debugged this, now it seems to work fine
    
    /// ^ I feel like, now that the button preconditions are ordered, we might wanna check if the sequence of buttons in the activeModifiers are the start (or the whole) of a sequence of buttons in some modification precondition. So if there is button Sequence in some button precondition that can still be reached based on the current state. (Right now we're just checking if the `button` is any part of any modification precondition's button sequence) But I guess if you consider that the user can let go of buttons, then any buttonSequence can "still be reached". And if we don't consider letting go of buttons (which probably doesn't make sense?) then it would be much more involved to determine this stuff.... So I think the current solution is probably the most practical.
    
    NSDictionary *buttonPrecondition = @{
        kMFButtonModificationPreconditionKeyButtonNumber: button,
        kMFButtonModificationPreconditionKeyClickLevel: level
    };
    for (NSDictionary *modificationPrecondition in remaps.allKeys) {
        if ([((NSArray *)modificationPrecondition[kMFModificationPreconditionKeyButtons]) containsObject:buttonPrecondition]) {
            return YES;
        }
    }
    
    return NO;
}

static BOOL effectOfGreaterLevelExistsFor(NSNumber *button, NSNumber *level, NSDictionary *remaps, NSDictionary *remapsActingOnThisButton) {
    
    // Check if effective remaps of a higher level exist for this button
    for (NSNumber *thisLevel in ((NSDictionary *)remapsActingOnThisButton[button]).allKeys) {
        if (thisLevel.intValue > level.intValue) {
            return YES;
        }
    }
    // Check for modifications at a higher level
    return modificationPreconditionButtonComponentOfGreaterLevelExistsForButton(button, level, remaps);
}

static BOOL modificationPreconditionButtonComponentOfGreaterLevelExistsForButton(NSNumber *button, NSNumber *level, NSDictionary *remaps) {
    
    /// Check if modification precondition exists such that at least one of its button components has the same button as the incoming button `button` and a level greater than the incoming level `level`
    /// We (were) passing in `activeModifiers` even though we don't need it. Why is that? Hints towards us messing sth up in some refactor.
    
    for (NSDictionary *modificationPrecondition in remaps.allKeys) {
        
        /// v This algorithm seems very convoluted for what it does. I think instead we could maybe just iterate through the button sequences of all modificationPreconditions until we find a button with a clickLevel higher than `level`. If we can't then we return `NO`, otherwise `YES
        /// Since button preconditions are ordered now, we maybe should check if there exists a modificationPreconditions' buttonSequence that can still be reached by adding `button` to the button sequence in the `activeModifiers`? Not sure though. I guess any sequence can be reached, by taking away some buttons first?
        
        NSIndexSet *indexesContainingButton = [(NSArray *)modificationPrecondition[kMFModificationPreconditionKeyButtons] indexesOfObjectsPassingTest:^BOOL(NSDictionary *_Nonnull dict, NSUInteger idx, BOOL * _Nonnull stop) {
            return [dict[kMFButtonModificationPreconditionKeyButtonNumber] isEqualToNumber:button];
        }];
        if (indexesContainingButton.count == 0) continue;
        
        /// v Shouldn't we iterate through the buttonSequence, instead of just checking at index `indexesContainingButton.firstIndex`?
        NSNumber *precondLvl = modificationPrecondition[kMFModificationPreconditionKeyButtons][indexesContainingButton.firstIndex][kMFButtonModificationPreconditionKeyClickLevel];
        if (precondLvl.unsignedIntegerValue > level.unsignedIntegerValue) {
            return YES;
        }
    }
    return NO;
}

#pragma mark - Other Landscape Assessment Functions

/// Used by `ButtonTriggerGenerator` to reset the click cycle, if we know the button can't be used this click cycle anyways.
///     Later in the control chain - in ButtonTriggerHandler - the assessMappingLandscapeWithButton:... method is called again. This is probably redundant, as we could just store the result of the first call somehow. But if it's fast enough, who cares
+ (BOOL)buttonCouldStillBeUsedThisClickCycle:(NSNumber *)devID button:(NSNumber *)button level:(NSNumber *)level {
    
    NSDictionary *remaps = TransformationManager.remaps;
    NSDictionary *modifiersActingOnThisButton = [ModifierManager getActiveModifiersForDevice:&devID filterButton:button event:nil];
    NSDictionary *remapsActingOnThisButton = RemapsOverrider.effectiveRemapsMethod(remaps, modifiersActingOnThisButton);
    
    BOOL clickActionOfThisLevelExists;
    BOOL effectForMouseDownStateOfThisLevelExists;
    BOOL effectOfGreaterLevelExists;
    [self assessMappingLandscapeWithButton:button
                                     level:level
                  remapsActingOnThisButton:remapsActingOnThisButton
                                    remaps:remaps
                             thisClickDoBe:&clickActionOfThisLevelExists
                              thisDownDoBe:&effectForMouseDownStateOfThisLevelExists
                               greaterDoBe:&effectOfGreaterLevelExists];
//    NSDictionary *info = @{
//        @"devID": devID,
//        @"button": button,
//        @"level": level,
//        @"clickActionOfThisLevelExists": @(clickActionOfThisLevelExists),
//        @"effectForMouseDownStateOfThisLevelExists": @(effectForMouseDownStateOfThisLevelExists),
//        @"effectOfGreaterLevelExists": @(effectOfGreaterLevelExists),
//        @"remaps": remaps,
//    };
//    DDLogDebug(@"CHECK IF EFFECT OF EQUAL OR GREATER LEVEL EXISTS - Info: %@", info);
    
    return clickActionOfThisLevelExists || effectForMouseDownStateOfThisLevelExists || effectOfGreaterLevelExists;
}

/// Used by `ButtonTriggerHandler` to determine `MFEventPassThroughEvaluation`
///     Noah from future: Why aren't we reusing `assessMappingLandscapeWithButton:` here?
///         -> I guess it's because we don't care about most of the arguments which have to be provided to `assessMappingLandscapeWithButton:`
///             For example we don't care about clickLevel and to use `assessMappingLandscapeWithButton:` we'd have to call it for each clickLevel and stuff.
///     Noah from even more in future: Maybe we should refactor the code for  `MFEventPassThroughEvaluation` and call this function from ButtonTriggerGenerator directly? As it is we're passing the `MFEventPassThroughEvaluation` through like 3 classes which is a little ugly.
+ (BOOL)effectExistsForButton:(NSNumber *)button remaps:(NSDictionary *)remaps effectiveRemaps:(NSDictionary *)effectiveRemaps {
    
    // Check if there is a direct effect for button
    BOOL hasDirectEffect = effectiveRemaps[button] != nil;
    if (hasDirectEffect) {
        return YES;
    }
    // Check if button has effect as modifier
    //      Noah from future: Maybe we should only check for button preconds with a higher clickLevel than current?
    //          -> But maybe that wouldn't make a diff because clickLevel is reset when `buttonCouldStillBeUsedThisClickCycle:` returns true? (I think)
    //          (I feel like we probs thought this through when we wrote it I just don't understand it anymore)
    for (NSDictionary *modificationPrecondition in remaps.allKeys) {
        if ([SharedUtility button:button isPartOfModificationPrecondition:modificationPrecondition]) {
            return YES;
        }
    }
    
    return NO;
}

@end
