//
// --------------------------------------------------------------------------
// DeviceManager.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import "Device.h"
#import "Constants.h"
#import "DisableSwiftBridging.h"

NS_ASSUME_NONNULL_BEGIN

@interface DeviceManager : NSObject


+ (MF_SWIFT_UNBRIDGED(NSArray<Device *> *))attachedDevices NS_REFINED_FOR_SWIFT;

+ (void)load_Manual;
+ (void)deconfigureDevices;

+ (BOOL)devicesAreAttached;
+ (Device * _Nullable)attachedDeviceWithIOHIDDevice:(IOHIDDeviceRef)iohidDevice;

+ (BOOL)someDeviceHasScrollWheel;
+ (BOOL)someDeviceHasPointing;
+ (BOOL)someDeviceHasUsableButtons;
+ (int)maxButtonNumberAmongDevices;


@end

NS_ASSUME_NONNULL_END
