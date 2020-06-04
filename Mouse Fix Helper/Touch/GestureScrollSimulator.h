//
// --------------------------------------------------------------------------
// GestureScrollSimulator.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import "IOHIDEventTypes.h"

NS_ASSUME_NONNULL_BEGIN

@interface GestureScrollSimulator : NSObject
+ (void)postGestureScrollEventWithGestureDeltaX:(int)dx deltaY:(int)dy phase:(IOHIDEventPhaseBits)phase;
@end

NS_ASSUME_NONNULL_END
