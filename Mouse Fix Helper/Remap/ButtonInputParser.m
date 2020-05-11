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
#import "ButtonInputReceiver.h"
#import "RemapUtility.h"
#import "Utility_HelperApp.h"
#import "AppDelegate.h"
#import "ConfigFileInterface_HelperApp.h"
#import "../SupportFiles/External/CGSInternal/CGSHotKeys.h"
#import "../SupportFiles/External/SensibleSideButtons/TouchEvents.h"
#import "TouchSimulator.h"

@implementation ButtonInputParser


NSDictionary *_testRemaps;
NSArray *_testRemapsUI;
+ (void)load {
    _testRemaps = @{
        @{}: @{                                                     // Key: modifier dict
            @(3): @{                                                // Key: button
                @(1): @{                                            // Key: level
                    @"click": @[                                    // Key: trigger, value: array of actions
                        @{
                            @"type": @"symbolicHotkey",
                            @"value": @(33),
                        },
                    ],
                },
                @(2): @{                                            // Key: level
                    @"click": @[                                    // Key: trigger, value: array of actions
                        @{
                            @"type": @"symbolicHotkey",
                            @"value": @(32),
                        },
                    ],
                },
            },
        },
        
        @{                                                          // Key: modifier dict
            @"keyboardModifierFlags": @(NSEventModifierFlagCommand | NSEventModifierFlagShift),
        }: @{
            @(3): @{                                                // Key: button
                @(1): @{                                            // Key: level
                    @"click": @[                                    // Key: trigger, value: array of actions
                        @{
                            @"type": @"symbolicHotkey",
                            @"value": @(64),
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
static int _clickLevel;
+ (void)resetInpuParser {
    [_levelTimer invalidate];
    [_holdTimer invalidate];
    _clickLevel = 0;
}
+ (void)parseInputWithButton:(int)button trigger:(int)trigger {
    
     if (trigger == kMFActionTriggerTypeButtonDown) {
         if ([_levelTimer isValid]) {
            _clickLevel += 1;
         } else {
             _clickLevel = 1;
         }
         [self doActionWithButton:button trigger:trigger level:_clickLevel];
        [_levelTimer invalidate];
        [_holdTimer invalidate];
        _holdTimer = [NSTimer scheduledTimerWithTimeInterval:0.3
                                                      target:self
                                                    selector:@selector(holdTimerCallback:)
                                                    userInfo:@(button)
                                                     repeats:NO];
        _levelTimer = [NSTimer scheduledTimerWithTimeInterval:0.25
                                                       target:self
                                                     selector:@selector(levelTimerCallback:)
                                                     userInfo:@(button)
                                                      repeats:NO];
     } else { // if (trigger == kMFActionTriggrTypeButtonUp)
         if ([_holdTimer isValid]) {
             [self doActionWithButton:button trigger:trigger level:_clickLevel];
         }
        [_holdTimer invalidate];
     }
}
+ (void)holdTimerCallback:(NSTimer *)timer {
    [_levelTimer invalidate];
    int button = [[timer userInfo] intValue];
    [self doActionWithButton:button trigger:kMFActionTriggerTypeHoldTimerExpired level:_clickLevel];
}
+ (void)levelTimerCallback:(NSTimer *)timer {
    if ([_holdTimer isValid]) {
        return;
    }
    int button = [[timer userInfo] intValue];
    [self doActionWithButton:button trigger:kMFActionTriggerTypeLevelTimerExpired level:_clickLevel];
}

+ (void)doActionWithButton:(int)button trigger:(MFActionTriggerType)trigger level:(int)level {
    
    double ts = CACurrentMediaTime();

//    NSLog(@"Current Modifiers: %@", modifiers);
    
    // Get action array for input
    // Try to get action array for currently active modifiers. If there are none, get default action array.
    
    NSDictionary *actionDict = _testRemaps[@{}];
    
    // Apply overrides according to currently active modifiers
    
    NSDictionary *modifiers = [RemapUtility getCurrentModifiers];
    if ([modifiers isNotEqualTo:@{}]) {
        NSDictionary *actionsForCurrentModifiers = _testRemaps[modifiers];
        actionDict = [Utility_HelperApp dictionaryWithOverridesAppliedFrom:[actionsForCurrentModifiers copy] to:actionDict];
    }
    
    // Get actions and calculate target trigger, that is, the trigger on which those actions should be executed.
    
    NSArray *actionArrayForInput;
    MFActionTriggerType targetTriggerForActionArray; // The trigger for which actionsForInput should fire.
    
    BOOL incomingTriggerIsForClick =
    trigger == kMFActionTriggerTypeButtonDown || trigger == kMFActionTriggerTypeButtonUp
    || trigger == kMFActionTriggerTypeLevelTimerExpired;
    
    if (incomingTriggerIsForClick) {
        
        actionArrayForInput = actionDict[@(button)][@(level)][@"click"];
        
        // Check if there are any actions for a higher level than the current one.
        // If so, set targetTrigger to `kMFActionTriggerTypeLevelTimerExpired`.
        
        BOOL actionOfGreaterLevelExists = NO;
        for (NSNumber *thisLevel in ((NSDictionary *)actionDict[@(button)]).allKeys) {
            if (thisLevel.intValue > level) {
                actionOfGreaterLevelExists = YES;
                break;
            }
        }
        if (actionOfGreaterLevelExists) {
            targetTriggerForActionArray = kMFActionTriggerTypeLevelTimerExpired;
            
        } else if ((actionDict[@(button)][@(level)][@"hold"] != nil)) {
            // ^ Checks if there are any actions at the same level, but which are triggered on hold (not on click).
            targetTriggerForActionArray = kMFActionTriggerTypeButtonUp;
            
        } else {
            targetTriggerForActionArray = kMFActionTriggerTypeButtonDown;
        }
        
    } else if (trigger == kMFActionTriggerTypeHoldTimerExpired) {
        actionArrayForInput = actionDict[@(button)][@(level)][@"hold"];
        targetTriggerForActionArray = kMFActionTriggerTypeHoldTimerExpired;
    } else { // if (trigger == kMFActionTriggerTypeModifyingAction)
        // TODO: Implement this
        targetTriggerForActionArray = -1;
    }
    
    NSLog(@"Target: %d, trigger: %d", targetTriggerForActionArray, trigger);
    
//    NSLog(@"bench: %f", CACurrentMediaTime() - ts);
    if (targetTriggerForActionArray == trigger) {
//        [self resetInpuParser]; // TODO: Think this through and make sure it doesn't lead to weird behaviour.
        for (NSDictionary *actionDict in actionArrayForInput) {
            [self handleActionDict:actionDict];
        }
    }
}




+ (void)handleActionDict:(NSDictionary *)actionDict {
    
    if ([actionDict[@"type"] isEqualToString:@"symbolicHotkey"]) {
        NSNumber *shk = actionDict[@"value"];
        [ButtonInputParser doSymbolicHotKeyAction:[shk intValue]];
    }
    else if ([actionDict[@"type"] isEqualToString:@"twoFingerSwipeEvent"]) {
        NSString *dirString = actionDict[@"value"];
        
        if ([dirString isEqualToString:@"left"]) {
            [TouchSimulator SBFFakeSwipe:kTLInfoSwipeLeft];
        } else if ([dirString isEqualToString:@"right"]) {
            [TouchSimulator SBFFakeSwipe:kTLInfoSwipeRight];
        }
    }
}

CG_EXTERN CGError CGSSetSymbolicHotKeyValue(CGSSymbolicHotKey hotKey, unichar keyEquivalent, CGKeyCode virtualKeyCode, CGSModifierFlags modifiers);

+ (void)doSymbolicHotKeyAction:(CGSSymbolicHotKey)shk {
    
    unichar keyEquivalent;
    CGKeyCode virtualKeyCode;
    CGSModifierFlags modifierFlags;
    CGSGetSymbolicHotKeyValue(shk, &keyEquivalent, &virtualKeyCode, &modifierFlags);
    
    BOOL hotKeyIsEnabled = CGSIsSymbolicHotKeyEnabled(shk);
    BOOL oldVirtualKeyCodeIsUsable = (virtualKeyCode < 400);
    
    if (hotKeyIsEnabled == FALSE) {
        CGSSetSymbolicHotKeyEnabled(shk, TRUE);
    }
    if (oldVirtualKeyCodeIsUsable == FALSE) {
        // set new parameters for shk - not accessible through actual keyboard, cause values too high
        keyEquivalent = 65535; // TODO: Why this value? Does it event matter what value this is?
        virtualKeyCode = (CGKeyCode)shk + 200;
        modifierFlags = 0;
        CGError err = CGSSetSymbolicHotKeyValue(shk, keyEquivalent, virtualKeyCode, modifierFlags);
        NSLog(@"(doSymbolicHotKeyAction) set shk params err: %d", err);
        if (err != 0) {
            // dD again or something if setting shk goes wrong
        }
    }
    
    // post keyevents corresponding to shk
    CGEventRef shortcutDown = CGEventCreateKeyboardEvent(NULL, virtualKeyCode, TRUE);
    CGEventRef shortcutUp = CGEventCreateKeyboardEvent(NULL, virtualKeyCode, FALSE);
    CGEventSetFlags(shortcutDown, (CGEventFlags)modifierFlags); // only type casting to silence warnings
    CGEventSetFlags(shortcutUp, (CGEventFlags)modifierFlags);
    CGEventPost(kCGSessionEventTap, shortcutDown); // Using `kCGSessionEventTap` instead of `kCGHIDEventTap` seems to prevent `[RemapUtility getCurrentModifiers]` from picking up the modifiers here.
    CGEventPost(kCGSessionEventTap, shortcutUp);
    CFRelease(shortcutDown);
    CFRelease(shortcutUp);
    
    //NSLog(@"sent keyEvents");
    
    // restore keyEnabled state after 20ms
    if (hotKeyIsEnabled == FALSE) {

        NSNumber *shkNS = [NSNumber numberWithInt:shk];
        [NSTimer scheduledTimerWithTimeInterval:0.05
                                         target:self
                                       selector:@selector(disableSHK:)
                                       userInfo:shkNS
                                        repeats:NO];
    }
    
}
+ (void)disableSHK:(NSTimer *)timer {
    CGSSymbolicHotKey shk = [[timer userInfo] intValue];
    CGSSetSymbolicHotKeyEnabled(shk, FALSE);
}

@end
