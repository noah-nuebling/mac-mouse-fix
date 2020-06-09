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

@interface InputReceiver_HID : NSObject

+ (void)registerInputCallback:(IOHIDDeviceRef)device;

+ (IOHIDDeviceRef)deviceWichCausedLastInput;

+ (BOOL)buttonEventInputSourceIsDeviceOfInterest;
+ (void)setButtonEventInputSourceIsDeviceOfInterest:(BOOL)B;

+ (void)receiveButtonInputForDevice:(IOHIDDeviceRef _Nonnull)device;
+ (void)receiveButtonAndAxisInputForDevice:(IOHIDDeviceRef _Nonnull)device seize:(BOOL)exclusive;

@end

NS_ASSUME_NONNULL_END
