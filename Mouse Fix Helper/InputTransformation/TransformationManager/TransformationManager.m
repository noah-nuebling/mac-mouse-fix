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
#import "Utility_HelperApp.h"
#import "ButtonInputParser.h"
#import "Actions.h"
#import "ModifierManager.h"
#import "ModifiedDrag.h"
#import "NSArray+Additions.h"

@implementation TransformationManager

#pragma mark - Trigger handling

+ (void)handleDragTrigger {
    
}

+ (void)handleScrollTrigger {
    
}

+ (MFEventPassThroughEvaluation)handleButtonTriggerWithButton:(NSNumber *)button triggerType:(MFActionTriggerType)triggerType clickLevel:(NSNumber *)level device:(NSNumber *)devID {
          
            NSLog(@"HANDLE BUTTON TRIGGER - button: %@, trigger: %@, level: %@, devID: %@", button, @(triggerType), level, devID);
    
    
    // Init passThroughEval
    MFEventPassThroughEvaluation passThroughEval = kMFEventPassThroughApproval;
    
    // Get remaps and apply modifier overrides
    
    NSDictionary *remaps = _testRemaps;
    NSDictionary *effectiveRemaps = remaps[@{}];
    NSDictionary *activeModifiersFiltered = [ModifierManager getActiveModifiersWithDevice:devID filterButton:button];
    if ([activeModifiersFiltered isNotEqualTo:@{}]) {
        NSDictionary *remapsForActiveModifiers = remaps[activeModifiersFiltered];
        effectiveRemaps = [Utility_HelperApp dictionaryWithOverridesAppliedFrom:[remapsForActiveModifiers copy] to:effectiveRemaps];
    }
    
    NSLog(@"ACTIVE MODS FILTERED - %@", activeModifiersFiltered);
    
    // Asses mapping landscape
    
    // \note It's unnecessary to assess mapping landscape (that includes calculating targetTrigger) on click actions again for every call of this function. It only has to be calculated once for every "click" (as opposed to "hold") actionArray in every possible overriden remapDict including the unoverriden one. We could precalculate everything once when loading remapDict if we wanted to. This is plenty fast though so it's fine.
    
    NSDictionary *activeModifiersUnfiltered = [ModifierManager getActiveModifiersWithDevice:devID filterButton:nil];
    BOOL clickActionOfThisLevelExists;
    BOOL mouseDownStateOfThisLevelCanHaveEffect;
    BOOL effectOfGreaterLevelExists;
    assessMappingLandscape(&clickActionOfThisLevelExists,
                           &mouseDownStateOfThisLevelCanHaveEffect,
                           &effectOfGreaterLevelExists,
                           button,
                           level,
                           remaps,
                           activeModifiersUnfiltered,
                           effectiveRemaps);
    
    // If no remaps exist for this button, (and if this functions was invoked as a direct result of a physical button press) let the CGEvent which caused this function call pass through
    
    if (triggerType == kMFActionTriggerTypeButtonDown || triggerType == kMFActionTriggerTypeButtonUp) {
        NSDictionary *remapsForThisButton = effectiveRemaps[button];
        if (remapsForThisButton == nil) {
            NSLog(@"No remaps exist for this button, letting event pass through");
            return kMFEventPassThroughApproval;
        }
    }
    
    NSLog(@"ACTIVE MODS UNFILTERED - %@", activeModifiersUnfiltered);
    
    // TODO: Send Feedback to ButtonInputParser if button has been used as modifier (by calling `handleHasHadEffectAsModifierWithDevice:button:`)
    
    // If trigger is for click action, calculate targetTrigger, that is, the trigger on which the click action should be executed,
    //      and then execute the click action array if the incoming trigger matches the target trigger
    
    if (isTriggerForClickAction(triggerType)) {
        
        // Find target trigger
        MFActionTriggerType targetTriggerForClickAction = kMFActionTriggerTypeNone;
        if (effectOfGreaterLevelExists) {
            targetTriggerForClickAction = kMFActionTriggerTypeLevelTimerExpired;
        } else if (mouseDownStateOfThisLevelCanHaveEffect) {
            targetTriggerForClickAction = kMFActionTriggerTypeButtonUp;
        } else {
            targetTriggerForClickAction = kMFActionTriggerTypeButtonDown;
        }
        
        // Execute click action array if incoming trigger matches target trigger
        if (triggerType == targetTriggerForClickAction) {
            NSArray *actionArrayForClickTrigger = effectiveRemaps[button][level][@"click"];
            if (actionArrayForClickTrigger) {
                [ButtonInputParser handleHasHadDirectEffectWithDevice:devID button:button];
                [Actions handleActionArray:actionArrayForClickTrigger];
            }
        }
    }
    
    // If trigger is for hold action, execute hold action array
    
    if (triggerType == kMFActionTriggerTypeHoldTimerExpired) {
        NSArray *actionArrayForHoldTrigger = effectiveRemaps[button][level][@"hold"];
        if (actionArrayForHoldTrigger) {
            [ButtonInputParser handleHasHadDirectEffectWithDevice:devID button:button];
            [Actions handleActionArray:actionArrayForHoldTrigger];
        }
    }
    
//    if (triggerType == kMFActionTriggerTypeButtonDown) {
//        NSArray *modifyingActionArrayForInput = remapDict[@(button)][@(level)][@"modifying"];
//        MFActivationCondition ac = {
//            .type = kMFActivationConditionTypeMouseButtonPressed,
//            .value = _buttonFromLastButtonDownEvent, // Could also use local `button` variable I think
//            .activatingDevice = _deviceFromLastButtonDownEvent,
//        };
//        [ModifyingActions initializeModifiedInputsWithActionArray:modifyingActionArrayForInput
//                                          withActivationCondition:&ac]; // ??? We only activate modified inputs, they will deactivate themselves once the activation condition becomes false
//    }
    
    return passThroughEval;
    
}

#pragma mark - Utility

#pragma mark Assess mapping landscape

static void assessMappingLandscape(BOOL *clickActionOfThisLevelExists,
                                   BOOL *mouseDownStateOfThisLevelCanHaveEffect,
                                   BOOL *effectOfGreaterLevelExists,
                                   NSNumber *button,
                                   NSNumber *level,
                                   NSDictionary *remaps,
                                   NSDictionary *activeModifiers,
                                   NSDictionary *effectiveRemaps)
{
    *clickActionOfThisLevelExists = effectiveRemaps[button][level][@"click"] != nil;
    *mouseDownStateOfThisLevelCanHaveEffect = effectExistsForMouseDownState(button, level, remaps, activeModifiers, effectiveRemaps);
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

// TODO: Test this v
static BOOL effectOfGreaterLevelExistsFor(NSNumber *button, NSNumber *level, NSDictionary *remaps, NSDictionary *activeModifiers, NSDictionary *effectiveRemaps) {
    
    // Check if effective remaps of a higer level exist for this button
    
    for (NSNumber *thisLevel in ((NSDictionary *)effectiveRemaps[button]).allKeys) {
        if (thisLevel.intValue > level.intValue) {
            return YES;
        }
    }
    
    // Check for modifications
    
    return modificationPreconditionComponentOfGreaterLevelExistsForButton(button, remaps, activeModifiers);
}

static BOOL modificationPreconditionComponentOfGreaterLevelExistsForButton(NSNumber *button, NSDictionary *remaps, NSDictionary *activeModifiers) {
    
    // Check if modification precondition exists such that at least one of its button components has the same button as `button` and a level greater than `level`
    
    for (NSDictionary *modificationPrecondition in remaps.allKeys) {
        
        for (NSNumber *precondButton in modificationPrecondition[@"buttonModifiers"]) {
            if (precondButton.unsignedIntegerValue == button.unsignedIntegerValue) {
                NSNumber *precondLvl = modificationPrecondition[@"buttonModifiers"][precondButton];
                NSNumber *activeLvl = activeModifiers[@"buttonModifiers"][precondButton]; // The same as `level` function argument if thisButton == button
                    // ^ TODO: What happens is this is nil (when `thisButton` isn't active as a modifier)
                BOOL doesExist = precondLvl.unsignedIntegerValue > activeLvl.unsignedIntegerValue;
                if (doesExist) {
                    return YES;
                }
            }
        }
    }

    return NO;
}

// v Unused, replaced by `modificationPreconditionComponentOfGreaterLevelExistsForButton()`
static BOOL modificationExistsWhichWillBeCompletedByButton(NSNumber *button, NSDictionary *remaps, NSDictionary *activeModifiers) {
    
    // Check if a modification exists, such that its modifiers will all be active once this button enters the mouse down state on a higher level
    
    // Another way to phrase this: Check if a modification precondition exists such that all of its components match all the components of the active modifiers, except that the component for this button has a higher level in the precondition compared to the active modifiers.
    
    BOOL modificationOfHigherLevelExists = NO;
    
    for (NSDictionary *modificationPrecondition in remaps.allKeys) {
        
        BOOL keyboardPrecondComponentChecksOut = [modificationPrecondition[@"keyboardModifiers"] isEqual:activeModifiers[@"keyboardModifiers"]];
        if (!keyboardPrecondComponentChecksOut) continue; // Keyboard modifiers don't match, so we know that this `modificationPrecondition` Does not meet our criteria, so we'll look at the next one
        
        BOOL buttonPrecondComponentChecksOut = YES; // True if all buttons check out
        for (NSNumber *thisButton in modificationPrecondition[@"buttonModifiers"]) {
            
            BOOL thisButtonChecksOut;
            
            NSNumber *precondLvl = modificationPrecondition[@"buttonModifiers"][thisButton];
            NSNumber *activeLvl = activeModifiers[@"buttonModifiers"][thisButton]; // The same as `level` function argument if thisButton == button
                // ^ TODO: What happens is this is nil (when `thisButton` isn't active as a modifier)
            
            if (thisButton.unsignedIntegerValue == button.unsignedIntegerValue) {
                thisButtonChecksOut = precondLvl.unsignedIntegerValue > activeLvl.unsignedIntegerValue;
            } else {
                thisButtonChecksOut = precondLvl.unsignedIntegerValue == activeLvl.unsignedIntegerValue;
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



#pragma mark - Dummy Data

NSDictionary *_testRemaps;
NSArray *_testRemapsUI;
+ (void)load {
    _testRemaps = @{
        @{}: @{                                                     // Key: modifier dict (empty -> no modifiers)
            @(3): @{                                                // Key: button
                @(1): @{                                            // Key: level
                    @"click": @[                                  // Key: click/hold, value: array of actions
                        @{
                            @"type": @"symbolicHotkey",
                            @"value": @(33),
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
//                @(2): @{                                            // Key: level
//                        @"click": @[                                  // Key: click/hold, value: array of actions
//                            @{
//                                @"type": @"symbolicHotkey",
//                                @"value": @(36),
//                            },
//                        ],
//
//                        @"modifying": @[                                    // Key: click/hold, value: array of actions
//                        @{
//                            @"type": @"modifiedDrag",
//                            @"value": @"twoFingerSwipe",
//                        },
//                    ],
//                },
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
                            @"type": @"symbolicHotkey",
                            @"value": @(160),
                        },
                    ],
                },
            },
            
        },
        
        @{                                                          // Key: modifier dict
            @"buttonModifiers": @{
                    @(3): @(2),                                      // btn, lvl
                    @(4): @(1)
            },
            @"keyboardModifiers": @(
                NSEventModifierFlagControl
                ),
        }: @{
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
