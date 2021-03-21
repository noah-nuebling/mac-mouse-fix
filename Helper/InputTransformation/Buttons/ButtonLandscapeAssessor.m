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

@implementation ButtonLandscapeAssessor

#pragma mark - Main

/// Why do we have arguments `activeModifiers`, `remaps` as well as `effectiveRemaps`?
///     `activeModifiers` and `remaps` should determine `effectiveRemaps`. Does this make any sense?
///     -> Yes, it seems to kind of make sense. activeModifiers is expected to be unfilitered, so containing `button`, while `effectiveRemaps` are the remaps for the modifiers that are _acting on_ `button`, so the active modifiers without `button`.
///        TODO: This is super confusing and it lead us to code `buttonCouldStillBeUsedThisClickCycle:` in a wrong way (I'm pretty sure). We need to move that logic inside of this function.
+ (void)assessMappingLandscapeWithbutton:(NSNumber *)button
                                   level:(NSNumber *)level
                         activeModifiers:(NSDictionary *)activeModifiers
                                  remaps:(NSDictionary *)remaps
                          effectiveRemaps:(NSDictionary *)effectiveRemaps
                           thisClickDoBe:(BOOL *)clickActionOfThisLevelExists
                            thisDownDoBe:(BOOL *)effectForMouseDownStateOfThisLevelExists
                             greaterDoBe:(BOOL *)effectOfGreaterLevelExists {
    
    *clickActionOfThisLevelExists = effectiveRemaps[button][level][kMFButtonTriggerDurationClick] != nil;
    *effectForMouseDownStateOfThisLevelExists = effectExistsForMouseDownState(button, level, remaps, activeModifiers, effectiveRemaps);
    *effectOfGreaterLevelExists = effectOfGreaterLevelExistsFor(button, level, remaps, activeModifiers, effectiveRemaps);
}

static BOOL effectExistsForMouseDownState(NSNumber *button, NSNumber *level, NSDictionary *remaps, NSDictionary *activeModifiers, NSDictionary *effectiveRemaps) {
    BOOL holdActionExists = effectiveRemaps[button][level][kMFButtonTriggerDurationHold] != nil;
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

static BOOL effectOfGreaterLevelExistsFor(NSNumber *button, NSNumber *level, NSDictionary *remaps, NSDictionary *activeModifiers, NSDictionary *effectiveRemaps) {
    // Check if effective remaps of a higher level exist for this button
    for (NSNumber *thisLevel in ((NSDictionary *)effectiveRemaps[button]).allKeys) {
        if (thisLevel.intValue > level.intValue) {
            return YES;
        }
    }
    // Check for modifications at a higher level
    return modificationPreconditionButtonComponentOfGreaterLevelExistsForButton(button, level, remaps, activeModifiers);
}

static BOOL modificationPreconditionButtonComponentOfGreaterLevelExistsForButton(NSNumber *button, NSNumber *level, NSDictionary *remaps, NSDictionary *activeModifiers) {
    
    // Check if modification precondition exists such that at least one of its button components has the same button as the incoming button `button` and a level greater than the incoming level `level`
    
    for (NSDictionary *modificationPrecondition in remaps.allKeys) {
        // TODO: Check if still workds after modification precondition refactor
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

#pragma mark - Convenience functions

/// This is used by ButtonTriggerGenerator to reset the click cycle, if we know the button can't be used this click cycle anyways.
/// \discussion We used to call [ModifierManager getActiveModifiersForDevice:filterButton:event:] with the filterButton argument set to nil.
///     This lead to issues with the click cycle being reset prematurely sometimes. We set filterBUtton to button, now. Hopefully this doesn't break stuff in other ways. I don't think so.
///             -> Noah from future: I'm pretty sure it actually will break stuff. See docs on  `assessMappingLandscapeWithbutton:..`
+ (BOOL)buttonCouldStillBeUsedThisClickCycle:(NSNumber *)devID button:(NSNumber *)button level:(NSNumber *)level {
    
    NSDictionary *remaps = TransformationManager.remaps;
    NSDictionary *activeModifiers = [ModifierManager getActiveModifiersForDevice:devID filterButton:button event:nil];
    NSDictionary *effectiveRemaps = [self getEffectiveRemaps:remaps activeModifiers:activeModifiers];
    
    BOOL clickActionOfThisLevelExists;
    BOOL effectForMouseDownStateOfThisLevelExists;
    BOOL effectOfGreaterLevelExists;
    [self assessMappingLandscapeWithbutton:button
                                     level:level
                           activeModifiers:activeModifiers
                                    remaps:remaps
                           effectiveRemaps:effectiveRemaps
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
+ (BOOL)effectExistsForButton:(NSNumber *)button remaps:(NSDictionary *)remaps effectiveRemaps:(NSDictionary *)effectiveRemaps {
    
    // Check if there is a direct effect for button
    BOOL hasDirectEffect = effectiveRemaps[button] != nil;
    if (hasDirectEffect) {
        return YES;
    }
    // Check if button has effect as modifier
    for (NSDictionary *modificationPrecondition in remaps.allKeys) {
        NSArray *buttonPreconditions = modificationPrecondition[kMFModificationPreconditionKeyButtons];
        NSIndexSet *buttonIndexes = [buttonPreconditions indexesOfObjectsPassingTest:^BOOL(NSDictionary *_Nonnull dict, NSUInteger idx, BOOL * _Nonnull stop) {
            return [dict[kMFButtonModificationPreconditionKeyButtonNumber] isEqualToNumber:button];
        }];
        if (buttonIndexes.count != 0) {
            return YES;
        }
    }
    
    return NO;
}

/// TODO: Move this to Utility_Transformations
+ (NSDictionary *)getEffectiveRemaps:(NSDictionary *)remaps activeModifiers:(NSDictionary *)activeModifiers {
    
    NSDictionary *effectiveRemaps = remaps[@{}];
    NSDictionary *remapsForActiveModifiers = remaps[activeModifiers];
    if ([activeModifiers isNotEqualTo:@{}]) {
        effectiveRemaps = [SharedUtility dictionaryWithOverridesAppliedFrom:[remapsForActiveModifiers copy] to:effectiveRemaps]; // Why do we do ` - copy` here?
    }
    return effectiveRemaps;
}

+ (NSSet<NSNumber *> *)getCapturedButtons {
    NSMutableSet<NSNumber *> *capturedButtons = [NSMutableSet set];
    for (int b = 1; b <= kMFMaxButtonNumber; b++) {
//        if (self buttonCouldStillBeUsedThisClickCycle:<#(nonnull NSNumber *)#> button:<#(nonnull NSNumber *)#> level:<#(nonnull NSNumber *)#>)
    }
    return capturedButtons;
}

@end
