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
            @(4): @{                                                // Key: button
                @(1): @{                                            // Key: level
//                    @"click": @[                                    // Key: trigger, value: array of actions
//                        @{
//                            @"type": @"symbolicHotkey",
//                            @"value": @(33),
//                        },
//                    ],
                    @"hold": @[                                    // Key: trigger, value: array of actions
                        @{
                            @"type": @"symbolicHotkey",
                            @"value": @(32),
                        },
                    ],
                },
                @(2): @{                                            // Key: level
                    @"click": @[                                    // Key: trigger, value: array of actions
                        @{
                            @"type": @"symbolicHotkey",
                            @"value": @(64),
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
+ (void)resetInputParser {
    [_levelTimer invalidate];
    [_holdTimer invalidate];
    _clickLevel = 0;
}
+ (MFEventPassThroughEvaluation)parseInputWithButton:(int)button trigger:(int)trigger {
    
    MFEventPassThroughEvaluation passThroughEval = kMFEventPassThroughApproval;
    
     if (trigger == kMFActionTriggerTypeButtonDown) {
         if ([_levelTimer isValid]) {
            _clickLevel += 1;
         } else {
             _clickLevel = 1;
         }
        passThroughEval = [self doActionWithButton:button trigger:trigger level:_clickLevel];
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
             passThroughEval = [self doActionWithButton:button trigger:trigger level:_clickLevel];
         }
        [_holdTimer invalidate];
     }
    return passThroughEval;
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

+ (void)extracted:(NSArray **)actionArrayForInput actionDict:(NSDictionary *)actionDict button:(int)button level:(int)level passThroughEval:(MFEventPassThroughEvaluation *)passThroughEval targetTriggerForActionArray:(MFActionTriggerType *)targetTriggerForActionArray trigger:(MFActionTriggerType)trigger {
    
}

+ (MFEventPassThroughEvaluation)doActionWithButton:(int)button trigger:(MFActionTriggerType)trigger level:(int)level {
    
//    double ts = CACurrentMediaTime();
    
    // This is the return value of the function. It determines, whether the event which caused this function call should be removed from the event stream or not. The return is only used when this function is called by `parseInputWithButton:trigger:`, which itself is called as a direct result of device input.
    MFEventPassThroughEvaluation passThroughEval = kMFEventPassThroughRefusal;
    
    // Get action array for input
    
    NSDictionary *actionDict = _testRemaps[@{}];
    
    // Apply modifier overrides
    
    NSDictionary *modifiers = [RemapUtility getCurrentModifiers];
    if ([modifiers isNotEqualTo:@{}]) {
        NSDictionary *actionsForCurrentModifiers = _testRemaps[modifiers];
        actionDict = [Utility_HelperApp dictionaryWithOverridesAppliedFrom:[actionsForCurrentModifiers copy] to:actionDict];
    }
    
    NSLog(@"Modifiers: %@", modifiers);
    
    // Get actionArray and calculate target trigger, that is, the trigger on which actionArray should be executed.
    
    NSArray *actionArrayForInput;
    MFActionTriggerType targetTriggerForActionArray;
    
    if (trigger == kMFActionTriggerTypeButtonDown ||
        trigger == kMFActionTriggerTypeButtonUp ||
        trigger == kMFActionTriggerTypeLevelTimerExpired) {
        
        // ^ The incoming trigger is one on which "click" actions can be fired on.
        // -> Get the relevant click action and calculate on which of the three possible triggers we want to execute it.
        
        actionArrayForInput = actionDict[@(button)][@(level)][@"click"];
        
        BOOL actionOfGreaterLevelExists = NO;
        for (NSNumber *thisLevel in ((NSDictionary *)actionDict[@(button)]).allKeys) {
            if (thisLevel.intValue > level) {
                actionOfGreaterLevelExists = YES;
                break;
            }
        }
        BOOL actionOfSameLevelWithHoldTriggerExists = (actionDict[@(button)][@(level)][@"hold"] != nil);
        
        // Set target trigger
        
        if (actionOfGreaterLevelExists) {
            targetTriggerForActionArray = kMFActionTriggerTypeLevelTimerExpired;
            
        }
        else if (actionOfSameLevelWithHoldTriggerExists) {
            targetTriggerForActionArray = kMFActionTriggerTypeButtonUp;
        } else {
            targetTriggerForActionArray = kMFActionTriggerTypeButtonDown;
        }
        
        // Set pass through evaluation
        
        if (actionArrayForInput == nil &&
            !actionOfGreaterLevelExists &&
            !actionOfSameLevelWithHoldTriggerExists) {
            passThroughEval = kMFEventPassThroughApproval;
        }
        
    } else if (trigger == kMFActionTriggerTypeHoldTimerExpired) {
        // The incoming trigger is for "hold" actions.
        // Get the relevant "hold" action and set targetTriggerForActionArray.
        
        actionArrayForInput = actionDict[@(button)][@(level)][@"hold"];
        targetTriggerForActionArray = kMFActionTriggerTypeHoldTimerExpired;
    } else { // if (trigger == kMFActionTriggerTypeModifyingAction)
        // TODO: Implement this
        targetTriggerForActionArray = -1;
    }
    
    NSLog(@"Target: %d, trigger: %d", targetTriggerForActionArray, trigger);
    
//    NSLog(@"bench: %f", CACurrentMediaTime() - ts);
    if (targetTriggerForActionArray == trigger) {
        [self resetInputParser]; // TODO: Think this through and make sure it doesn't lead to weird behaviour.
        for (NSDictionary *actionDict in actionArrayForInput) {
            [self handleActionDict:actionDict];
        }
    }
    return passThroughEval;
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
    
    CGEventFlags originalModifierFlags = CGEventGetFlags(CGEventCreate(NULL));
    
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
        modifierFlags = 10485760; // 0 Didn't work in my testing. This seems to be the 'empty' CGSModifierFlags value, used to signal that no modifiers are pressed.
        CGError err = CGSSetSymbolicHotKeyValue(shk, keyEquivalent, virtualKeyCode, modifierFlags);
        NSLog(@"(doSymbolicHotKeyAction) set shk params err: %d", err);
        if (err != 0) {
            // Do again or something if setting shk goes wrong
        }
    }
//    } else if (modifierFlags != 0) {
//        // Sending fake events with modifier flags messed up `[RemapUtility getCurrentModifiers]`, so we tried disabling modifier flags (and reenabling them later). Unfortunately, a value of 0 didn't work, and the value 10485760, which (weirdly) seems to be the actual empty CGSModifierFlags value, still messes up `getCurrentModifiers`.
//        CGSSetSymbolicHotKeyValue(shk, keyEquivalent, virtualKeyCode, 10485760);
//    }
    
    // post keyevents corresponding to shk
    CGEventRef shortcutDown = CGEventCreateKeyboardEvent(NULL, virtualKeyCode, TRUE);
    CGEventRef shortcutUp = CGEventCreateKeyboardEvent(NULL, virtualKeyCode, FALSE);
    CGEventSetFlags(shortcutDown, (CGEventFlags)modifierFlags);
    CGEventSetFlags(shortcutUp, originalModifierFlags); // Restore original keyboard modifier flags state. This seems to fix `[RemapUtility getCurrentModifiers]`
    CGEventPost(kCGHIDEventTap, shortcutDown);
    CGEventPost(kCGHIDEventTap, shortcutUp);
    NSLog(@"%lu", (unsigned long)[NSEvent modifierFlags]);
    CFRelease(shortcutDown);
    CFRelease(shortcutUp);
    
//     Restore original hotkey parameters state after 20ms
    if (hotKeyIsEnabled == FALSE) { // Only really need to restore hotKeyIsEnabled. But the other stuff doesn't hurt.
        [NSTimer scheduledTimerWithTimeInterval:0.05
                                         target:self
                                       selector:@selector(restoreSHK:)
                                       userInfo:@{
                                           @"shk": @(shk),
                                           @"enabled": @(hotKeyIsEnabled),
                                           @"keyEquivalent": @(keyEquivalent),
                                           @"virtualKeyCode": @(virtualKeyCode),
                                           @"flags": @(modifierFlags),
                                       }
                                        repeats:NO];
    }
    
    NSLog(@"%lu", (unsigned long)[NSEvent modifierFlags]);
    
}
+ (void)restoreSHK:(NSTimer *)timer { // TODO: Test if this works
    
    CGSSymbolicHotKey shk = [timer.userInfo[@"shk"] intValue];
    BOOL enabled = [timer.userInfo[@"enabled"] boolValue];
    unichar kEq = [timer.userInfo[@"keyEquivalent"] unsignedCharValue];
    CGKeyCode kCode = [timer.userInfo[@"virtualKeyCode"] unsignedIntValue];
    CGSModifierFlags mod = [timer.userInfo[@"flags"] intValue];
    
    CGSSetSymbolicHotKeyEnabled(shk, enabled);
    CGSSetSymbolicHotKeyValue(shk, kEq, kCode, mod);
}

@end
