//
// --------------------------------------------------------------------------
// PointerSpeed.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import <IOKit/hid/IOHIDDevice.h>
//#import <IOKit/hid/IOHIDKeys.h>

NS_ASSUME_NONNULL_BEGIN

@interface PointerSpeedExperiments : NSObject
+ (void)setSensitivityTo:(int)sens onDevice:(IOHIDDeviceRef)dev;
+ (void)setAccelerationTo:(double)acc;
@end

NS_ASSUME_NONNULL_END
