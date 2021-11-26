//
// --------------------------------------------------------------------------
// RemapUtility.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#import "Constants.h"

NS_ASSUME_NONNULL_BEGIN

@interface Utility_Transformation : NSObject

+ (CFMachPortRef)createEventTapWithLocation:(CGEventTapLocation)location
                                       mask:(CGEventMask)mask
                                     option:(CGEventTapOptions)option
                                  placement:(CGEventTapPlacement)placement
                                   callback:(CGEventTapCallBack)callback;

+ (void)hideMousePointer:(BOOL)B;
+ (void)postMouseButtonClicks:(MFMouseButtonNumber)button nOfClicks:(int64_t)nOfClicks;
+ (void)postMouseButton:(MFMouseButtonNumber)button down:(BOOL)down;

/// `MFEffectiveRemapsMethod`s are blocks that take `remaps` and `activeModifiers` as input and return `effectiveRemaps` based on those.
typedef NSDictionary *_Nonnull (^MFEffectiveRemapsMethod)(NSDictionary *_Nonnull, NSDictionary *_Nonnull);
+ (MFEffectiveRemapsMethod)effectiveRemapsMethod_Override;
+ (CGPoint)CGMouseLocationWithoutEvent;
+ (CGEventFlags)CGModifierFlagsWithoutEvent;
@end

NS_ASSUME_NONNULL_END
