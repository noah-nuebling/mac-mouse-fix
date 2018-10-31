//
//  AppDelegate.h
//  Mouse Remap Helper
//
//  Created by Noah Nübling on 25.07.18.
//  Copyright © 2018 Noah Nuebling Enterprises Ltd. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <IOKit/hid/IOHIDManager.h>


@interface AppDelegate : NSObject <NSApplicationDelegate>

// USB device added callback function
static void Handle_DeviceMatchingCallback(void *context, IOReturn result, void *sender, IOHIDDeviceRef device);


extern NSMutableArray *pressedButtonModifierList;

@end
