//
// --------------------------------------------------------------------------
// InputReceiver_HID.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import <IOKit/hid/IOHIDManager.h>

NS_ASSUME_NONNULL_BEGIN

@interface Device : NSObject

@property (atomic, assign, readonly, nullable) IOHIDDeviceRef iohidDevice;

+ (instancetype)new NS_UNAVAILABLE;

+ (Device * _Nullable)deviceWithRegistryID:(uint64_t)registryID;
+ (Device *)deviceWithIOHIDDevice:(IOHIDDeviceRef)IOHIDDevice;
+ (Device *)strangeDevice;

- (NSNumber *)uniqueID;
- (BOOL)wrapsIOHIDDevice:(IOHIDDeviceRef)iohidDevice;
- (NSString *)name;
- (NSString *)manufacturer;
- (int)nOfButtons;
- (NSString *)description;


//- (void)receiveOnlyButtonInput;
//- (void)receiveAxisInputAndDoSeizeDevice:(BOOL)exclusive;

@end

NS_ASSUME_NONNULL_END
