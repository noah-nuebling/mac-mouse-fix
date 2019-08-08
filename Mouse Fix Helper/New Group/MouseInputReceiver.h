#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "IOKit/hid/IOHIDManager.h"


@interface MouseInputReceiver : NSObject

+ (void)startOrStopDecide;

+ (void)Register_InputCallback_HID:(IOHIDDeviceRef)device;
@end
