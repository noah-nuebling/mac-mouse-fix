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
#import "RemapUtility.h"
#import "Utility_HelperApp.h"
#import "ConfigFileInterface_HelperApp.h"

@implementation ButtonInputParser


NSDictionary *_testRemaps;
NSArray *_testRemapsUI;
+ (void)load {
    _testRemaps = @{
        @{}: @{                                                     // Key: modifier dict
            @(4): @{                                                // Key: button
                @(1): @{                                            // Key: level
                    @"modifying": @[                                  // Key: click/hold/modifying, value: array of actions
                        @{
                            @"type": @"modifyingScroll",
                            @"value": @"magnification",
                        },
//                        @{
//                            @"type": @"modifyingDrag",
//                            @"value": @"threeFingerSwipe",
//                        },
                    ],
                    @"click": @[                                  // Key: click/hold, value: array of actions
                        @{
                            @"type": @"symbolicHotkey",
                            @"value": @(32),
                        },
                    ],
                    @"hold": @[                                    // Key: click/hold, value: array of actions
                        @{
                            @"type": @"symbolicHotkey",
                            @"value": @(36),
                        },
                    ],
                },
                @(2): @{                                            // Key: level
                    @"click": @[                                    // Key: click/hold, value: array of actions
                        @{
                            @"type": @"symbolicHotkey",
                            @"value": @(70),
                        },
                    ],
                },
            },
//            @(4): @{                                                // Key: button
//                @(1): @{                                            // Key: level
//                    @"click": @[                                  // Key: click/hold, value: array of actions
//                        @{
//                            @"type": @"symbolicHotkey",
//                            @"value": @(79),
//                        },
//                    ],
//                },
//            },
//            @(5): @{                                                // Key: button
//                @(1): @{                                            // Key: level
//                    @"click": @[                                  // Key: click/hold, value: array of actions
//                        @{
//                            @"type": @"symbolicHotkey",
//                            @"value": @(81),
//                        },
//                    ],
//                },
//            },
            
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
static int _previousButton;
static int _clickLevel;
+ (void)resetInputParser {
    [_levelTimer invalidate];
    [_holdTimer invalidate];
    _clickLevel = 0;
    _previousButton = 0;
}
+ (MFEventPassThroughEvaluation)sendActionTriggersForInputWithButton:(int)button type:(MFButtonInputType)type {
    
    MFEventPassThroughEvaluation passThroughEval = kMFEventPassThroughApproval;
    
     if (type == kMFButtonInputTypeButtonDown) {
         
         if (button != _previousButton) {
             [self resetInputParser];
             _previousButton = button;
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
        _levelTimer = [NSTimer scheduledTimerWithTimeInterval:0.25
                                                       target:self
                                                     selector:@selector(levelTimerCallback:)
                                                     userInfo:@(button)
                                                      repeats:NO];
     } else { // if (type == kMFButtonInputTypeButtonUp)
         
         if (button != _previousButton) {
             return kMFEventPassThroughApproval;
         }
         
         if ([_holdTimer isValid]) {
             passThroughEval = [self handleActionTriggerWithButton:button triggerType:kMFActionTriggerTypeButtonUp level:_clickLevel];
         }
        [_holdTimer invalidate];
     }
    return passThroughEval;
}
+ (void)holdTimerCallback:(NSTimer *)timer {
    [_levelTimer invalidate];
    int button = [[timer userInfo] intValue];
    [self handleActionTriggerWithButton:button triggerType:kMFActionTriggerTypeHoldTimerExpired level:_clickLevel];
}
+ (void)levelTimerCallback:(NSTimer *)timer {
    if ([_holdTimer isValid]) {
        return;
    }
    int button = [[timer userInfo] intValue];
    [self handleActionTriggerWithButton:button triggerType:kMFActionTriggerTypeLevelTimerExpired level:_clickLevel];
}

+ (MFEventPassThroughEvaluation)handleActionTriggerWithButton:(int)button triggerType:(MFActionTriggerType)triggerType level:(int)level {
    
    // This is the return value of the function. It determines, whether the event which caused this function call should be removed from the event stream or not. The return is only used when this function is called by `sendActionTriggersWithInputButton:trigger:`, which itself is called as a direct result of device input.
    MFEventPassThroughEvaluation passThroughEval = kMFEventPassThroughRefusal;
    
    // Get remapDict and apply modifier overrides
    
    NSDictionary *remapDict = _testRemaps[@{}];
    
    NSDictionary *modifiers = [RemapUtility getCurrentModifiers];
    if ([modifiers isNotEqualTo:@{}]) {
        NSDictionary *actionsForCurrentModifiers = _testRemaps[modifiers];
        remapDict = [Utility_HelperApp dictionaryWithOverridesAppliedFrom:[actionsForCurrentModifiers copy] to:remapDict];
    }
    
    // Get actionArray and calculate targetTrigger, that is, the trigger on which actionArray should be executed.
    // \note It's unnecessary to calculate targetTrigger again for every call of this function. It only has to be calculated once for every "click" (as opposed to "hold") actionArray in every possible overriden remapDict including the unoverriden one. We could precalculate everything once when loading remapDict if we wanted to. This is plenty fast though so it's fine.
    
    NSArray *actionArrayForInput;
    MFActionTriggerType targetTriggerForActionArray;
    
    if (triggerType == kMFActionTriggerTypeButtonDown ||
        triggerType == kMFActionTriggerTypeButtonUp ||
        triggerType == kMFActionTriggerTypeLevelTimerExpired) {
        
        // ^ The incoming trigger is for "click" actions.
        // -> Get the relevant "click" action and calculate on which of the three possible triggers we want to execute it.
        
        actionArrayForInput = remapDict[@(button)][@(level)][@"click"];
        
        BOOL actionOfGreaterLevelExists = NO;
        for (NSNumber *thisLevel in ((NSDictionary *)remapDict[@(button)]).allKeys) {
            if (thisLevel.intValue > level) {
                actionOfGreaterLevelExists = YES;
                break;
            }
        }
        BOOL actionOfSameLevelWithHoldTriggerExists = (remapDict[@(button)][@(level)][@"hold"] != nil);
        
        // Set target trigger
        
        if (actionOfGreaterLevelExists) {
            targetTriggerForActionArray = kMFActionTriggerTypeLevelTimerExpired;
        } else if (actionOfSameLevelWithHoldTriggerExists) {
            targetTriggerForActionArray = kMFActionTriggerTypeButtonUp;
        } else {
            targetTriggerForActionArray = kMFActionTriggerTypeButtonDown;
        }
        
        // Let the input event which caused this function call pass through, if no remaps exist for this button.
        // TODO: Think about this and make sure that the condition is true if and only if no remaps exist for this button
        
        if (actionArrayForInput == nil &&
            !actionOfGreaterLevelExists &&
            !actionOfSameLevelWithHoldTriggerExists) {
            passThroughEval = kMFEventPassThroughApproval;
        }
        
    } else if (triggerType == kMFActionTriggerTypeHoldTimerExpired) {
        // ^ The incoming trigger is for "hold" actions.
        actionArrayForInput = remapDict[@(button)][@(level)][@"hold"];
        targetTriggerForActionArray = kMFActionTriggerTypeHoldTimerExpired;
    } else { // if (trigger == kMFActionTriggerTypeModifyingAction)
        // TODO: Implement this
        targetTriggerForActionArray = -1;
    }
    
    // Execute actionArray
    
    if (targetTriggerForActionArray == triggerType) {
        // v This prevents clicks that occur right after an event fires from inceasing click level further, which leads to a worse UX.
        [self resetInputParser]; // TODO: Think this through and make sure it doesn't lead to weird behaviour.
        [OneShotActions handleActionArray:actionArrayForInput];
    }
    return passThroughEval;
}

@end
