//
// --------------------------------------------------------------------------
// InputReceiver_HID.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import <IOKit/hid/IOHIDManager.h>

NS_ASSUME_NONNULL_BEGIN

@interface Device : NSObject

@property (atomic, assign, readonly, nonnull) IOHIDDeviceRef IOHIDDevice;
@property (atomic, assign, readonly) BOOL isSeized;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
+ (Device *)deviceForIOHIDDevice:(IOHIDDeviceRef)IOHIDDevice;

- (NSNumber *)uniqueID;
- (NSString *)name;
- (NSString *)description;


- (void)receiveOnlyButtonInput;
- (void)receiveAxisInputAndDoSeizeDevice:(BOOL)exclusive;

@end

NS_ASSUME_NONNULL_END
