//
// --------------------------------------------------------------------------
// TouchSimulator.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import "SensibleSideButtons/TouchEvents.h"
#import "SensibleSideButtons/IOHIDEventTypes.h"
#import "SensibleSideButtons/IOHIDEventData.h"

NS_ASSUME_NONNULL_BEGIN

@interface TouchSimulator : NSObject
+ (void)SBFFakeSwipe:(TLInfoSwipeDirection)dir;
+ (void)postEventWithMagnification:(double)magnification phase:(IOHIDEventPhaseBits)phase;
@end

NS_ASSUME_NONNULL_END
