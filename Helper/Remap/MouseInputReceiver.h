//
// --------------------------------------------------------------------------
// MouseInputReceiver.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

@import CoreGraphics;
#import <Cocoa/Cocoa.h>
#import "IOKit/hid/IOHIDManager.h"


@interface MouseInputReceiver : NSObject

+ (void)decide;

+ (void)Register_InputCallback_HID:(IOHIDDeviceRef)device;
@end
