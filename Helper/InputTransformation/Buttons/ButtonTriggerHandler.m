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
#import "ButtonTriggerHandler.h"
#import "ButtonLandscapeAssessor.h"

@implementation ButtonTriggerHandler

#pragma mark - Handle triggers

+ (MFEventPassThroughEvaluation)handleButtonTriggerWithButton:(NSNumber *)button triggerType:(MFActionTriggerType)triggerType clickLevel:(NSNumber *)level device:(NSNumber *)devID {
    
#if DEBUG
    NSLog(@"HANDLING BUTTON TRIGGER - button: %@, triggerType: %@, level: %@, devID: %@", button, @(triggerType), level, devID);
#endif
    
    // Get remaps and apply modifier overrides
    NSDictionary *remaps = TransformationManager.remaps;
    NSDictionary *activeModifiers = [ModifierManager getActiveModifiersForDevice:devID filterButton:button event:nil]; // The modifiers which act on the incoming button (the button can't modify itself so we filter it out)
    NSDictionary *effectiveRemaps = [ButtonLandscapeAssessor getEffectiveRemaps:remaps activeModifiers:activeModifiers];
    NSDictionary *remapsForActiveModifiers = remaps[activeModifiers];
    
#if DEBUG
    NSLog(@"\nActive mods: %@, \nremapsForActiveMods: %@", activeModifiers, remapsForActiveModifiers);
#endif
    
    // If no remaps exist for this button, let the CGEvent which caused this function call pass through (Only if this function was invoked as a direct result of a physical button press)
    if (triggerType == kMFActionTriggerTypeButtonDown || triggerType == kMFActionTriggerTypeButtonUp) {
        if (![ButtonLandscapeAssessor effectExistsForButton:button
                                                     remaps:remaps
                                            effectiveRemaps:effectiveRemaps]) {
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
    //      Noah from future: TODO: But why do we pass the old value for `effectiveRemaps` - which is not based on `activeModifiersUnfiltered` - to ButtonLandscapeAssessor?
    BOOL clickActionOfThisLevelExists;
    BOOL effectForMouseDownStateOfThisLevelExists;
    BOOL effectOfGreaterLevelExists;
    [ButtonLandscapeAssessor assessMappingLandscapeWithButton:button
                                                        level:level
                                              activeModifiers:activeModifiersUnfiltered
                                                       remaps:remaps
                                              effectiveRemaps:effectiveRemaps
                                                thisClickDoBe:&clickActionOfThisLevelExists
                                                 thisDownDoBe:&effectForMouseDownStateOfThisLevelExists
                                                  greaterDoBe:&effectOfGreaterLevelExists];
    
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

#pragma mark - Utility

static BOOL isTriggerForClickAction(MFActionTriggerType triggerType) {
    return triggerType == kMFActionTriggerTypeButtonDown ||
    triggerType == kMFActionTriggerTypeButtonUp ||
    triggerType == kMFActionTriggerTypeLevelTimerExpired;
}

@end
