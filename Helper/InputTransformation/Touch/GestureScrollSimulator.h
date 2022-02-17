//
// --------------------------------------------------------------------------
// GestureScrollSimulator.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Mac_Mouse_Fix_Helper-Swift.h>
#import <Foundation/Foundation.h>
#import "IOHIDEventTypes.h"

NS_ASSUME_NONNULL_BEGIN

@interface GestureScrollSimulator : NSObject

+ (void)postGestureScrollEventWithDeltaX:(int64_t)dx deltaY:(int64_t)dy phase:(IOHIDEventPhaseBits)phase;
+ (void)postGestureScrollEvent_Synchronously_WithDeltaX:(int64_t)dx deltaY:(int64_t)dy phase:(IOHIDEventPhaseBits)phase;

+ (void)afterStartingMomentumScroll:(void (^ _Nullable)(void))callback;
+ (void)stopMomentumScroll;
+ (PixelatedVectorAnimator *)momentumAnimator;

@end

NS_ASSUME_NONNULL_END
