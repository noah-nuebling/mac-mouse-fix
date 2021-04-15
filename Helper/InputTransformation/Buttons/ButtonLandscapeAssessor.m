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
#import "Utility_Transformation.h"

@implementation ButtonLandscapeAssessor

#pragma mark - Main Assess Button Landscape Function

/// Primarily used for `[ButtonTriggerHandler + handleButtonTriggerWithButton:...]` to help figure out when to fire clickEffects
/// `activeModifiers` are the active modifiers including `button`
/// `activeModifiersActingOnThisButton` are the active modifiers with `button` filtered out
/// `effectiveRemapsMethod` is a block taking `remaps` and `activeModifiersActingOnThisButton` and returning what the effective remaps acting on the button are.
///     Should normally pass `[Utility Transform + effectiveRemapsMethod_Override]` I think other stuff will break if we use sth else.
+ (void)assessMappingLandscapeWithButton:(NSNumber *)button
                                   level:(NSNumber *)level
                         activeModifiers:(NSDictionary *)activeModifiers
                 activeModifiersFiltered:(NSDictionary *)activeModifiersActingOnThisButton
                   effectiveRemapsMethod:(MFEffectiveRemapsMethod)effectiveRemapsMethod
                                  remaps:(NSDictionary *)remaps
                           thisClickDoBe:(BOOL *)clickActionOfThisLevelExists
                            thisDownDoBe:(BOOL *)effectForMouseDownStateOfThisLevelExists
                             greaterDoBe:(BOOL *)effectOfGreaterLevelExists {
    
    NSDictionary *remapsActingOnThisButton = effectiveRemapsMethod(remaps, activeModifiersActingOnThisButton);
    
    *clickActionOfThisLevelExists = remapsActingOnThisButton[button][level][kMFButtonTriggerDurationClick] != nil;
    *effectForMouseDownStateOfThisLevelExists = effectExistsForMouseDownState(button, level, remaps, activeModifiers, remapsActingOnThisButton);
    *effectOfGreaterLevelExists = effectOfGreaterLevelExistsFor(button, level, remaps, activeModifiers, remapsActingOnThisButton);
}

#pragma mark Helper functions for Main Assess Button Landscape Function

static BOOL effectExistsForMouseDownState(NSNumber *button, NSNumber *level, NSDictionary *remaps, NSDictionary *activeModifiers, NSDictionary *remapsActingOnThisButton) {
    BOOL holdActionExists = remapsActingOnThisButton[button][level][kMFButtonTriggerDurationHold] != nil;
    BOOL usedAsModifier = isPartOfModificationPrecondition(button, level, remaps, activeModifiers);
    
    return holdActionExists || usedAsModifier;
}
static BOOL isPartOfModificationPrecondition(NSNumber *button, NSNumber *level, NSDictionary *remaps, NSDictionary *activeModifiers) {
    // TODO: Check if this still works after modification precondition refactor
        // Debugged this, now it seems to work fine
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

static BOOL effectOfGreaterLevelExistsFor(NSNumber *button, NSNumber *level, NSDictionary *remaps, NSDictionary *activeModifiers, NSDictionary *remapsActingOnThisButton) {
    
    // Check if effective remaps of a higher level exist for this button
    for (NSNumber *thisLevel in ((NSDictionary *)remapsActingOnThisButton[button]).allKeys) {
        if (thisLevel.intValue > level.intValue) {
            return YES;
        }
    }
    // Check for modifications at a higher level
    return modificationPreconditionButtonComponentOfGreaterLevelExistsForButton(button, level, remaps, activeModifiers);
}

static BOOL modificationPreconditionButtonComponentOfGreaterLevelExistsForButton(NSNumber *button, NSNumber *level, NSDictionary *remaps, NSDictionary *activeModifiers) {
    
    // Check if modification precondition exists such that at least one of its button components has the same button as the incoming button `button` and a level greater than the incoming level `level`
    // We're passing in `activeModifiers` even though we don't need it. Why is that? Hints towards us messing sth up in some refactor.
    
    for (NSDictionary *modificationPrecondition in remaps.allKeys) {
        NSIndexSet *indexesContainingButton = [(NSArray *)modificationPrecondition[kMFModificationPreconditionKeyButtons] indexesOfObjectsPassingTest:^BOOL(NSDictionary *_Nonnull dict, NSUInteger idx, BOOL * _Nonnull stop) {
            return [dict[kMFButtonModificationPreconditionKeyButtonNumber] isEqualToNumber:button];
        }];
        if (indexesContainingButton.count == 0) continue;
        
        NSNumber *precondLvl = modificationPrecondition[kMFModificationPreconditionKeyButtons][indexesContainingButton.firstIndex][kMFButtonModificationPreconditionKeyClickLevel];
        if (precondLvl.unsignedIntegerValue > level.unsignedIntegerValue) {
            return YES;
        }
    }
    return NO;
}

#pragma mark - Other Landscape Assessment Functions

/// Used by `ButtonTriggerGenerator` to reset the click cycle, if we know the button can't be used this click cycle anyways.
+ (BOOL)buttonCouldStillBeUsedThisClickCycle:(NSNumber *)devID button:(NSNumber *)button level:(NSNumber *)level {
    
    NSDictionary *remaps = TransformationManager.remaps;
    NSDictionary *activeModifiers = [ModifierManager getActiveModifiersForDevice:devID filterButton:nil event:nil];
    NSDictionary *activeModifiersActingOnThisButton = [ModifierManager getActiveModifiersForDevice:devID filterButton:button event:nil];
    
    BOOL clickActionOfThisLevelExists;
    BOOL effectForMouseDownStateOfThisLevelExists;
    BOOL effectOfGreaterLevelExists;
    [self assessMappingLandscapeWithButton:button
                                     level:level
                           activeModifiers:activeModifiers
                   activeModifiersFiltered:activeModifiersActingOnThisButton
                     effectiveRemapsMethod:Utility_Transformation.effectiveRemapsMethod_Override
                                    remaps:remaps
                             thisClickDoBe:&clickActionOfThisLevelExists
                              thisDownDoBe:&effectForMouseDownStateOfThisLevelExists
                               greaterDoBe:&effectOfGreaterLevelExists];
#if DEBUG
//    NSDictionary *info = @{
//        @"devID": devID,
//        @"button": button,
//        @"level": level,
//        @"clickActionOfThisLevelExists": @(clickActionOfThisLevelExists),
//        @"effectForMouseDownStateOfThisLevelExists": @(effectForMouseDownStateOfThisLevelExists),
//        @"effectOfGreaterLevelExists": @(effectOfGreaterLevelExists),
//        @"remaps": remaps,
//    };
//    NSLog(@"CHECK IF EFFECT OF EQUAL OR GREATER LEVEL EXISTS - Info: %@", info);
#endif
    
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
