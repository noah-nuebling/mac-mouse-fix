//
// --------------------------------------------------------------------------
// RemapUtility.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <CoreGraphics/CoreGraphics.h>
//#import <Foundation/Foundation.h>
#import "Constants.h"

NS_ASSUME_NONNULL_BEGIN

@interface TransformationUtility : NSObject

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
