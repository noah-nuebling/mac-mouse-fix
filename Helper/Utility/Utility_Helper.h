//
// --------------------------------------------------------------------------
// Utility_Helper.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>

@interface Utility_Helper : NSObject
+ (CGEventRef)createEventWithValuesFromEvent:(CGEventRef)event;
+ (void)printEventFieldDifferencesBetween:(CGEventRef)event1 and:(CGEventRef)event2;
+ (NSString *)binaryRepresentation:(int64_t)value;
+ (CGPoint)getCurrentPointerLocation_flipped;
@end

