
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


//
//  InputParser.m
//  Mouse Remap Helper
//
//  Created by Noah Nübling on 19.11.18.
//  Copyright © 2018 Noah Nuebling Enterprises Ltd. All rights reserved.
//

#import "InputParser.h"
#import "AppDelegate.h"
#import "ConfigFileInterface.h"
#import "CGSInternal/CGSHotKeys.h"
#import "SensibleSideButtons/TouchEvents.h"

@implementation InputParser

// input parsing
static CGEventRef   _savedEvent;
static NSTimer     *_clickAndHoldTimer;

// simulating touch events
static NSArray *_nullArray;
static NSMutableDictionary *_swipeInfo;

+ (void)initialize{
    
    // setup touch event constants
    _nullArray = @[];
    _swipeInfo = [NSMutableDictionary dictionary];
    for (NSNumber* direction in @[ @(kTLInfoSwipeUp), @(kTLInfoSwipeDown), @(kTLInfoSwipeLeft), @(kTLInfoSwipeRight) ]) {
        NSDictionary* swipeInfo1 = [NSDictionary dictionaryWithObjectsAndKeys:
                                    @(kTLInfoSubtypeSwipe), kTLInfoKeyGestureSubtype,
                                    @(1), kTLInfoKeyGesturePhase,
                                    nil];
        
        NSDictionary* swipeInfo2 = [NSDictionary dictionaryWithObjectsAndKeys:
                                    @(kTLInfoSubtypeSwipe), kTLInfoKeyGestureSubtype,
                                    direction, kTLInfoKeySwipeDirection,
                                    @(4), kTLInfoKeyGesturePhase,
                                    nil];
        
        _swipeInfo[direction] = @[ swipeInfo1, swipeInfo2 ];
    }
}



+ (CGEventRef)parse:(int)mouseButton state:(int)state event:(CGEventRef)event {
    
    NSLog(@"parsing input (Input Parser)");
    
    NSString *keyPath = [NSString stringWithFormat:@"ButtonRemaps.%d", mouseButton];
    
    NSDictionary *remapsForInputButton = [ConfigFileInterface.config valueForKeyPath: keyPath];
    
    @try {
        
        if ( ([[remapsForInputButton allKeys] count] == 0) ) {
            NSLog(@"couldn't find any remaps for this button (Input Parser)");
            return event;
        }
        
    // single click remapping
        NSArray *clickAction = [remapsForInputButton valueForKey:@"click"];
        if ( ([[remapsForInputButton allKeys] count] == 1) && clickAction != nil ) {
            
            NSLog(@"SINGLE CLICK REMAPPING");
            
            if (state == 1) {
                [InputParser handleActionArray:clickAction];
                return nil;
            }
        }
        
        
    // both click *and* hold remapping, or single hold remapping
        
        if (state == 1) {
            
            if (clickAction == nil) {
                _savedEvent = CGEventCreateCopy(event);
            }
            NSArray *holdAction = [remapsForInputButton objectForKey:@"hold"];
            _clickAndHoldTimer = [NSTimer scheduledTimerWithTimeInterval:0.3
                                             target:self
                                           selector:@selector(clickAndHoldCallback:)
                                           userInfo:holdAction
                                            repeats:NO];
            
            return nil;
            
        } else if (state == 0) {
            if ([_clickAndHoldTimer isValid]) {
                [_clickAndHoldTimer invalidate];
                _clickAndHoldTimer = nil;
                
                if (clickAction == nil) {
                    CGEventPost(kCGSessionEventTap, _savedEvent);
                    CGEventPost(kCGSessionEventTap, event);
                    _savedEvent = nil;
                } else {
                    [InputParser handleActionArray:clickAction];
                }
                return nil;
            }
        } else {
            NSLog(@"ERRÖR: InputButtonState value invalid (Input Parser)");
        }
    } @catch (NSException *exception) {
        NSLog(@"ERROR: remaps broken (Input Parser)");
        [ConfigFileInterface repairConfigFile: @"remaps"];
    }
    
    return event;
}

+ (void)clickAndHoldCallback:(NSTimer *)timer {
    NSArray *holdAction = [timer userInfo];
    [self handleActionArray:holdAction];
    return;
}


+ (void)handleActionArray: (NSArray *)actionArray {
    
    NSLog(@"handling input (Input Parser)");
    
    if ([actionArray[0] isEqualToString:@"symbolicHotKey"])
    {
        NSNumber *shk = actionArray[1];
        [InputParser doSymbolicHotKeyAction:[shk intValue]];
    }
    else if ([actionArray[0] isEqualToString:@"swipeEvent"]) {
        NSLog(@"SWIPE");
        NSLog(@"%@", actionArray[1]);
        NSString *dirString = actionArray[1];
        
        if ([dirString isEqualToString:@"left"]) {
            SBFFakeSwipe(kTLInfoSwipeLeft);
        }
        else if ([dirString isEqualToString:@"right"]) {
            SBFFakeSwipe(kTLInfoSwipeRight);
        }
    }
}
                  
static void SBFFakeSwipe(TLInfoSwipeDirection dir) {
    
    NSArray *nullArray = @[];
    
    CGEventRef event1 = tl_CGEventCreateFromGesture((__bridge CFDictionaryRef)(_swipeInfo[@(dir)][0]), (__bridge CFArrayRef)nullArray);
    CGEventRef event2 = tl_CGEventCreateFromGesture((__bridge CFDictionaryRef)(_swipeInfo[@(dir)][1]), (__bridge CFArrayRef)nullArray);
    
    CGEventPost(kCGHIDEventTap, event1);
    CGEventPost(kCGHIDEventTap, event2);
    
    CFRelease(event1);
    CFRelease(event2);
}
                  
                  


CG_EXTERN CGError CGSSetSymbolicHotKeyValue(CGSSymbolicHotKey hotKey, unichar keyEquivalent, CGKeyCode virtualKeyCode, CGSModifierFlags modifiers);

+ (void)doSymbolicHotKeyAction:(CGSSymbolicHotKey)shk {
    
    unichar keyEquivalent;
    CGKeyCode virtualKeyCode;
    CGSModifierFlags modifierFlags;
    CGSGetSymbolicHotKeyValue(shk, &keyEquivalent, &virtualKeyCode, &modifierFlags);
    
    NSLog(@"vkk: %d", virtualKeyCode);
    
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
static void disableSHK(NSTimer *timer) {
    CGSSymbolicHotKey shk = [[timer userInfo] intValue];
    CGSSetSymbolicHotKeyEnabled(shk, FALSE);
}
static void doClickAndHoldAction(NSTimer *timer) {
    NSArray *holdAction = [timer userInfo];
    [InputParser handleActionArray:holdAction];
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
 selector:@selector(clickAndHoldCallback:)
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
 + (void)clickAndHoldCallback:(NSTimer *)timer {
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
