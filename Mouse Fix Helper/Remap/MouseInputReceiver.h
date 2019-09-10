//
// --------------------------------------------------------------------------
// MouseInputReceiver.h
// Created for: Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by: Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "IOKit/hid/IOHIDManager.h"


@interface MouseInputReceiver : NSObject

+ (void)startOrStopDecide;

+ (void)Register_InputCallback_HID:(IOHIDDeviceRef)device;
@end
