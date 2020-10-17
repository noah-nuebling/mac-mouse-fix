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

BOOL isTriggerForClickAction(MFActionTriggerType triggerType) {
    return triggerType == kMFActionTriggerTypeButtonDown ||
    triggerType == kMFActionTriggerTypeButtonUp ||
    triggerType == kMFActionTriggerTypeLevelTimerExpired;
}

static void assessMappingLandscape(BOOL *actionOfGreaterLevelExists, BOOL *actionOfSameLevelWithMouseDownStateDependencyExists, NSNumber *button, NSNumber *level, NSDictionary *remaps) {
    *actionOfSameLevelWithMouseDownStateDependencyExists = [TransformationManager holdActionExistsForButton:button clickLevel:level remapDict:remaps]
    || [TransformationManager modifyingActionExistsForButton:button clickLevel:level remapDict:remaps];
    *actionOfGreaterLevelExists = [TransformationManager actionOfGreaterClickLevelExistsForButton:button clickLevel:level remapDict:remaps];
}

+ (MFEventPassThroughEvaluation)handleButtonTriggerWithButton:(NSNumber *)button trigger:(MFActionTriggerType)trigger level:(NSNumber *)level device:(NSNumber *)devID {
          
    NSLog(@"HANDLE BUTTON TRIGGER - button: %@, trigger: %@, level: %@, devID: %@", button, @(trigger), level, devID);
    
    MFEventPassThroughEvaluation passThroughEval = true;
    
    // Get remapDict and apply modifier overrides
    
    NSDictionary *remaps = _testRemaps[@{}];
    
    NSDictionary *modifiers = [self getActiveModifiers];
    if ([modifiers isNotEqualTo:@{}]) {
        NSDictionary *remapsForActiveModifiers = _testRemaps[modifiers];
        remaps = [Utility_HelperApp dictionaryWithOverridesAppliedFrom:[remapsForActiveModifiers copy] to:remaps];
    }
    
    // Asses mapping landscape
    BOOL actionOfSameLevelWithMouseDownStateDependencyExists;
    BOOL actionOfGreaterLevelExists;
    assessMappingLandscape(&actionOfGreaterLevelExists, &actionOfSameLevelWithMouseDownStateDependencyExists, button, level, remaps);
    
    // If no remaps exist for this button, let the event which caused this function call pass through
    
    if (trigger == kMFActionTriggerTypeButtonDown || trigger == kMFActionTriggerTypeButtonUp) {
        // ^ The passThroughEval return value only does anything on trigger types that are caused directly by mouse input (kMFActionTriggerTypeButtonDown and kMFActionTriggerTypeButtonUp) so this condition isn't totally necessary
        
        NSArray *clickAction = remaps[button][level][@"click"];
        
        if (clickAction == nil
            && !actionOfSameLevelWithMouseDownStateDependencyExists
            && !actionOfGreaterLevelExists)
        {
            NSLog(@"No remaps exist for this button, letting event pass through");
            return kMFEventPassThroughApproval;
        }
    }
    
    // If trigger is for click action, calculate targetTrigger, that is, the trigger on which the click action should be executed.
    
    // \note It's unnecessary to calculate targetTrigger on click actions again for every call of this function. It only has to be calculated once for every "click" (as opposed to "hold") actionArray in every possible overriden remapDict including the unoverriden one. We could precalculate everything once when loading remapDict if we wanted to. This is plenty fast though so it's fine.
    
    if (isTriggerForClickAction(trigger)) {
        
        // Find target trigger
        
        MFActionTriggerType targetTriggerForClickAction = kMFActionTriggerTypeNone;
        if (actionOfGreaterLevelExists) {
            targetTriggerForClickAction = kMFActionTriggerTypeLevelTimerExpired;
        } else if (actionOfSameLevelWithMouseDownStateDependencyExists) {
            targetTriggerForClickAction = kMFActionTriggerTypeButtonUp;
        } else {
            targetTriggerForClickAction = kMFActionTriggerTypeButtonDown;
        }
        
        // Execute OneShotActionArray if incoming trigger matches target trigger
        
        if (trigger == targetTriggerForClickAction) {
            NSArray *actionArrayForClickTrigger = remaps[button][level][@"click"];
            if (actionArrayForClickTrigger) {
                [ButtonInputParser handleHasHadDirectEffectWithDevice:devID button:button];
                [Actions handleActionArray:actionArrayForClickTrigger];
            }
        }
    }
    
    // If trigger is for hold action, trigger is right away
    
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

#pragma mark Determine target trigger for click actions

+ (BOOL)holdActionExistsForButton:(NSNumber *)button clickLevel:(NSNumber *)level remapDict:(NSDictionary *)remapDict {
    return remapDict[button][level][@"hold"] != nil;
}

+ (BOOL)modifyingActionExistsForButton:(NSNumber *)button clickLevel:(NSNumber *)level remapDict:(NSDictionary *)remapDict {
    return remapDict[button][level][@"modifying"] != nil;
}

+ (BOOL)actionOfGreaterClickLevelExistsForButton:(NSNumber *)button clickLevel:(NSNumber *)level remapDict:(NSDictionary *)remapDict {
    BOOL actionOfGreaterLevelExists = NO;
    for (NSNumber *thisLevel in ((NSDictionary *)remapDict[button]).allKeys) {
        if (thisLevel.intValue > level.intValue) {
            actionOfGreaterLevelExists = YES;
            break;
        }
    }
    return actionOfGreaterLevelExists;
}

#pragma mark Modifiers

+ (NSDictionary *)getActiveModifiers {
    return @{
        @"keyboard": @([self getActiveKeyboardModifiers]),
        @"button": @([self getActiveButtonModifiers])
    };
}
+ (NSUInteger)getActiveKeyboardModifiers {
    NSEventModifierFlags modifierFlags = [NSEvent modifierFlags]
        & NSDeviceIndependentModifierFlagsMask; // Not sure if this does anything
    return modifierFlags;
}

+ (NSUInteger)getActiveButtonModifiers {
    return 0;
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
            @"keyboardModifierFlags": @(NSEventModifierFlagControl),
        }: @{
            @(4): @{                                                // Key: button
                @(1): @{                                            // Key: level
                    @"click": @[                                  // Key: clic/hold, value: array of actions
                        @{
                            @"type": @"twoFingerSwipeEvent",
                            @"value": @"left",
                        },
                    ],
                },
            },
            @(5): @{                                                // Key: button
                @(1): @{                                            // Key: level
                    @"click": @[                                  // Key: click/hold, value: array of actions
                        @{
                            @"type": @"twoFingerSwipeEvent",
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
