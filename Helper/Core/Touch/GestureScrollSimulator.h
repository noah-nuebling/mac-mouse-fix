//
// --------------------------------------------------------------------------
// GestureScrollSimulator.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CGEvent.h>
#import "IOHIDEventTypes.h"

NS_ASSUME_NONNULL_BEGIN

@interface GestureScrollSimulator : NSObject

+ (void)postGestureScrollEventWithDeltaX:(int64_t)dx
                                  deltaY:(int64_t)dy
                                   phase:(IOHIDEventPhaseBits)phase
                      autoMomentumScroll:(BOOL)autoMomentum
                      invertedFromDevice:(BOOL)invertedFromDevice;

+ (void)postMomentumScrollDirectlyWithDeltaX:(double)dx
                                      deltaY:(double)dy
                               momentumPhase:(CGMomentumScrollPhase)momentumPhase
                          invertedFromDevice:(BOOL)invertedFromDevice;

+ (void)afterStartingMomentumScroll:(void (^ _Nullable)(void))callback;
+ (void)stopMomentumScroll;
+ (void)suspendMomentumScroll;

@end

NS_ASSUME_NONNULL_END
