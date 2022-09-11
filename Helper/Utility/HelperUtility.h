//
// --------------------------------------------------------------------------
// HelperUtility.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
@import CoreVideo;

@interface HelperUtility : NSObject

+ (void)openMainApp;
//+ (CGEventRef)createEventWithValuesFromEvent:(CGEventRef)event;
+ (void)printEventFieldDifferencesBetween:(CGEventRef)event1 and:(CGEventRef)event2;
+ (NSString *)binaryRepresentation:(int64_t)value;

/// Get current modifier flags
CGEventFlags getModifierFlags(void);
CGEventFlags getModifierFlagsWithEvent(CGEventRef flagEvent);

/// Get current pointer location
CGPoint getPointerLocation(void);
CGPoint getPointerLocationWithEvent(CGEventRef locEvent);
NSPoint getFlippedPointerLocation(void);
NSPoint getFlippedPointerLocationWithEvent(CGEventRef locEvent);

@end

