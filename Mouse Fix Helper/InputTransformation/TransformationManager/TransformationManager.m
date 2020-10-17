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
#import "ModifyingActions.h"
#import "ButtonInputParser.h"
#import "Actions.h"

@implementation TransformationManager

#pragma mark - Trigger handling

+ (void)handleDragTrigger {
    
}

+ (void)handleScrollTrigger {
    
}

+ (MFEventPassThroughEvaluation)handleButtonTriggerWithButton:(NSNumber *)button trigger:(MFActionTriggerType)trigger level:(NSNumber *)level device:(NSNumber *)devID {
          
            //NSLog(@"HANDLE BUTTON TRIGGER - button: %@, trigger: %@, level: %@, devID: %@", button, @(trigger), level, devID);
    
    
    // Init passThroughEval
    MFEventPassThroughEvaluation passThroughEval = kMFEventPassThroughApproval;
    
    // Get remaps and apply modifier overrides
    NSDictionary *remaps = _testRemaps[@{}];
    NSDictionary *modifiers = [self getActiveModifiers];
    if ([modifiers isNotEqualTo:@{}]) {
        NSDictionary *remapsForActiveModifiers = _testRemaps[modifiers];
        remaps = [Utility_HelperApp dictionaryWithOverridesAppliedFrom:[remapsForActiveModifiers copy] to:remaps];
    }
    
    // Asses mapping landscape
    
    // \note It's unnecessary to assess mapping landscape (that includes calculating targetTrigger) on click actions again for every call of this function. It only has to be calculated once for every "click" (as opposed to "hold") actionArray in every possible overriden remapDict including the unoverriden one. We could precalculate everything once when loading remapDict if we wanted to. This is plenty fast though so it's fine.
    
    BOOL clickActionOfThisLevelExists;
    BOOL mouseDownStateOfThisLevelCanHaveEffect;
    BOOL effectOfGreaterLevelExists;
    assessMappingLandscape(&clickActionOfThisLevelExists, &mouseDownStateOfThisLevelCanHaveEffect, &effectOfGreaterLevelExists, button, level, remaps);
    
    // If no remaps exist for this button, (and if this functions was invoked as a direct result of a physical button press) let the CGEvent which caused this function call pass through
    
    if (trigger == kMFActionTriggerTypeButtonDown || trigger == kMFActionTriggerTypeButtonUp) {
        NSDictionary *remapsForThisButton = remaps[button];
        if (remapsForThisButton == nil) {
            NSLog(@"No remaps exist for this button, letting event pass through");
            return kMFEventPassThroughApproval;
        }
    }
    
    NSArray *clickAction = remaps[button][level][@"click"];
    
    if (clickAction == nil
        && !mouseDownStateOfThisLevelCanHaveEffect
        && !effectOfGreaterLevelExists)
    {

    }
    
    // If trigger is for click action, calculate targetTrigger, that is, the trigger on which the click action should be executed,
    //      and then execute the click action array if the incoming trigger matches the target trigger
    
    if (isTriggerForClickAction(trigger)) {
        
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
        if (trigger == targetTriggerForClickAction) {
            NSArray *actionArrayForClickTrigger = remaps[button][level][@"click"];
            if (actionArrayForClickTrigger) {
                [ButtonInputParser handleHasHadDirectEffectWithDevice:devID button:button];
                [Actions handleActionArray:actionArrayForClickTrigger];
            }
        }
    }
    
    // If trigger is for hold action, execute hold action array
    
    if (trigger == kMFActionTriggerTypeHoldTimerExpired) {
        NSArray *actionArrayForHoldTrigger = remaps[button][level][@"hold"];
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
                                   NSDictionary *remaps)
{
    *clickActionOfThisLevelExists = remaps[button][level][@"click"] != nil;
    *mouseDownStateOfThisLevelCanHaveEffect = effectExistsForMouseDownState(button, level, remaps);
    *effectOfGreaterLevelExists = effectOfGreaterLevelExistsFor(button, level, remaps);
}

static BOOL effectExistsForMouseDownState(NSNumber *button, NSNumber *level, NSDictionary *remaps) {
    BOOL holdActionExists = remaps[button][level][@"hold"] != nil;
    BOOL usedAsModifier = isUsedAsModifier(button, level, remaps);
    
    return holdActionExists || usedAsModifier;
}
static BOOL isUsedAsModifier(NSNumber *button, NSNumber *level, NSDictionary *remaps) {
    return NO; // TODO: Implement
}
static BOOL effectOfGreaterLevelExistsFor(NSNumber *button, NSNumber *level, NSDictionary *remaps) {
    BOOL actionOfGreaterLevelExists = NO;
    for (NSNumber *thisLevel in ((NSDictionary *)remaps[button]).allKeys) {
        if (thisLevel.intValue > level.intValue) {
            actionOfGreaterLevelExists = YES;
            break;
        }
    }
    
    // TODO: Check for usage as modifier on higher level
    
    return actionOfGreaterLevelExists;
}

static BOOL isTriggerForClickAction(MFActionTriggerType triggerType) {
    return triggerType == kMFActionTriggerTypeButtonDown ||
    triggerType == kMFActionTriggerTypeButtonUp ||
    triggerType == kMFActionTriggerTypeLevelTimerExpired;
}

#pragma mark Modifiers

+ (NSDictionary *)getActiveModifiers {
    
    NSMutableDictionary *outDict = [NSMutableDictionary dictionary];
    
    NSUInteger kb = [self getActiveKeyboardModifiers];
    NSDictionary *btn = [self getActiveButtonModifiers];
    
    if (kb != 0) {
        outDict[@"keyboard"] = @(kb);
    }
    if (btn != 0) {
        outDict[@"button"] = btn;
    }
    
    return outDict;
}
+ (NSUInteger)getActiveKeyboardModifiers {
    NSEventModifierFlags modifierFlags = [NSEvent modifierFlags]
        & NSDeviceIndependentModifierFlagsMask; // Not sure if this does anything
    return modifierFlags;
}

+ (NSDictionary *)getActiveButtonModifiers {
    return nil;
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
                    @"hold": @[                                  // Key: click/hold, value: array of actions
                        @{
                            @"type": @"symbolicHotkey",
                            @"value": @(70),
                        },
                    ],
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
            @"keyboard": @(NSEventModifierFlagControl),
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
