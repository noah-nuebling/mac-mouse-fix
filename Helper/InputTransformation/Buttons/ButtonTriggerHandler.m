//
// --------------------------------------------------------------------------
// ButtonTriggerHandler.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "ButtonTriggerHandler.h"
#import "TransformationManager.h"
#import "ModifierManager.h"
#import "Constants.h"
#import "Actions.h"
#import "SharedUtility.h"
#import "ButtonTriggerGenerator.h"

@implementation ButtonTriggerHandler

#pragma mark - Handle triggers

+ (MFEventPassThroughEvaluation)handleButtonTriggerWithButton:(NSNumber *)button triggerType:(MFActionTriggerType)triggerType clickLevel:(NSNumber *)level device:(NSNumber *)devID {
    
#if DEBUG
    NSLog(@"HANDLING BUTTON TRIGGER - button: %@, triggerType: %@, level: %@, devID: %@", button, @(triggerType), level, devID);
#endif
    
    // Get remaps and apply modifier overrides
    NSDictionary *remaps = TransformationManager.remaps;
    NSDictionary *activeModifiers = [ModifierManager getActiveModifiersForDevice:devID filterButton:button event:nil]; // The modifiers which act on the incoming button (the button can't modify itself so we filter it out)
    NSDictionary *effectiveRemaps = getEffectiveRemaps(remaps, activeModifiers);
    NSDictionary *remapsForActiveModifiers = remaps[activeModifiers];
    
    // If no remaps exist for this button, let the CGEvent which caused this function call pass through (Only if this function was invoked as a direct result of a physical button press)
    if (triggerType == kMFActionTriggerTypeButtonDown || triggerType == kMFActionTriggerTypeButtonUp) {
        if (!effectExistsForButton(button, remaps, effectiveRemaps)) {
#if DEBUG
            NSLog(@"No remaps exist for this button, letting event pass through");
#endif
            return kMFEventPassThroughApproval;
        }
    }
    
    // Asses mapping landscape
    // \note It's unnecessary to assess mapping landscape (that includes calculating targetTrigger) on click actions again for every call of this function. It only has to be calculated once for every "click" (as opposed to "hold") actionArray in every possible overriden remapDict including the unoverriden one. We could precalculate everything once when loading remapDict if we wanted to. This is plenty fast though so it's fine.
    
    NSDictionary *activeModifiersUnfiltered = [ModifierManager getActiveModifiersForDevice:devID filterButton:nil event:nil];
    //      ^ We need to check whether the incoming button is acting as a modifier to determine
    //          `effectForMouseDownStateOfThisLevelExists`, so we can't use the variable `activeModifiers` defined above because it filters out the incoming button
    BOOL clickActionOfThisLevelExists;
    BOOL effectForMouseDownStateOfThisLevelExists;
    BOOL effectOfGreaterLevelExists;
    assessMappingLandscape(&clickActionOfThisLevelExists,
                           &effectForMouseDownStateOfThisLevelExists,
                           &effectOfGreaterLevelExists,
                           button,
                           level,
                           remaps,
                           activeModifiersUnfiltered,
                           effectiveRemaps);
#if DEBUG
    // NSLog(@"ACTIVE MODIFIERS - %@", activeModifiersUnfiltered);
#endif
    
    // Send trigger (if apropriate)
    
    if (isTriggerForClickAction(triggerType)) {
        
        // Find targetTriggerType based on mapping landscape assessment
        MFActionTriggerType targetTriggerType = kMFActionTriggerTypeNone;
        if (effectOfGreaterLevelExists) {
            targetTriggerType = kMFActionTriggerTypeLevelTimerExpired;
        } else if (effectForMouseDownStateOfThisLevelExists) {
            targetTriggerType = kMFActionTriggerTypeButtonUp;
        } else {
            targetTriggerType = kMFActionTriggerTypeButtonDown;
        }
        
        // Execute action if incoming trigger matches target trigger
        if (triggerType == targetTriggerType) executeClickOrHoldActionIfItExists(kMFButtonTriggerDurationClick,
                                                                                 devID,
                                                                                 button,
                                                                                 level,
                                                                                 activeModifiers,
                                                                                 remapsForActiveModifiers,
                                                                                 effectiveRemaps);
    } else if (triggerType == kMFActionTriggerTypeHoldTimerExpired) {
        
        // If trigger is for hold action, execute hold action
        
        executeClickOrHoldActionIfItExists(kMFButtonTriggerDurationHold,
                                           devID,
                                           button,
                                           level,
                                           activeModifiers,
                                           remapsForActiveModifiers,
                                           effectiveRemaps);
    }
    
    
    return kMFEventPassThroughRefusal;
    
}

#pragma mark - Execute actions

static void executeClickOrHoldActionIfItExists(NSString * _Nonnull duration,
                                               NSNumber * _Nonnull devID,
                                               NSNumber * _Nonnull button,
                                               NSNumber * _Nonnull level,
                                               NSDictionary *activeModifiers,
                                               NSDictionary *remapsForActiveModifiers,
                                               NSDictionary *effectiveRemaps) {
    
    NSArray *effectiveActionArray = effectiveRemaps[button][level][duration];
    if (effectiveActionArray) { // click/hold action does exist for this button + level
        // // Add modificationPrecondition info for addMode. See TransformationManager -> AddMode for context
        if ([effectiveActionArray[0][kMFActionDictKeyType] isEqualToString: kMFActionDictTypeAddModeFeedback]) {
            effectiveActionArray[0][kMFRemapsKeyModificationPrecondition] = activeModifiers;
        }
        // Execute action
        [Actions executeActionArray:effectiveActionArray];
        // Notify triggering button
        [ButtonTriggerGenerator handleButtonHasHadDirectEffectWithDevice:devID button:button];
        // Notify modifying buttons if executed action depends on active modification
        NSArray *actionArrayFromActiveModification = remapsForActiveModifiers[button][level][duration];
        BOOL actionStemsFromModification = [effectiveActionArray isEqual:actionArrayFromActiveModification];
        if (actionStemsFromModification) {
            [ModifierManager handleModifiersHaveHadEffect:devID];
        }
    }
}


#pragma mark - Interface

#pragma mark Other

+ (BOOL)effectOfEqualOrGreaterLevelExistsForDevice:(NSNumber *)devID button:(NSNumber *)button level:(NSNumber *)level {
    
    NSDictionary *remaps = TransformationManager.remaps;
    NSDictionary *activeModifiers = [ModifierManager getActiveModifiersForDevice:devID filterButton:nil event:nil];
    NSDictionary *effectiveRemaps = getEffectiveRemaps(remaps, activeModifiers);
    
    BOOL clickActionOfThisLevelExists;
    BOOL effectForMouseDownStateOfThisLevelExists;
    BOOL effectOfGreaterLevelExists;
    assessMappingLandscape(&clickActionOfThisLevelExists,
                           &effectForMouseDownStateOfThisLevelExists,
                           &effectOfGreaterLevelExists,
                           button,
                           level,
                           remaps,
                           activeModifiers,
                           effectiveRemaps);
    
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

#pragma mark - Utility

#pragma mark Helper

static NSDictionary *getEffectiveRemaps(NSDictionary *remaps, NSDictionary *activeModifiers) {
    
    NSDictionary *effectiveRemaps = remaps[@{}];
    NSDictionary *remapsForActiveModifiers = remaps[activeModifiers];
    if ([activeModifiers isNotEqualTo:@{}]) {
        effectiveRemaps = [SharedUtility dictionaryWithOverridesAppliedFrom:[remapsForActiveModifiers copy] to:effectiveRemaps]; // Why do we do ` - copy` here?
    }
    return effectiveRemaps;
}

static BOOL effectExistsForButton(NSNumber *button, NSDictionary *remaps, NSDictionary *effectiveRemaps) {
    
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

#pragma mark Assess mapping landscape

static void assessMappingLandscape(BOOL *clickActionOfThisLevelExists,
                                   BOOL *effectForMouseDownStateOfThisLevelExists,
                                   BOOL *effectOfGreaterLevelExists,
                                   NSNumber *button,
                                   NSNumber *level,
                                   NSDictionary *remaps,
                                   NSDictionary *activeModifiers,
                                   NSDictionary *effectiveRemaps)
{
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

static BOOL isTriggerForClickAction(MFActionTriggerType triggerType) {
    return triggerType == kMFActionTriggerTypeButtonDown ||
    triggerType == kMFActionTriggerTypeButtonUp ||
    triggerType == kMFActionTriggerTypeLevelTimerExpired;
}

@end
