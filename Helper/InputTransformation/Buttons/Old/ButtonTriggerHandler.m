////
//// --------------------------------------------------------------------------
//// ButtonTriggerHandler.m
//// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
//// Created by Noah Nuebling in 2020
//// Licensed under MIT
//// --------------------------------------------------------------------------
////
//
//#import "ButtonTriggerHandler.h"
//#import "TransformationManager.h"
//#import "ModifierManager.h"
//#import "Constants.h"
//#import "Actions.h"
//#import "SharedUtility.h"
//#import "ButtonTriggerGenerator.h"
//#import "ButtonTriggerHandler.h"
//#import "ButtonLandscapeAssessor.h"
////#import "Utility_Transformation.h"
//#import "Mac_Mouse_Fix_Helper-Swift.h"
//
//@implementation ButtonTriggerHandler
//
//#pragma mark - Handle triggers
//
//+ (MFEventPassThroughEvaluation)handleButtonTriggerWithButton:(NSNumber *)button triggerType:(MFActionTriggerType)triggerType clickLevel:(NSNumber *)level device:(NSNumber *)devID {
//    
//    DDLogDebug(@"HANDLING BUTTON TRIGGER - button: %@, triggerType: %@, level: %@, devID: %@", button, @(triggerType), level, devID);
//    
//    /// Get remaps and apply modifier overrides
//    NSDictionary *remaps = TransformationManager.remaps;
//    NSDictionary *modifiersActingOnThisButton = [ModifierManager getActiveModifiersForDevice:&devID filterButton:button event:nil];
//    /// ^ The modifiers which act on the incoming button (the button can't modify itself so we filter it out)
//    
//    NSDictionary *modificationsForModifiersActingOnThisButton = remaps[modifiersActingOnThisButton];
//    NSDictionary *modificationsActingOnThisButton = RemapSwizzler.swizzler(remaps, modifiersActingOnThisButton);
//    
////    DDLogDebug(@"\nActive mods: %@, \nremapsForActiveMods: %@", modifiersActingOnThisButton, remapsForModifiersActingOnThisButton);
//    
//    /// If no remaps exist for this button, let the CGEvent which caused this function call pass through (Only if this function was invoked as a direct result of a physical button press)
//    if (triggerType == kMFActionTriggerTypeButtonDown || triggerType == kMFActionTriggerTypeButtonUp) {
//        if (![ButtonLandscapeAssessor effectExistsForButton:button
//                                                     remaps:remaps
//                                modificationsActingOnButton:modificationsActingOnThisButton]) {
//            DDLogDebug(@"No remaps exist for this button, letting event pass through");
//            return kMFEventPassThroughApproval;
//        }
//    }
//    
//    /// Asses mapping landscape
//    /// \note It's unnecessary to assess mapping landscape (that includes calculating targetTrigger) on click actions again for every call of this function. It only has to be calculated once for every "click" (as opposed to "hold") actionArray in every possible overriden remapDict including the unoverriden one. We could precalculate everything once when loading remapDict if we wanted to. This is plenty fast though so it's fine.
//    
////    NSDictionary *activeModifiers = [ModifierManager getActiveModifiersForDevice:&devID filterButton:nil event:nil];
//    ///      ^ We need to check whether the incoming button is acting as a modifier to determine
//    ///          `effectForMouseDownStateOfThisLevelExists`, so we can't just use the variable `modifiersActingOnThisButton` defined above, because it filters out the incoming button
//    ///             Update: Apparently we don't need this anymore?
//    
//    BOOL clickActionOfThisLevelExists;
//    BOOL effectForMouseDownStateOfThisLevelExists;
//    BOOL effectOfGreaterLevelExists;
//    [ButtonLandscapeAssessor assessMappingLandscapeWithButton:button
//                                                        level:level
//                              modificationsActingOnThisButton:modificationsActingOnThisButton
//                                                       remaps:remaps
//                                                thisClickDoBe:&clickActionOfThisLevelExists
//                                                 thisDownDoBe:&effectForMouseDownStateOfThisLevelExists
//                                                  greaterDoBe:&effectOfGreaterLevelExists];
//    
//    // DDLogDebug(@"ACTIVE MODIFIERS - %@", activeModifiersUnfiltered);
//    
//    /// Send trigger (if apropriate)
//    
//    if (isTriggerForClickAction(triggerType)) {
//        
//        /// Find targetTriggerType based on mapping landscape assessment
//        MFActionTriggerType targetTriggerType = kMFActionTriggerTypeNone;
//        if (effectOfGreaterLevelExists) {
//            targetTriggerType = kMFActionTriggerTypeLevelTimerExpired;
//        } else if (effectForMouseDownStateOfThisLevelExists) {
//            targetTriggerType = kMFActionTriggerTypeButtonUp;
//        } else {
//            targetTriggerType = kMFActionTriggerTypeButtonDown;
//        }
//        
//        /// Execute action if incoming trigger matches target trigger
//        if (triggerType == targetTriggerType) executeClickOrHoldActionIfItExists(kMFButtonTriggerDurationClick,
//                                                                                 devID,
//                                                                                 button,
//                                                                                 level,
//                                                                                 modifiersActingOnThisButton,
//                                                                                 modificationsForModifiersActingOnThisButton,
//                                                                                 modificationsActingOnThisButton);
//    } else if (triggerType == kMFActionTriggerTypeHoldTimerExpired) {
//        
//        /// If trigger is for hold action, execute hold action
//        
//        executeClickOrHoldActionIfItExists(kMFButtonTriggerDurationHold,
//                                           devID,
//                                           button,
//                                           level,
//                                           modifiersActingOnThisButton,
//                                           modificationsForModifiersActingOnThisButton,
//                                           modificationsActingOnThisButton);
//    }
//    
//    
//    return kMFEventPassThroughRefusal;
//    
//}
//
//#pragma mark - Execute actions
//
//static void executeClickOrHoldActionIfItExists(NSString * _Nonnull duration,
//                                               NSNumber * _Nonnull devID,
//                                               NSNumber * _Nonnull button,
//                                               NSNumber * _Nonnull level,
//                                               NSDictionary *modifiersActingOnThisButton,
//                                               NSDictionary *modificationsForModifiersActingOnThisButton,
//                                               NSDictionary *modificationsActingOnThisButton) {
//    
//    NSArray *effectiveActionArray = modificationsActingOnThisButton[button][level][duration];
//    if (effectiveActionArray) { /// click/hold action does exist for this button + level
//        
//        if ([effectiveActionArray[0][kMFActionDictKeyType] isEqualToString: kMFActionDictTypeAddModeFeedback]) {
//            /// Add modificationPrecondition info for addMode. See TransformationManager -> AddMode for context
//            
//            effectiveActionArray[0][kMFRemapsKeyModificationPrecondition] = [ModifierManager getActiveModifiersForDevice:&devID filterButton:button event:nil despiteAddMode:YES];
//            /// ^ These are the actual modifiersActingOnThisButton. But for addMode we needed to set the argument `modifiersActingOnThisButton` to `@{}`, so we need to get the real value here.
//        }
//        /// Execute action
//        [Actions executeActionArray:effectiveActionArray];
//        /// Notify triggering button
//        [ButtonTriggerGenerator handleButtonHasHadDirectEffectWithDevice:devID button:button];
//        /// Notify modifying buttons if executed action depends on active modification
//        ///     Edit: This doesn't make sense on two levels. 1. Calling handleModifiersHaveHadEffect shouldn't do anything because we're processing button input, so any other modifying button's state has already been reset when this button came in. 2. This logic stems from when we still had simple overriding of the modificiations. Where we just took the modifications for the empty precondition E and overrode them with the modifications for the activeModifiers A. When that was still the case, `actionArrayFromActiveModification` told us whether the action we just executed stemmed from E or A. Now that we use complex overriding, this `actionArrayFromActiveModification` doesn't tell us anything useful, as it's currently defined.
//        ///     TODO: Remove the `actionStemsFromModification` check and maybe `handleModifiersHaveHadEffectWithDevice:` too
//        NSArray *actionArrayFromActiveModification = modificationsForModifiersActingOnThisButton[button][level][duration];
//        BOOL actionStemsFromModification = [effectiveActionArray isEqual:actionArrayFromActiveModification];
//        if (actionStemsFromModification) {
//            [ModifierManager handleModifiersHaveHadEffectWithDevice:devID activeModifiers:modifiersActingOnThisButton];
//        }
//    }
//}
//
//#pragma mark - Utility
//
//static BOOL isTriggerForClickAction(MFActionTriggerType triggerType) {
//    return triggerType == kMFActionTriggerTypeButtonDown ||
//    triggerType == kMFActionTriggerTypeButtonUp ||
//    triggerType == kMFActionTriggerTypeLevelTimerExpired;
//}
//
//@end
