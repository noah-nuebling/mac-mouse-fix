//
// --------------------------------------------------------------------------
// PointerSpeed2.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import <IOKit/hid/IOHIDBase.h>

NS_ASSUME_NONNULL_BEGIN

@interface PointerSpeedExperiments2 : NSObject

+ (void)setSensitivityTo:(int)sensitivity onDevice:(IOHIDDeviceRef)dev;

@end

NS_ASSUME_NONNULL_END
