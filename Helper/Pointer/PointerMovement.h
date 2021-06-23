//
// --------------------------------------------------------------------------
// PointerMovement.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import <IOKit/hid/IOHIDBase.h>

NS_ASSUME_NONNULL_BEGIN

@interface PointerMovement : NSObject

/// Shouldn't use this yet, as it's still buggy

//+ (void)setForAllDevices;
//+ (void)setForDevice:(IOHIDDeviceRef)device;

@end

NS_ASSUME_NONNULL_END
