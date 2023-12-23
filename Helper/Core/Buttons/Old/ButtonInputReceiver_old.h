//
// --------------------------------------------------------------------------
// ButtonInputReceiver.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "IOKit/hid/IOHIDManager.h"
#import "Device.h"
#import "Constants.h"


@interface ButtonInputReceiver : NSObject

typedef enum {
    kMFEventPassThroughApproval,
    kMFEventPassThroughRefusal,
} MFEventPassThroughEvaluation;

typedef enum {
    kMFButtonInputTypeButtonDown,
    kMFButtonInputTypeButtonUp,
} MFButtonInputType;

typedef enum {
    kMFActionTriggerTypeNone = -1,
    kMFActionTriggerTypeButtonDown = 0,
    kMFActionTriggerTypeButtonUp = 1,
    kMFActionTriggerTypeHoldTimerExpired = 2,
    kMFActionTriggerTypeLevelTimerExpired = 3,
} MFActionTriggerType;

//typedef enum {
//    kMFUIActionTriggerTypeClick = 0,
//    kMFUIActionTriggerTypeHold = 1,
//    kMFUIActionTriggerTypeModifying = 2,
//} MFUIActionTriggerType;

+ (void)load_Manual;

+ (void)decide;

//+ (void)insertFakeEventWithButton:(MFMouseButtonNumber)button isMouseDown:(BOOL)isMouseDown;

+ (void)handleHIDButtonInputFromRelevantDeviceOccured:(Device *)dev button:(NSNumber *)btn;
+ (BOOL)allRelevantButtonInputsHaveBeenProcessed;

@end
