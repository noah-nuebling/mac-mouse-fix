//
//  AppDelegate.h
//  Mouse Remap Helper
//
//  Created by Noah Nübling on 25.07.18.
//  Copyright © 2018 Noah Nuebling Enterprises Ltd. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <IOKit/hid/IOHIDManager.h>
#import "Mouse_Remap_Helper-Swift.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>



// registered USB Device sent input report callback function

// USB device added callback function
static void Handle_DeviceMatchingCallback(void *context, IOReturn result, void *sender, IOHIDDeviceRef device);

// USB device removed callback function
static void Handle_DeviceRemovalCallback(void *context, IOReturn result, void *sender, IOHIDDeviceRef device);

// Counts the number of devices in the device set (incudes all USB devices that match our dictionary)
static long USBDeviceCount(IOHIDManagerRef HIDManager);

// static long get_int_property(IOHIDDeviceRef device, CFStringRef key);

@end
