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
+ (void)deconfigureDevicesWithCompletion:(void (^)(BOOL completedBeforeDeadline))completion;

+ (BOOL)devicesAreAttached;
+ (Device * _Nullable)attachedDeviceWithIOHIDDevice:(IOHIDDeviceRef)iohidDevice;

+ (BOOL)someDeviceHasScrollWheel;
+ (BOOL)someDeviceHasPointing;
+ (BOOL)someDeviceHasUsableButtons;
+ (int)maxButtonNumberAmongDevices;

#if DEBUG
+ (void)unitTestAttachDevice:(Device *)device
             attachedDevices:(NSMutableArray<Device *> *)attachedDevices
                      notify:(void (^)(NSArray<Device *> *devices))notify
            controllerAttach:(void (^)(Device *device))controllerAttach
    NS_SWIFT_NAME(unitTestAttach(device:attachedDevices:notify:controllerAttach:));

+ (void)unitTestRemoveDevice:(Device *)device
             attachedDevices:(NSMutableArray<Device *> *)attachedDevices
                     prepare:(void (^)(Device *device, void (^completion)(void)))prepare
                      notify:(void (^)(NSArray<Device *> *devices))notify
    NS_SWIFT_NAME(unitTestRemove(device:attachedDevices:prepare:notify:));
#endif

@end

NS_ASSUME_NONNULL_END
