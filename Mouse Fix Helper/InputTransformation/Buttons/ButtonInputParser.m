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
        passThroughEval = [TransformationManager handleButtonTriggerWithButton:button triggerType:kMFActionTriggerTypeButtonDown level:_clickLevel];
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
         
         passThroughEval = [TransformationManager handleButtonTriggerWithButton:button triggerType:kMFActionTriggerTypeButtonUp level:_clickLevel];
         
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
    [TransformationManager handleButtonTriggerWithButton:_buttonFromLastButtonDownEvent triggerType:kMFActionTriggerTypeHoldTimerExpired level:_clickLevel];
}
+ (void)levelTimerCallback:(NSTimer *)timer {
//    int button = [[timer userInfo] intValue];
    [TransformationManager handleButtonTriggerWithButton:_buttonFromLastButtonDownEvent triggerType:kMFActionTriggerTypeLevelTimerExpired level:_clickLevel];
}

@end
