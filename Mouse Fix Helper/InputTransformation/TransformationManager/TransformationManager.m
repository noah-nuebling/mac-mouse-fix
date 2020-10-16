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

+ (MFEventPassThroughEvaluation)handleButtonTriggerWithButton:(int64_t)button triggerType:(MFActionTriggerType)triggerType level:(int64_t)level {
    
    MFEventPassThroughEvaluation passThroughEval = true;
    
    // Get remapDict and apply modifier overrides
    
    NSDictionary *remapDict = _testRemaps[@{}];
    
    NSDictionary *modifiers = [self getActiveModifiers];
    if ([modifiers isNotEqualTo:@{}]) {
        NSDictionary *actionsForCurrentModifiers = _testRemaps[modifiers];
        remapDict = [Utility_HelperApp dictionaryWithOverridesAppliedFrom:[actionsForCurrentModifiers copy] to:remapDict];
    }
    
    // Get OneShotActionArray for click input and calculate targetTrigger, that is, the trigger on which the click action should be executed.
    // \note It's unnecessary to calculate targetTrigger on click actions again for every call of this function. It only has to be calculated once for every "click" (as opposed to "hold") actionArray in every possible overriden remapDict including the unoverriden one. We could precalculate everything once when loading remapDict if we wanted to. This is plenty fast though so it's fine.
    
    MFActionTriggerType targetClickTriggerForOneShotActionArray = kMFActionTriggerTypeNone;
    
    if (triggerType == kMFActionTriggerTypeButtonDown ||
        triggerType == kMFActionTriggerTypeButtonUp ||
        triggerType == kMFActionTriggerTypeLevelTimerExpired) {
        
        // ^ The incoming triggers is for "click" actions.
        // -> Get the relevant "click" action and calculate on which of the three possible triggers we want to execute it.
        
        BOOL actionOfGreaterLevelExists = [self actionOfGreaterClickLevelExistsForButton:button clickLevel:level remapDict:remapDict];
        BOOL actionOfSameLevelWithHoldTriggerOrWhichIsModifyingExists
            = [self holdActionExistsForButton:button clickLevel:level remapDict:remapDict]
            || [self modifyingActionExistsForButton:button clickLevel:level remapDict:remapDict];
        
        // Set target trigger
        
        if (actionOfGreaterLevelExists) {
            targetClickTriggerForOneShotActionArray = kMFActionTriggerTypeLevelTimerExpired;
        } else if (actionOfSameLevelWithHoldTriggerOrWhichIsModifyingExists) {
            targetClickTriggerForOneShotActionArray = kMFActionTriggerTypeButtonUp;
        } else {
            targetClickTriggerForOneShotActionArray = kMFActionTriggerTypeButtonDown;
        }
        
        // Let the input event which caused this function call pass through, if no remaps exist for this button.
        // TODO: Think about this and make sure that the condition is true if and only if no remaps exist for this button
        
        NSArray *OneShotActionArrayForClickTrigger = remapDict[@(button)][@(level)][@"click"];
        if (
            ((triggerType == kMFActionTriggerTypeButtonDown) || (triggerType == kMFActionTriggerTypeButtonUp))
            // ^ The passThroughEval return value only does anything on trigger types that are caused directly by mouse input (kMFActionTriggerTypeButtonDown and kMFActionTriggerTypeButtonUp) so this condition isn't really necessary
            && OneShotActionArrayForClickTrigger == nil
            && !actionOfGreaterLevelExists
            && !actionOfSameLevelWithHoldTriggerOrWhichIsModifyingExists
            )
        {
            passThroughEval = kMFEventPassThroughApproval; // TODO: Couldn't we return here immediately?
        }
    }
    
    
    // Execute OneShotActionArray
    
    if (triggerType == targetClickTriggerForOneShotActionArray) {
        NSArray *OneShotActionArrayForClickTrigger = remapDict[@(button)][@(level)][@"click"];
        if (OneShotActionArrayForClickTrigger) {
            [ButtonInputParser handleHasHadDirectEffectWithDevice:devID button:<#(NSNumber *)#>];
            [Actions handleActionArray:OneShotActionArrayForClickTrigger];
        }
    }
    if (triggerType == kMFActionTriggerTypeHoldTimerExpired) {
        NSArray *OneShotActionArrayForHoldTrigger = remapDict[@(button)][@(level)][@"hold"];
        if (OneShotActionArrayForHoldTrigger) {
            [ButtonInputParser reset];
            [Actions handleActionArray:OneShotActionArrayForHoldTrigger];
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

+ (BOOL)holdActionExistsForButton:(int64_t)button clickLevel:(int64_t)level remapDict:(NSDictionary *)remapDict {
    return remapDict[@(button)][@(level)][@"hold"] != nil;
}

+ (BOOL)modifyingActionExistsForButton:(int64_t)button clickLevel:(int64_t)level remapDict:(NSDictionary *)remapDict {
    return remapDict[@(button)][@(level)][@"modifying"] != nil;
}

+ (BOOL)actionOfGreaterClickLevelExistsForButton:(int64_t)button clickLevel:(int64_t)level remapDict:(NSDictionary *)remapDict {
    BOOL actionOfGreaterLevelExists = NO;
    for (NSNumber *thisLevel in ((NSDictionary *)remapDict[@(button)]).allKeys) {
        if (thisLevel.intValue > level) {
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
                            @"value": @(70),
                        },
                    ],
//                    @"hold": @[                                  // Key: click/hold, value: array of actions
//                        @{
//                            @"type": @"symbolicHotkey",
//                            @"value": @(33),
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
                    @"modifying": @[
                            @{
                                @"type": @"modifiedDrag",
                                @"value": @"threeFingerSwipe",
                            }
                    ],
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
