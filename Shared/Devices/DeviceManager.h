//
// --------------------------------------------------------------------------
// DeviceManager.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import "Device.h"
#import "WannabePrefixHeader.h"

NS_ASSUME_NONNULL_BEGIN

@interface DeviceManager : NSObject


+ (NSArray<Device *> *)attachedDevices MF_SWIFT_HIDDEN;
+ (id)__SWIFT_UNBRIDGED_attachedDevices;

+ (void)load_Manual;
+ (BOOL)devicesAreAttached;

+ (Device * _Nullable)attachedDeviceWithIOHIDDevice:(IOHIDDeviceRef)iohidDevice;
+ (void)deconfigureDevices;

@end

NS_ASSUME_NONNULL_END
