//
// --------------------------------------------------------------------------
// HelperUtility.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
@import AppKit;
@import CoreVideo;

NS_ASSUME_NONNULL_BEGIN

@interface HelperUtility : NSObject

/// Display under pointer
+ (CVReturn)displayUnderMousePointer:(CGDirectDisplayID *)dspID withEvent:(CGEventRef _Nullable)event;
+ (CVReturn)display:(CGDirectDisplayID *)dspID atPoint:(CGPoint)point;

/// App under pointer
+ (NSRunningApplication * _Nullable)appUnderMousePointerWithEvent:(CGEventRef _Nullable)event;

/// Open main app
+ (void)openMainApp;

/// Display data
//+ (CGEventRef)createEventWithValuesFromEvent:(CGEventRef)event;
+ (void)printEventFieldDifferencesBetween:(CGEventRef)event1 and:(CGEventRef)event2;
+ (NSString *)binaryRepresentation:(int64_t)value;

/// Get current modifier flags
CGEventFlags getModifierFlags(void);
CGEventFlags getModifierFlagsWithEvent(CGEventRef flagEvent);

/// Get current pointer location
CGPoint getPointerLocation(void);
CGPoint getPointerLocationWithEvent(CGEventRef _Nullable locEvent);
NSPoint getFlippedPointerLocation(void);
NSPoint getFlippedPointerLocationWithEvent(CGEventRef _Nullable locEvent);

@end

NS_ASSUME_NONNULL_END
