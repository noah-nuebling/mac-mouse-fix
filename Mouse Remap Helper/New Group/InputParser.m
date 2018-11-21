
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
#import "CGSInternal/CGSHotKeys.h"
#import "SensibleSideButtons/TouchEvents.h"

@implementation InputParser

static NSDictionary *configFromFile;


+ (void) parse: (int)mouseButton state: (int)state {
    
    AppDelegate *appDelegate = [NSApp delegate];
    
    NSString *keyPath = [NSString stringWithFormat:@"ButtonRemaps.%d", mouseButton];
    
    NSDictionary *remapsForInputButton = [[appDelegate configDictFromFile] valueForKeyPath: keyPath];
    if (remapsForInputButton == nil) {
        NSLog(@"couldn't find remaps for this button in config file");
        return;
    }
    
    
    @try {
        
    // single remapping
        if ([[remapsForInputButton allKeys] count] == 1)
        {
            NSArray *clickAction = [remapsForInputButton valueForKey:@"click"];
            NSString *eventType = clickAction[0];
            BOOL isSpaceSwitchEvent = FALSE;
            if ([eventType isEqualToString:@"symbolicHotKey"]) {
                if ( ([clickAction[1] intValue] == 79) || ([clickAction[1] intValue] == 81) ) {
                    isSpaceSwitchEvent = TRUE;
                }
            }

            // trigger swipe events on release, not sure if I'm crazy, but I think it feels better
            if ((state == 1 && isSpaceSwitchEvent) ||
                (state == 0 && !isSpaceSwitchEvent))
                {
                [InputParser handleActionArray:clickAction];
                if (clickAction == nil) {
                    [appDelegate repairConfigFile:@"remaps"];

                }
            }
        }
        
    // double remapping
        else if ([[remapsForInputButton allKeys] count] == 2)
        {
            if (state == 1) {
                NSArray *holdAction = [remapsForInputButton objectForKey:@"hold"];
                NSTimer *clickAndHoldTimer = [NSTimer scheduledTimerWithTimeInterval:0.3
                                                 target:appDelegate
                                               selector:@selector(doClickAndHoldAction:)
                                               userInfo:holdAction
                                                repeats:NO];
                [appDelegate setClickAndHoldTimer:clickAndHoldTimer];
                
            } else if (state == 0) {
                NSTimer *clickAndHoldTimer = [appDelegate clickAndHoldTimer];
                if ([clickAndHoldTimer isValid]) {
                    NSArray *clickAction = [remapsForInputButton objectForKey:@"click"];
                    [InputParser handleActionArray:clickAction];
                    [[appDelegate clickAndHoldTimer] invalidate];
                    [appDelegate setClickAndHoldTimer: nil];
                }
            } else
            {
                NSLog(@"ERRÖR: InputButtonState value invalid");
                return;
            }
        }
        
        
    }
    @catch (NSException *exception) {
        NSLog(@"ERROR: remaps broken");
        [appDelegate repairConfigFile: @"remaps"];
    }
}


+ (void)handleActionArray: (NSArray *)actionArray {
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
    
    AppDelegate *appDelegate = [NSApp delegate];
    NSArray *nullArray = [appDelegate nullArray];
    NSMutableDictionary * swipeInfo = [appDelegate swipeInfo];
    
    
    CGEventRef event1 = tl_CGEventCreateFromGesture((__bridge CFDictionaryRef)(swipeInfo[@(dir)][0]), (__bridge CFArrayRef)nullArray);
    CGEventRef event2 = tl_CGEventCreateFromGesture((__bridge CFDictionaryRef)(swipeInfo[@(dir)][1]), (__bridge CFArrayRef)nullArray);
    
    CGEventPost(kCGHIDEventTap, event1);
    CGEventPost(kCGHIDEventTap, event2);
    
    CFRelease(event1);
    CFRelease(event2);
}
                  
                  


CG_EXTERN CGError CGSSetSymbolicHotKeyValue(CGSSymbolicHotKey hotKey, unichar keyEquivalent, CGKeyCode virtualKeyCode, CGSModifierFlags modifiers);

+ (void) doSymbolicHotKeyAction: (CGSSymbolicHotKey)shk {
    
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
        AppDelegate *appDelegate = [NSApp delegate];
        NSNumber *shkNS = [NSNumber numberWithInt:shk];
        [NSTimer scheduledTimerWithTimeInterval:0.05
                                         target:appDelegate
                                       selector:@selector(disableSHK:)
                                       userInfo:shkNS
                                        repeats:NO];
    }
    
}

@end
