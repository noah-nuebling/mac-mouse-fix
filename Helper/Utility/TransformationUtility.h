//
// --------------------------------------------------------------------------
// RemapUtility.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

#import <CoreGraphics/CoreGraphics.h>
//#import <Foundation/Foundation.h>
#import "Constants.h"

NS_ASSUME_NONNULL_BEGIN

@interface TransformationUtility : NSObject

typedef enum {
    kMFDirectionUp,
    kMFDirectionRight,
    kMFDirectionDown,
    kMFDirectionLeft,
    kMFDirectionNone
} MFDirection;

BOOL directionChanged(MFDirection direction1, MFDirection direction2);

+ (double)roundUp:(double)numToRound toMultiple:(double)multiple;

+ (NSTimeInterval)nsTimeStamp;

+ (CFMachPortRef)createEventTapWithLocation:(CGEventTapLocation)location
                                       mask:(CGEventMask)mask
                                     option:(CGEventTapOptions)option
                                  placement:(CGEventTapPlacement)placement
                                   callback:(CGEventTapCallBack)callback;

+ (CFMachPortRef)createEventTapWithLocation:(CGEventTapLocation)location
                                       mask:(CGEventMask)mask
                                     option:(CGEventTapOptions)option
                                  placement:(CGEventTapPlacement)placement
                                   callback:(CGEventTapCallBack)callback
                                    runLoop:(CFRunLoopRef)runLoop;

+ (void)makeCursorSettable;

+ (void)hideMousePointer:(BOOL)B;
+ (void)postMouseButtonClicks:(MFMouseButtonNumber)button nOfClicks:(int64_t)nOfClicks;
+ (void)postMouseButton:(MFMouseButtonNumber)button down:(BOOL)down;
@end

NS_ASSUME_NONNULL_END
