//
// --------------------------------------------------------------------------
// ButtonInputParser.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "ButtonInputParser.h"
#import "Actions.h"
#import "ModifyingActions.h"
#import "RemapUtility.h"
#import "Utility_HelperApp.h"
#import "ConfigFileInterface_HelperApp.h"
#import "GestureScrollSimulator.h"
#import "TransformationManager.h"

#pragma mark - Definition of private helper class `Button State`

// Instaces of this helper class describe the state of a single button on an input device
// The `_state` class variable of `ButtonInputParser` is a collection of `ButtonState` instances
@interface ButtonState : NSObject
@property NSTimer *holdTimer;
@property NSTimer *levelTimer;
@property int64_t clickLevel;
@property BOOL isZombified;
@end
@implementation ButtonState
@synthesize holdTimer, levelTimer, clickLevel, isZombified;
@end

#pragma mark - Implementation of `ButtonInputParser`

@implementation ButtonInputParser

#pragma mark - Class vars

/*
 deviceID:
 buttonNumber:
 ButtonState instance
 */
static NSMutableDictionary *_state;

#pragma mark - Load

+ (void)load {
    _state = [NSMutableDictionary dictionary];
}

#pragma mark - Input parsing

+ (MFEventPassThroughEvaluation)parseInputWithButton:(NSNumber *)btn trigger:(MFButtonInputType)trigger inputDevice:(MFDevice *)device {
    
    // Init passThroughEval
    MFEventPassThroughEvaluation passThroughEval = kMFEventPassThroughApproval;
    
    // Get incoming device id
    NSNumber *devID = (__bridge NSNumber *)[device getID];
    
    // Get state of the incoming button
    ButtonState *bs = _state[devID][btn];
    
    // If no entry exists in _state for the current device and button, create one
    if (bs == nil) {
        bs = [ButtonState alloc];
        _state[devID] = [NSMutableDictionary dictionary];
        _state[devID][btn] = bs;
    }
    
    // Reset button state if zombified
    if (bs.isZombified) {
        [self resetStateWithDevice:devID button:btn];
    }
    
    if (trigger == kMFButtonInputTypeButtonDown) {
        
        // Mouse down
        
        // Increase click level
        bs.clickLevel += 1;
        
        // Send trigger
        passThroughEval = [TransformationManager handleButtonTriggerWithButton:btn trigger:kMFActionTriggerTypeButtonDown level:@(bs.clickLevel) device:devID];
        
        // Restart Timers
        NSDictionary *timerInfo = @{
            @"devID": devID,
            @"btn": btn
        };
        [bs.holdTimer invalidate]; // Probs unnecessary cause it gets killed by mouse up anyways
        [bs.levelTimer invalidate];
        bs.holdTimer = [NSTimer scheduledTimerWithTimeInterval:0.25
                                                        target:self
                                                      selector:@selector(holdTimerCallback:)
                                                      userInfo:timerInfo
                                                       repeats:NO];
        bs.levelTimer = [NSTimer scheduledTimerWithTimeInterval:0.25 //NSEvent.doubleClickInterval // The possible doubleClickIntervall
                         // values (configurable in System Preferences) are either too long or too short
                                                         target:self
                                                       selector:@selector(levelTimerCallback:)
                                                       userInfo:timerInfo
                                                        repeats:NO];
        
    } else {
        
        // Mouse up
        
        // Send trigger
        passThroughEval = [TransformationManager handleButtonTriggerWithButton:btn trigger:kMFActionTriggerTypeButtonUp level:@(bs.clickLevel) device:devID];
        
        // Kill hold timer (not sure if necessary)
        [bs.holdTimer invalidate];
        
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
    
    ButtonState *bs = _state[*devID][*btn];
    *lvl = @(bs.clickLevel);
}

#pragma mark - State control

#pragma mark Reset state

+ (void)resetStateWithDevice:(NSNumber *)devID button:(NSNumber *)btn {
    
    ButtonState *bs = _state[devID][btn];
    
    [bs.holdTimer invalidate];
    [bs.levelTimer invalidate];
    bs.clickLevel = 0;
    bs.isZombified = NO;
    
}
// Don't think we'll need this
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
    
    ButtonState *bs = _state[devID][btn];
    
    [bs.holdTimer invalidate];
    [bs.levelTimer invalidate];
    
    bs.isZombified = YES;
    
}

#pragma mark Interface

+ (void)handleHasHadDirectEffectWithDevice:(NSNumber *)devID button:(NSNumber *)btn {
    [self resetStateWithDevice:devID button:btn];
}

+ (void)handleHasHadEffectAsModifierWithDevice:(NSNumber *)devID button:(NSNumber *)btn {
    [self zombifyWithDevice:devID button:btn];
}

@end
