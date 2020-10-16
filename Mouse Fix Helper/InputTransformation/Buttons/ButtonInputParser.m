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
#import "Actions.h"
#import "ModifyingActions.h"
#import "RemapUtility.h"
#import "Utility_HelperApp.h"
#import "ConfigFileInterface_HelperApp.h"
#import "GestureScrollSimulator.h"
#import "TransformationManager.h"

@implementation ButtonInputParser

#pragma mark - State

typedef struct __ButtonState {
    NSTimer *holdTimer;
    NSTimer *levelTimer;
    int64_t clickLevel;
    BOOL isZombified;
} ButtonState;

/*
deviceID:
    buttonNumber:
        struct __ButtonState
*/
static NSMutableDictionary *_state;

#pragma mark - Load

+ (void)load {
    _state = [NSMutableDictionary dictionary];
}

#pragma mark - Input parsing

+ (MFEventPassThroughEvaluation)parseInputWithButton:(int64_t)button trigger:(MFButtonInputType)trigger inputDevice:(MFDevice *)device {
    
    // Init passThroughEval
    
    MFEventPassThroughEvaluation passThroughEval = kMFEventPassThroughApproval;
    
    // Get state of the incoming button
    
    NSNumber *devID = (__bridge NSNumber *)[device getID];
    
    NSValue *bsAsValue = _state[devID][@(button)];
    ButtonState bs;
    if (bsAsValue != nil) {
        [bsAsValue getValue:&bs];
    } else { // If no entry exists in _state for the current device and button, create one
        // Create new struct and initialize all fields to 0
        bs = (ButtonState) {0};
        // Create a new entry in _state for bs
        _state[devID] = [NSMutableDictionary dictionary];
        writeBsToState(&bs, devID, @(button));
    }
    
    // Reset button state if zombified
    
    if (bs.isZombified) {
        [self resetStateWithDevice:devID button:@(button)];
    }
    
     if (trigger == kMFButtonInputTypeButtonDown) {
         
         // Mouse down
         
         // Increase click level
         
         bs.clickLevel += 1;
         writeBsToState(&bs, devID, @(button));
         
         // Send trigger
         
         passThroughEval = [TransformationManager handleButtonTriggerWithButton:@(button) trigger:kMFActionTriggerTypeButtonDown level:@(bs.clickLevel) device:devID];
         
         // Restart timers
         
        [bs.levelTimer invalidate];
        [bs.holdTimer invalidate];
         
         NSDictionary *info = @{
             @"devID": devID,
             @"btn": @(button)
         };
        bs.holdTimer = [NSTimer scheduledTimerWithTimeInterval:0.25
                                                        target:self
                                                      selector:@selector(holdTimerCallback:)
                                                      userInfo:info
                                                     repeats:NO];
         bs.levelTimer = [NSTimer scheduledTimerWithTimeInterval:0.25 // NSEvent.doubleClickInterval
                                                       target:self
                                                     selector:@selector(levelTimerCallback:)
                                                     userInfo:info
                                                      repeats:NO];
         
     } else {
         
         // Mouse up
         
         // Send trigger
         
         passThroughEval = [TransformationManager handleButtonTriggerWithButton:@(button) trigger:kMFActionTriggerTypeButtonUp level:@(bs.clickLevel) device:@(devID.integerValue)];
         
     }
    
    // Return pass through evaluation
    
    return passThroughEval;
}

#pragma mark - Timer callbacks

+ (void)holdTimerCallback:(NSTimer *)timer {
    NSNumber *devID;
    NSNumber *btn;
    NSNumber *lvl;
    timerCallbackHelper(timer.userInfo, &devID, &btn, &lvl);
    
    [self zombifyWithDevice:devID button:btn];
    [TransformationManager handleButtonTriggerWithButton:btn trigger:kMFActionTriggerTypeHoldTimerExpired level:lvl device:devID];
}

+ (void)levelTimerCallback:(NSTimer *)timer {
    NSNumber *devID;
    NSNumber *btn;
    NSNumber *lvl;
    timerCallbackHelper(timer.userInfo, &devID, &btn, &lvl);
    
    [self resetStateWithDevice:devID button:btn];
    [TransformationManager handleButtonTriggerWithButton:btn trigger:kMFActionTriggerTypeLevelTimerExpired level:lvl device:devID];
}
static void timerCallbackHelper(NSDictionary *info, NSNumber **devID, NSNumber **btn,NSNumber **lvl) {
    
    *devID = (NSNumber *)info[@"devID"];
    *btn = (NSNumber *)info[@"btn"];
    
    ButtonState bs = getBsFromState(*devID, *btn);
    *lvl = @(bs.clickLevel);
}

#pragma mark - State control

static ButtonState getBsFromState(NSNumber *devID, NSNumber *btn) {
    ButtonState bs;
    [((NSValue *) _state[devID][btn]) getValue:&bs];
    return bs;
}

// The NSValue objects encapsulating the ButtonState structs which _state holds are immutable.
// Use this after modifying a ButtonState object to apply the changes to _state.
static void writeBsToState(const ButtonState *modifiedBs, NSNumber *devID, NSNumber *button) {
    _state[devID][button] = [NSValue valueWithBytes:modifiedBs objCType:@encode(ButtonState)];
}

#pragma mark Reset state

+ (void)resetStateWithDevice:(NSNumber *)devID button:(NSNumber *)btn {
    
    ButtonState bs = getBsFromState(devID, btn);
    
    [bs.holdTimer invalidate];
    [bs.levelTimer invalidate];
    bs.clickLevel = 0;
    bs.isZombified = NO;
    
    writeBsToState(&bs, devID, btn);
}

+ (void)resetAllState {
    for (NSNumber *devKey in _state) {
        NSDictionary *dev = _state[devKey];
        for (NSNumber *btnKey in dev) {
            [self resetStateWithDevice:devKey button:btnKey];
        }
    }
}

#pragma mark Zombify

// Zombification is kinda like a 'half reset'. Everything except click level is reset and when further input occurs, the button's state will reset before the input is parsed
// This necessary to be able to use buttons as modifiers (e.g. pressing a button to modify the function of another button)
+ (void)zombifyWithDevice:(NSNumber *)devID button:(NSNumber *)btn {
    
    ButtonState bs = getBsFromState(devID, btn);
    
    [bs.holdTimer invalidate];
    [bs.levelTimer invalidate];
    bs.isZombified = YES;
    
    writeBsToState(&bs, devID, btn);
    
}

#pragma mark Interface

+ (void)handleHasHadDirectEffectWithDevice:(NSNumber *)devID button:(NSNumber *)btn {
    [self resetStateWithDevice:devID button:btn];
}

+ (void)handleHasHadEffectAsModifierWithDevice:(NSNumber *)devID button:(NSNumber *)btn {
    [self zombifyWithDevice:devID button:btn];
}


@end
