//
// --------------------------------------------------------------------------
// InputReceiver_HID.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import <IOKit/hid/IOHIDManager.h>

NS_ASSUME_NONNULL_BEGIN

@interface Device : NSObject

@property (atomic, assign, readonly, nullable) IOHIDDeviceRef iohidDevice;
@property (nonatomic, assign) BOOL isLogitechDiverted;
@property (nonatomic, assign) BOOL supportsLogitechDPI;
@property (nonatomic, assign) int logitechBatteryPercentage;
@property (nonatomic, assign) int logitechBatteryStatus;
@property (nonatomic, assign) int logitechDPI;
@property (nonatomic, assign) BOOL supportsLogitechHiResWheel;
@property (nonatomic, assign) BOOL logitechHiResEnabled;
@property (nonatomic, assign) BOOL supportsLogitechReportRate;
@property (nonatomic, assign) uint16_t logitechReportRate; // Current rate in Hz

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
