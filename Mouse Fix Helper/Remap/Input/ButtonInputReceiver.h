//
// --------------------------------------------------------------------------
// ButtonInputReceiver.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "IOKit/hid/IOHIDManager.h"


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
    kMFActionTriggerTypeLevelTimerExpired = 2,
    kMFActionTriggerTypeHoldTimerExpired = 3,
} MFActionTriggerType;

//typedef enum {
//    kMFUIActionTriggerTypeClick = 0,
//    kMFUIActionTriggerTypeHold = 1,
//    kMFUIActionTriggerTypeModifying = 2,
//} MFUIActionTriggerType;

+ (void)decide;

+ (void)registerInputCallback_HID:(IOHIDDeviceRef)device;

@end
