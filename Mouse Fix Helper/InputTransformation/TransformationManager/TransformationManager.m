//
// --------------------------------------------------------------------------
// TransformationManager.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "TransformationManager.h"
#import "RemapUtility.h"
#import "SharedUtility.h"
#import "ButtonInputParser.h"
#import "Actions.h"
#import "Modifiers.h"
#import "ModifiedDrag.h"
#import "NSArray+Additions.h"
#import "Constants.h"

@implementation TransformationManager

#pragma mark - Interface

#pragma mark Trigger handling

+ (void)handleDragTrigger {
    
}

+ (void)handleScrollTrigger {
    
}
+ (MFEventPassThroughEvaluation)handleButtonTriggerWithButton:(NSNumber *)button triggerType:(MFActionTriggerType)triggerType clickLevel:(NSNumber *)level device:(NSNumber *)devID {
    
            NSLog(@"HANDLE BUTTON TRIGGER - button: %@, trigger: %@, level: %@, devID: %@", button, @(triggerType), level, devID);
    
    // Get remaps and apply modifier overrides
    NSDictionary *remaps = _remaps;
    NSDictionary *activeModifiers = [Modifiers getActiveModifiersForDevice:devID filterButton:button]; // The modifiers which act on the incoming button (the button can't modify itself so we filter it out)
    NSDictionary *effectiveRemaps = getEffectiveRemaps(remaps, activeModifiers);
    NSDictionary *remapsForActiveModifiers = remaps[activeModifiers];
    
    // If no remaps exist for this button, (and if this functions was invoked as a direct result of a physical button press) let the CGEvent which caused this function call pass through
    if (triggerType == kMFActionTriggerTypeButtonDown || triggerType == kMFActionTriggerTypeButtonUp) {
        NSDictionary *remapsForThisButton = effectiveRemaps[button];
        if (remapsForThisButton == nil) {
            NSLog(@"No remaps exist for this button, letting event pass through");
            return kMFEventPassThroughApproval;
        }
    }
    
    // Asses mapping landscape
    // \note It's unnecessary to assess mapping landscape (that includes calculating targetTrigger) on click actions again for every call of this function. It only has to be calculated once for every "click" (as opposed to "hold") actionArray in every possible overriden remapDict including the unoverriden one. We could precalculate everything once when loading remapDict if we wanted to. This is plenty fast though so it's fine.
    
    NSDictionary *activeModifiersUnfiltered = [Modifiers getActiveModifiersForDevice:devID filterButton:nil];
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
        if (triggerType == targetTriggerType) executeClickOrHoldActionIfItExists(@"click",
                                                                                 devID,
                                                                                 button,
                                                                                 level,
                                                                                 activeModifiers,
                                                                                 remapsForActiveModifiers,
                                                                                 effectiveRemaps);
    } else if (triggerType == kMFActionTriggerTypeHoldTimerExpired) {
        
        // If trigger is for hold action, execute hold action
        
        executeClickOrHoldActionIfItExists(@"hold",
                                           devID,
                                           button,
                                           level,
                                           activeModifiers,
                                           remapsForActiveModifiers,
                                           effectiveRemaps);
    }
    
    return kMFEventPassThroughRefusal;
    
}

#pragma mark Other

+ (BOOL)effectOfEqualOrGreaterLevelExistsForDevice:(NSNumber *)devID button:(NSNumber *)button level:(NSNumber *)level {
    
    NSDictionary *remaps = _remaps;
    NSDictionary *activeModifiers = [Modifiers getActiveModifiersForDevice:devID filterButton:nil];
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
    *clickActionOfThisLevelExists = effectiveRemaps[button][level][@"click"] != nil;
    *effectForMouseDownStateOfThisLevelExists = effectExistsForMouseDownState(button, level, remaps, activeModifiers, effectiveRemaps);
    *effectOfGreaterLevelExists = effectOfGreaterLevelExistsFor(button, level, remaps, activeModifiers, effectiveRemaps);
}

static BOOL effectExistsForMouseDownState(NSNumber *button, NSNumber *level, NSDictionary *remaps, NSDictionary *activeModifiers, NSDictionary *effectiveRemaps) {
    BOOL holdActionExists = effectiveRemaps[button][level][@"hold"] != nil;
    BOOL usedAsModifier = isUsedAsModifier(button, level, remaps, activeModifiers);
    
    return holdActionExists || usedAsModifier;
}
static BOOL isUsedAsModifier(NSNumber *button, NSNumber *level, NSDictionary *remaps, NSDictionary *activeModifiers) {
    
    BOOL outVal = NO;
    
    BOOL activeModifiersDoModify = remaps[activeModifiers] != nil;
    if (activeModifiersDoModify) {
        BOOL currentButtonAndLevelAreComponentOfActiveModifers = [activeModifiers[@"buttonModifiers"][button] isEqualToNumber: level];
        outVal = currentButtonAndLevelAreComponentOfActiveModifers;
    }
    
    return outVal;
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
        
        BOOL precondContainsButton = modificationPrecondition[@"buttonModifiers"][button] != nil;
        if (!precondContainsButton) continue;
        
        NSNumber *precondLvl = modificationPrecondition[@"buttonModifiers"][button];
        if (precondLvl.unsignedIntegerValue > level.unsignedIntegerValue) {
            return YES;
        }
    }
    return NO;
}

// v Unused, replaced by `modificationPreconditionButtonComponentOfGreaterLevelExistsForButton()`
static BOOL modificationExistsWhichWillBeCompletedByButton(NSNumber *button, NSDictionary *remaps, NSDictionary *activeModifiers) {
    
    // Check if a modification exists, such that its precondition components will all be active once the incoming button enters the mouse down state on a higher level
    // So a modification which can be brought into effect just by clicking the incoming button some more times
    
    // Another way to phrase this: Check if a modification precondition exists such that all of its components match all the components of the active modifiers, except that the component which represents the incoming button has a higher level than the incoming level
    
    BOOL modificationOfHigherLevelExists = NO;
    
    for (NSDictionary *modificationPrecondition in remaps.allKeys) {
        
        BOOL keyboardPrecondComponentChecksOut = [modificationPrecondition[@"keyboardModifiers"] isEqual:activeModifiers[@"keyboardModifiers"]];
        if (!keyboardPrecondComponentChecksOut) continue; // Keyboard modifiers don't match, so we know that this `modificationPrecondition` Does not meet our criteria, so we'll look at the next one
        
        BOOL buttonPrecondComponentChecksOut = YES; // True if all buttons check out
        for (NSNumber *precondButton in modificationPrecondition[@"buttonModifiers"]) {
            
            BOOL thisButtonChecksOut;
            
            NSNumber *precondLvl = modificationPrecondition[@"buttonModifiers"][precondButton];
            NSNumber *incomingLvl = activeModifiers[@"buttonModifiers"][precondButton]; // The same as `level` function argument if thisButton == button
            // ^ What happens is this is nil (when `thisButton` isn't active as a modifier)
            
            if (precondButton.unsignedIntegerValue == button.unsignedIntegerValue) {
                thisButtonChecksOut = precondLvl.unsignedIntegerValue > incomingLvl.unsignedIntegerValue;
            } else {
                thisButtonChecksOut = precondLvl.unsignedIntegerValue == incomingLvl.unsignedIntegerValue;
            }
            
            if (!thisButtonChecksOut) {
                buttonPrecondComponentChecksOut = NO; // This button doesn't check out, so this `modificationPrecondition` Does not meet our criteria, so we'll look at the next one
                break;
            }
        }
        
        if (buttonPrecondComponentChecksOut) { // Keyboard modifiers and all buttons checked out, so we know our criteria has been met
            modificationOfHigherLevelExists = YES;
        }
    }
    
    return modificationOfHigherLevelExists;
}

static BOOL isTriggerForClickAction(MFActionTriggerType triggerType) {
    return triggerType == kMFActionTriggerTypeButtonDown ||
    triggerType == kMFActionTriggerTypeButtonUp ||
    triggerType == kMFActionTriggerTypeLevelTimerExpired;
}

#pragma mark - Execute actions

static void executeClickOrHoldActionIfItExists(NSString *clickHold,
                                               NSNumber * _Nonnull devID,
                                               NSNumber * _Nonnull button,
                                               NSNumber * _Nonnull level,
                                               NSDictionary *activeModifiers,
                                               NSDictionary *remapsForActiveModifiers,
                                               NSDictionary *effectiveRemaps) {
    
    NSArray *effectiveActionArray = effectiveRemaps[button][level][clickHold];
    if (effectiveActionArray) { // click/hold action does exist for this button + level
        // Execute action
        [Actions executeActionArray:effectiveActionArray];
        // Notify triggering button
        [ButtonInputParser handleButtonHasHadDirectEffectWithDevice:devID button:button];
        // Notify modifying buttons if executed action depends on active modification
        NSArray *actionArrayFromActiveModification = remapsForActiveModifiers[button][level][clickHold];
        BOOL actionStemsFromModification = [effectiveActionArray isEqual:actionArrayFromActiveModification];
        if (actionStemsFromModification) {
            notifyModifyingButtons(devID, activeModifiers);
        }
    }
}
static void notifyModifyingButtons(NSNumber * _Nonnull devID,
                                   NSDictionary *activeModifiers) {
    
    // Notify all active button modifiers that they have had an effect
    for (NSNumber *precondButton in activeModifiers[@"buttonModifiers"]) {
        [ButtonInputParser handleButtonHasHadEffectAsModifierWithDevice:devID button:precondButton];
    }
}

#pragma mark - Dummy Data

NSDictionary *_remaps;
+ (NSDictionary *)remaps {
    return _remaps;
}
NSArray *_remapsUI;
+ (void)load {
    _remaps = @{
        @{}: @{                                                     // Key: modifier dict (empty -> no modifiers)
                @(3): @{                                                // Key: button
                        @(1): @{                                            // Key: level
                                @"hold": @[                                   // Key: click/hold, value: array of actions
                                        @{
                                            @"type": @"symbolicHotkey",
                                            @"value": @(32),
                                        },
                                ],
                                //                    @"hold": @[                                  // Key: click/hold, value: array of actions
                                //                        @{
                                //                            @"type": @"symbolicHotkey",
                                //                            @"value": @(70),
                                //                        },
                                //                    ],
                                //                    @"modifying": @[
                                //                            @{
                                //                                @"type": @"modifiedDrag",
                                //                                @"value": @"threeFingerSwipe",
                                //                            }
                                //                    ]
                        },
                        @(2): @{                                            // Key: level
                                @"hold": @[                                  // Key: click/hold, value: array of actions
                                        @{
                                            @"type": @"symbolicHotkey",
                                            @"value": @(36),
                                        },
                                ],
                                
                        },
                },
                @(4): @{                                                // Key: button
                        @(1): @{                                            // Key: level
                                //                    @"modifying": @[
                                //                            @{
                                //                                @"type": @"modifiedDrag",
                                //                                @"value": @"threeFingerSwipe",
                                //                            }
                                //                    ],
                                @"click": @[
                                        @{
                                            @"type": @"symbolicHotkey",
                                            @"value": @(32),
                                        }
                                ],
                                @"hold": @[
                                        @{
                                            @"type": @"smartZoom",
                                        }
                                ],
                        },
                        @(2): @{                                            // Key: level
                                //                    @"modifying": @[
                                //                            @{
                                //                                @"type": @"modifiedDrag",
                                //                                @"value": @"twoFingerSwipe",
                                //                            }
                                //                    ],
                                @"click": @[
                                        @{
                                            @"type": @"symbolicHotkey",
                                            @"value": @(36),
                                        }
                                ],
                        },
                },
                @(5): @{                                                // Key: button
                        @(1): @{                                            // Key: level
                                @"modifying": @[
                                        @{
                                            @"type": @"modifiedDrag",
                                            @"value": @"twoFingerSwipe",
                                        }
                                ]
                        },
                },
                @(7)  : @{                                                // Key: button
                        @(1): @{                                            // Key: level
                                @"click": @[                                  // Key: click/hold, value: array of actions
                                        @{
                                            kMFActionArrayKeyType: kMFActionArrayTypeSymbolicHotkey,
                                            kMFActionArrayKeyVariant: @(kMFSHLaunchpad),
                                        },
                                ],
                        },
                },
                
        },
        
        @{                                                          // Key: modifier dict
            kMFModifierKeyButtons: @{
                    @(4): @(1),                                      // btn, lvl
            },
            //            @"keyboardModifiers": @(
            //                NSEventModifierFlagControl
            //                ),
        }: @{
                kMFRemapsKeyModifiedDrag: kMFModifiedDragTypeThreeFingerSwipe,
                @(4): @{                                                // Key: button
                        @(1): @{                                            // Key: level
                                @"click": @[                                  // Key: clic/hold, value: array of actions
                                        @{
                                            @"type": @"navigationSwipe",
                                            @"value": @"left",
                                        },
                                ],
                        },
                },
                @(5): @{                                                // Key: button
                        @(1): @{                                            // Key: level
                                @"click": @[                                  // Key: click/hold, value: array of actions
                                        @{
                                            @"type": @"navigationSwipe",
                                            @"value": @"right",
                                        },
                                ],
                        },
                },
        },
    };
    //    _testRemapsUI = @[
    //        @{
    //            @"button": @(3),
    //            @"level": @(1),
    //            @"type": @"click",
    //            @"modifiers": @[],
    //            @"actions": @[
    //                @{
    //                    @"type": @"symbolicHotkey",
    //                    @"value": @(32),
    //                },
    //            ],
    //        },
    //        @{
    //            @"button": @(3),
    //            @"level": @(1),
    //            @"type": @"hold",
    //            @"modifiers": @[],
    //            @"actions": @[
    //                @{
    //                    @"type": @"symbolicHotkey",
    //                    @"value": @(33),
    //                },
    //            ],
    //        },
    //    ];
}

@end
