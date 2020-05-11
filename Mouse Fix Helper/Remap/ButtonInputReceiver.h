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
    kMFButtonInputTypeButtonUp = 1,
    kMFButtonInputTypeButtonDown = 0,
    kMFButtonInputTypeHoldTimerExpired = 3,
    kMFButtonInputTypeLevelTimerExpired = 2,
} MFButtonInputType;

+ (void)decide;

+ (void)registerInputCallback_HID:(IOHIDDeviceRef)device;

@end
