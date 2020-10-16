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
        ButtonState
*/
NSMutableDictionary *_state;

#pragma mark - Load

+ (void)load {
    _state = [NSMutableDictionary dictionary];
}

#pragma mark - Input parsing

+ (MFEventPassThroughEvaluation)parseInputWithButton:(int64_t)button type:(MFButtonInputType)type inputDevice:(MFDevice *)device {
    
    // Init passThroughEval
    
    MFEventPassThroughEvaluation passThroughEval = kMFEventPassThroughApproval;
    
    // Get state of the incoming button
    
    NSNumber *devID = (__bridge NSNumber *)[device getID];
    
    NSValue *bsAsValue = [_state valueForKeyPath:[NSString stringWithFormat:@"%@.%@", devID, @(button)]];
    if (bsAsValue == nil) {
        ButtonState bs;
        _state[devID][@(button)] = [NSValue valueWithBytes:&bs objCType:@encode(ButtonState)];
    }
    ButtonState bs;
    [bsAsValue getValue:&bs];
    
    // Reset button state if zombified
    
    if (bs.isZombified) {
        [self resetButtonState:&bs];
    }
    
    // Mouse down
     if (type == kMFButtonInputTypeButtonDown) {
         
         // Send trigger
         
        passThroughEval = [TransformationManager handleButtonTriggerWithButton:button triggerType:kMFActionTriggerTypeButtonDown level:bs.clickLevel];
         
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
     }
    // Mouse up
     else {
         
         // Send trigger
         
         passThroughEval = [TransformationManager handleButtonTriggerWithButton:button triggerType:kMFActionTriggerTypeButtonUp level:bs.clickLevel];
         
     }
    
    // Return
    return passThroughEval;
}

#pragma mark - Timer callbacks

+ (void)holdTimerCallback:(NSTimer *)timer {
    NSNumber *devID;
    NSNumber *btn;
    NSNumber *lvl;
    timerCallbackHelper(timer.userInfo, &devID, &btn, &lvl);
    
    [self zombifyWithDevice:devID button:btn];
    [TransformationManager handleButtonTriggerWithButton:btn.integerValue triggerType:kMFActionTriggerTypeHoldTimerExpired level:lvl.integerValue];
}

+ (void)levelTimerCallback:(NSTimer *)timer {
    NSNumber *devID;
    NSNumber *btn;
    NSNumber *lvl;
    timerCallbackHelper(timer.userInfo, &devID, &btn, &lvl);
    
    [self resetStateWithDevice:devID button:btn];
    [TransformationManager handleButtonTriggerWithButton:btn.integerValue triggerType:kMFActionTriggerTypeLevelTimerExpired level:lvl.integerValue];
}
static void timerCallbackHelper(NSDictionary *info, NSNumber **devID, NSNumber **btn,NSNumber **lvl) {
    
    *devID = (NSNumber *)info[@"devID"];
    *btn = (NSNumber *)info[@"btn"];
    
    ButtonState bs;
    [((NSValue *)_state[*devID][*btn]) getValue:&bs];
    *lvl = @(bs.clickLevel);
}

#pragma mark - State control

#pragma mark Reset state

+ (void)resetButtonState:(ButtonState *)bs {
    [bs->holdTimer invalidate];
    [bs->levelTimer invalidate];
    bs->clickLevel = 0;
    bs->isZombified = NO;
}

+ (void)resetStateWithDevice:(NSNumber *)devID button:(NSNumber *)btn {
    ButtonState bs;
    [((NSValue *) _state[devID][btn]) getValue:&bs];
    
    [self resetButtonState:&bs];
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

// Zombification is kinda like a 'half reset'. Everything except click level is reset and when further input occurs, the button's state is reset before the input is parsed
// This necessary to be able to use buttons as modifiers (e.g. pressing a button to modify the function of another button)
+ (void)zombifyWithDevice:(NSNumber *)devID button:(NSNumber *)btn {
    ButtonState bs;
    [((NSValue *) _state[devID][btn]) getValue:&bs];
    
    [bs.holdTimer invalidate];
    [bs.levelTimer invalidate];
    bs.isZombified = YES;
}

#pragma mark - Interface

+ (void)handleHasHadDirectEffectWithDevice:(NSNumber *)devID button:(NSNumber *)btn {
    [self resetStateWithDevice:devID button:btn];
}

+ (void)handleHasHadEffectAsModifierWithDevice:(NSNumber *)devID button:(NSNumber *)btn {
    [self zombifyWithDevice:devID button:btn];
}

@end
