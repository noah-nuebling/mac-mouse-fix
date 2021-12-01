//
// --------------------------------------------------------------------------
// Utility_Helper.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
@import CoreVideo;

@interface Utility_Helper : NSObject
+ (CGEventRef)createEventWithValuesFromEvent:(CGEventRef)event;
+ (void)printEventFieldDifferencesBetween:(CGEventRef)event1 and:(CGEventRef)event2;
+ (NSString *)binaryRepresentation:(int64_t)value;

/// Get current modifier flags
CGEventFlags getModifierFlags(void);
CGEventFlags getModifierFlagsWithEvent(CGEventRef flagEvent);

/// Get current pointer location
CGPoint getPointerLocation(void);
CGPoint getPointerLocationWithEvent(CGEventRef locEvent);

/// Get display under mouse pointer
+ (CVReturn)displayUnderMousePointer:(CGDirectDisplayID *)dspID withEvent:(CGEventRef)event;
+ (CVReturn)display:(CGDirectDisplayID *)dspID atPoint:(CGPoint)point;

@end

