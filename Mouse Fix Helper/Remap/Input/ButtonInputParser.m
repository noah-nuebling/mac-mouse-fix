//
// --------------------------------------------------------------------------
// ButtonInputParser.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

// SensibleSideButtons, a utility that fixes the navigation buttons on third-party mice in macOS
// Copyright (C) 2018 Alexei Baboulevitch (ssb@archagon.net)
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
//

#import "ButtonInputParser.h"
#import "OneShotActions.h"
#import "ModifyingActions.h"
#import "RemapUtility.h"
#import "Utility_HelperApp.h"
#import "ConfigFileInterface_HelperApp.h"
#import "GestureScrollSimulator.h"

@implementation ButtonInputParser


NSDictionary *_testRemaps;
NSArray *_testRemapsUI;
+ (void)load {
    _testRemaps = @{
        @{}: @{                                                     // Key: modifier dict
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
                    @"click": @[                                  // Key: clic/hold, value: array of actions
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


static NSTimer *_levelTimer;
static NSTimer *_holdTimer;
static int64_t _buttonFromLastButtonDownEvent;
static MFDevice *_deviceFromLastButtonDownEvent;
static int64_t _clickLevel;
+ (void)reset {
    [_levelTimer invalidate];
    [_holdTimer invalidate];
    _clickLevel = 0;
//    _buttonFromLastMouseDown = 0; // TODO: This broke ending modified drags on releasing the modifying mouse button. I'm not sure what it was good for so I commented it out.
}
+ (MFEventPassThroughEvaluation)sendActionTriggersForInputWithButton:(int64_t)button type:(MFButtonInputType)type inputDevice:device {
    
    MFEventPassThroughEvaluation passThroughEval = kMFEventPassThroughApproval;
    
     if (type == kMFButtonInputTypeButtonDown) {
         
         if (button != _buttonFromLastButtonDownEvent || device != _deviceFromLastButtonDownEvent) {
             [self reset];
             _buttonFromLastButtonDownEvent = button;
             _deviceFromLastButtonDownEvent = device;
         }
         
         if ([_levelTimer isValid]) {
            _clickLevel += 1;
         } else {
             _clickLevel = 1;
         }
        passThroughEval = [self handleActionTriggerWithButton:button triggerType:kMFActionTriggerTypeButtonDown level:_clickLevel];
        [_levelTimer invalidate];
        [_holdTimer invalidate];
        _holdTimer = [NSTimer scheduledTimerWithTimeInterval:0.25
                                                      target:self
                                                    selector:@selector(holdTimerCallback:)
                                                    userInfo:@(button)
                                                     repeats:NO];
         _levelTimer = [NSTimer scheduledTimerWithTimeInterval:0.25 // NSEvent.doubleClickInterval
                                                       target:self
                                                     selector:@selector(levelTimerCallback:)
                                                     userInfo:@(button)
                                                      repeats:NO];
     } else { // if (type == kMFButtonInputTypeButtonUp)
         
         passThroughEval = [self handleActionTriggerWithButton:button triggerType:kMFActionTriggerTypeButtonUp level:_clickLevel];
         
//         if ([_holdTimer isValid]) { // TODO: Find a way to make click actions trigger on mouse up after hold timer expired, if the reason that the click action is triggered on mouse up is not a hold action on the same button and click level (-> if it's a modifying action)
//             passThroughEval =
//         } else {
//             [ModifyingActions deactivateAllInputModification];
//         }
//        [_holdTimer invalidate];
         
         
     }
    return passThroughEval;
}
+ (void)holdTimerCallback:(NSTimer *)timer {
//    int button = [[timer userInfo] intValue];
    [self handleActionTriggerWithButton:_buttonFromLastButtonDownEvent triggerType:kMFActionTriggerTypeHoldTimerExpired level:_clickLevel];
}
+ (void)levelTimerCallback:(NSTimer *)timer {
//    int button = [[timer userInfo] intValue];
    [self handleActionTriggerWithButton:_buttonFromLastButtonDownEvent triggerType:kMFActionTriggerTypeLevelTimerExpired level:_clickLevel];
}


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

+ (MFEventPassThroughEvaluation)handleActionTriggerWithButton:(int64_t)button triggerType:(MFActionTriggerType)triggerType level:(int64_t)level {
    
    [GestureScrollSimulator breakMomentumScroll]; // Momentum scroll should be started, if when a modified drag of type "twoFingerSwipe" is deactivated. Not sure when it should be stopped. But just doing it here for now should work fine.
    
    if (triggerType == kMFActionTriggerTypeButtonUp) {
        [ModifyingActions deactivateAllInputModificationConditionedOnButton:button];
    }
    
    
    // This is the return value of the function. It determines, whether the event which caused this function call should be removed from the event stream or not. The return is only used when this function is called by `sendActionTriggersWithInputButton:trigger:`, which itself is called as a direct result of device input. So it's only used when the triggerType is `kMFActionTriggerTypeButtonDown` or `kMFActionTriggerTypeButtonUp`
    MFEventPassThroughEvaluation passThroughEval = kMFEventPassThroughRefusal;
    
    // Get remapDict and apply modifier overrides
    
    NSDictionary *remapDict = _testRemaps[@{}];
    
    NSDictionary *modifiers = [RemapUtility getCurrentModifiers];
    if ([modifiers isNotEqualTo:@{}]) {
        NSDictionary *actionsForCurrentModifiers = _testRemaps[modifiers];
        remapDict = [Utility_HelperApp dictionaryWithOverridesAppliedFrom:[actionsForCurrentModifiers copy] to:remapDict];
    }

    // Check validity of trigger
    
    // In the following, a timer 'firing' is the same as a timer 'expiring'
    
    // I'm not entirely sure what I'm doing here
    // One goal is that, if one of the three main types of actions (click, hold, and modifying) is triggered for a certain button and a certain click level, that should (help) kill the other two main types, by invalidating relevant trigger types. This should help make it possible to trigger each one of them independently without triggering the others
    // It also has the function of the firing of the _holdTimer and _clicktimer being mutually exclusive.
    // The _holdTimer firing will also implicitly reset _clickLevel by invalidating _levelTimer. After the _levelTimer has fired the _clickLevel will also be reset because it will be invalid afterwards (See the code in `sendActionTriggersForInputWithButton:type:`)

    
    BOOL triggerIsValid = NO;
    
    if (_buttonFromLastButtonDownEvent != button) { // This should only ever happen if the trigger is kMFActionTriggerTypeButtonUp
        triggerIsValid = NO;
    } else if (triggerType == kMFActionTriggerTypeButtonDown) {
        triggerIsValid = YES;
    } else if (triggerType == kMFActionTriggerTypeButtonUp) {
        
        BOOL a = _holdTimer.isValid
        || ![self holdActionExistsForButton:button clickLevel:_clickLevel remapDict:remapDict];
        BOOL b = ![ModifyingActions anyModifiedInputIsInUseForButton:button]
        || ![self modifyingActionExistsForButton:button clickLevel:_clickLevel remapDict:remapDict];
        if (a && b) {
            triggerIsValid = YES;
        }
        [_holdTimer invalidate];
    } else if (triggerType == kMFActionTriggerTypeHoldTimerExpired) {
        triggerIsValid = YES;
        [_levelTimer invalidate];
        // It's actually also implicitly invalidated in these cases:
        // 1. If the button associated with the hold timer is not currently pressed anymore. In that case the hold timer will never fire because a button up event invalidates the hold timer (see last 'else if' case)
        // 2. After a modified input associated with _buttonFromLastMouseDown comes into use. In that case the hold timer will never fire, because the input parser will be reset which will in turn reset the hold timer. (see `[ButtonInputParser reset]`)
        // 3. When a mouse down event occurs – that will restart the timer. (see `sendActionTriggersForInputWithButton:type:`)
    } else if (triggerType == kMFActionTriggerTypeLevelTimerExpired) {
        if (!_holdTimer.isValid) {
            triggerIsValid = YES;
        }
        // It's actually also implicitly invalidated in these cases:
        // 1. If _buttonFromLastMouseDown is currently pressed
        // 2. After the hold timer associated with _buttonFromLastMouseDown fired
            // These two conditions are captured by the `if (!_holdTimer.isValid)` statement above and by calling `[_levelTimer invalidate]` when the hold timer fires. (see the last else if statement)
        // 3. When a mouse down event occurs – that will restart the timer. (see `sendActionTriggersForInputWithButton:type:`)
    }
    
    // Get OneShotActionArray for click input and calculate targetTrigger, that is, the trigger on which actionArray should be executed.
    // \note It's unnecessary to calculate targetTrigger on click actions again for every call of this function. It only has to be calculated once for every "click" (as opposed to "hold") actionArray in every possible overriden remapDict including the unoverriden one. We could precalculate everything once when loading remapDict if we wanted to. This is plenty fast though so it's fine.
    
    MFActionTriggerType targetClickTriggerForOneShotActionArray = kMFActionTriggerTypeNone;
    
    if (triggerType == kMFActionTriggerTypeButtonDown ||
        triggerType == kMFActionTriggerTypeButtonUp ||
        triggerType == kMFActionTriggerTypeLevelTimerExpired) {
        
        // ^ The incoming triggers is for "click" actions.
        // -> Get the relevant "click" action and calculate on which of the three possible triggers we want to execute it.
        
        BOOL actionOfGreaterLevelExists = [self actionOfGreaterClickLevelExistsForButton:button clickLevel:level remapDict:remapDict];
        BOOL actionOfSameLevelWithHoldTriggerOrWhichIsModifyingExists
            = [self holdActionExistsForButton:button clickLevel:_clickLevel remapDict:remapDict]
            || [self modifyingActionExistsForButton:button clickLevel:_clickLevel remapDict:remapDict];
        
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
        [self reset]; // I'm not sure about the order of statements here. But it probably doesn't matter.
        [OneShotActions handleActionArray:OneShotActionArrayForClickTrigger];
    }
    if (triggerType == kMFActionTriggerTypeHoldTimerExpired) {
        NSArray *OneShotActionArrayForHoldTrigger = remapDict[@(button)][@(level)][@"hold"];
        [self reset];
        [OneShotActions handleActionArray:OneShotActionArrayForHoldTrigger];
    }
    if (triggerType == kMFActionTriggerTypeButtonDown) {
        NSArray *modifyingActionArrayForInput = remapDict[@(button)][@(level)][@"modifying"];
        struct ActivationCondition ac = {
            .type = kMFActivationConditionTypeMouseButtonPressed,
            .value = _buttonFromLastButtonDownEvent, // Could also use local `button` variable I think
            .activatingDevice = (__bridge IOHIDDeviceRef _Nonnull)(_deviceFromLastButtonDownEvent),
        };
        [ModifyingActions initializeModifiedInputsWithActionArray:modifyingActionArrayForInput
                                           withActivationCondition:ac]; // ??? We only activate modified inputs, they will deactivate themselves once the activation condition becomes false
    }
    
    return passThroughEval;
}

@end
