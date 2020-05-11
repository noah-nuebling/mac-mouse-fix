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
#import "AppDelegate.h"
#import "ConfigFileInterface_HelperApp.h"
#import "../SupportFiles/External/CGSInternal/CGSHotKeys.h"
#import "../SupportFiles/External/SensibleSideButtons/TouchEvents.h"
#import "TouchSimulator.h"

@implementation ButtonInputParser


NSArray *_testRemapsDataStructure;
+ (void)load {
    _testRemapsDataStructure = @[
        @{
            @"button": @(3),
            @"level": @(1),
            @"type": @(kMFButtonInputTypeButtonUp),
            @"modifiers": @[],
            @"action": @{
                    @"type": @"symbolicHotkey",
                    @"value": @(32),
            },
        },
        @{
            @"button": @(3),
            @"level": @(1),
            @"type": @(kMFButtonInputTypeHoldTimerExpired),
            @"modifiers": @[],
            @"action": @{
                    @"type": @"symbolicHotkey",
                    @"value": @(33),
            },
        },
//        @{
//            @"button": @(3),
//            @"level": @(2),
//            @"type": @(kMFButtonInputTypeHoldTimerExpired),
//            @"modifiers": @[],
//            @"action": @{
//                    @"type": @"symbolicHotkey",
//                    @"value": @(33),
//            },
//        },
//        @{
//            @"button": @(3),
//            @"level": @(3),
//            @"type": @(kMFButtonInputTypeHoldTimerExpired),
//            @"modifiers": @[],
//            @"action": @{
//                    @"type": @"symbolicHotkey",
//                    @"value": @(33),
//            },
//        },
//        @{
//            @"button": @(3),
//            @"level": @(4),
//            @"type": @(kMFButtonInputTypeHoldTimerExpired),
//            @"modifiers": @[],
//            @"action": @{
//                    @"type": @"symbolicHotkey",
//                    @"value": @(33),
//            },
//        },
//        @{
//            @"button": @(3),
//            @"level": @(5),
//            @"type": @(kMFButtonInputTypeHoldTimerExpired),
//            @"modifiers": @[],
//            @"action": @{
//                    @"type": @"symbolicHotkey",
//                    @"value": @(33),
//            },
//        },
    ];
}


static NSTimer *_levelTimer;
static NSTimer *_holdTimer;
static int _clickLevel;

+ (void)parseInputWithButton:(int)button eventType:(int)type {
    
     if (type == kMFButtonInputTypeButtonDown) {
         if ([_levelTimer isValid]) {
            _clickLevel += 1;
         } else {
             _clickLevel = 1;
         }
         [self doActionWithButton:button eventType:type level:_clickLevel];
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
     } else { // if (type == kMFButtonInputTypeButtonUp)
         if ([_holdTimer isValid]) {
             [self doActionWithButton:button eventType:type level:_clickLevel];
         }
        [_holdTimer invalidate];
     }
}
+ (void)holdTimerCallback:(NSTimer *)timer {
    [_levelTimer invalidate];
    int button = [[timer userInfo] intValue];
    [self doActionWithButton:button eventType:kMFButtonInputTypeHoldTimerExpired level:_clickLevel];
}
+ (void)levelTimerCallback:(NSTimer *)timer {
    if ([_holdTimer isValid]) {
        return;
    }
    int button = [[timer userInfo] intValue];
    [self doActionWithButton:button eventType:kMFButtonInputTypeLevelTimerExpired level:_clickLevel];
}

+ (void)doActionWithButton:(int)button eventType:(MFButtonInputType)type level:(int)level {
    
    NSArray *modifiers = @[];
    
//    NSPredicate *findActionForInput = [NSPredicate predicateWithFormat:
//                                       @"button = %d AND type = %d AND level = %d AND modifiers = %d",
//                                       button, type, level, modifiers];
    
    double ts = CACurrentMediaTime();
    
    NSPredicate *findActionForInput = [NSPredicate predicateWithFormat:
                                       @"button = %d AND type = %d AND level = %d AND modifiers = %@",
                                       button, type, level, modifiers];
    
    NSArray *actionsForInput = [_testRemapsDataStructure filteredArrayUsingPredicate:findActionForInput];
    NSLog(@"Benchmark1: %f", CACurrentMediaTime() - ts);
    
    
    if (actionsForInput.count == 0) {
        return;
    }
    
    assert(actionsForInput.count == 1);
    
    [self handleActionDict:actionsForInput[0][@"action"]];
    
    NSLog(@"Benchmark2: %f", CACurrentMediaTime() - ts);
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
        keyEquivalent = 65535;
        virtualKeyCode = (CGKeyCode)shk + 200;
        modifierFlags = 0;
        CGError err = CGSSetSymbolicHotKeyValue(shk, keyEquivalent, virtualKeyCode, modifierFlags);
        NSLog(@"(doSymbolicHotKeyAction) set shk params err: %d", err);
        if (err != 0) {
            // do again or something if setting shk goes wrong
        }
    }
    
    // post keyevents corresponding to shk
    CGEventRef shortcutDown = CGEventCreateKeyboardEvent(NULL, virtualKeyCode, TRUE);
    CGEventRef shortcutUp = CGEventCreateKeyboardEvent(NULL, virtualKeyCode, FALSE);
    CGEventSetFlags(shortcutDown, (CGEventFlags)modifierFlags); // only type casting to silence warnings
    CGEventSetFlags(shortcutUp, (CGEventFlags)modifierFlags);
    CGEventPost(kCGHIDEventTap, shortcutDown);
    CGEventPost(kCGHIDEventTap, shortcutUp);
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

// NSTimer callbacks
+(void)disableSHK:(NSTimer *)timer {
    CGSSymbolicHotKey shk = [[timer userInfo] intValue];
    CGSSetSymbolicHotKeyEnabled(shk, FALSE);
}
+(void)doClickAndHoldAction:(NSTimer *)timer {
    NSArray *holdAction = [timer userInfo];
    [ButtonInputParser handleActionDict:holdAction];
}

@end

// click gesture recognizer:
/*
 NSTimer *clickAndHoldTimer;
 NSTimer *multiClickTimer;
 
 int clickLevel = 0;
 + (CGEventRef)clickGestureRecognizer:(CGEventRef)event {
 NSNumber *currentButton = [NSNumber numberWithInteger:CGEventGetIntegerValueField(event,kCGMouseEventButtonNumber)+1];
 int currentButtonInt = [currentButton intValue];
 int state = (int) CGEventGetIntegerValueField(event, kCGMouseEventPressure);
 if (state == 255) {
 state = 1;
 }
 
 if (state == 1) {
 if ([multiClickTimer isValid]) {
 clickLevel += 1;
 [multiClickTimer invalidate];
 }
 [self parseClickGestureWithButton:currentButtonInt state:1 level:clickLevel holdCallback:false clickCallback:false];
 
 clickAndHoldTimer = [NSTimer scheduledTimerWithTimeInterval:0.3
 target:self
 selector:@selector(holdTimerCallback:)
 userInfo:currentButton
 repeats:NO];
 multiClickTimer = [NSTimer scheduledTimerWithTimeInterval:0.25
 target:self
 selector:@selector(multiClickCallback:)
 userInfo:currentButton
 repeats:NO];
 } else {
 [self parseClickGestureWithButton:currentButtonInt state:0 level:clickLevel holdCallback:false clickCallback:false];
 if ([clickAndHoldTimer isValid] == true) {
 [clickAndHoldTimer invalidate];
 }
 }
 return event;
 }
 + (void)holdTimerCallback:(NSTimer *)timer {
 int button = [[timer userInfo] intValue];
 [self parseClickGestureWithButton:button state:-1 level:clickLevel holdCallback:true clickCallback:false];
 clickLevel = 0;
 [multiClickTimer invalidate];
 }
 + (void)multiClickCallback:(NSTimer *)timer {
 int button = [[timer userInfo] intValue];
 if ([clickAndHoldTimer isValid] == false) {
 [self parseClickGestureWithButton:button state:-1 level:clickLevel holdCallback:false clickCallback:true];
 clickLevel = 0;
 }
 
 }
 
 + (void)parseClickGestureWithButton:(int)button state:(int)state level:(int)level holdCallback:(Boolean)hold clickCallback:(Boolean)ccb{
 NSLog(@"button: %d, state: %d, clicklevel: %d, hold: %d, delayClick: %d", button, state, level, hold, ccb);
 }
 */
