//
// --------------------------------------------------------------------------
// Utility_Helper.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <AppKit/AppKit.h>
#import "Utility_Helper.h"
#import "Constants.h"
#import "Utility_Transformation.h"
#import "WannabePrefixHeader.h"

@implementation Utility_Helper

/// Don't use this. This doesn't produce identical results.
/// This is a more general / functional version of the function at `ScrollUtility -> createPixelBasedScrollEventWithValuesFromEvent:event`. See it's doc for more info. (That function failed to produce identical events, but this does too, unfortunately)
/// This doesn't produce identical event either unfortunately
/// Setting the fields in a different order changes the results, so from that (and based on experience from macos-touch-reverse-engineering) I think that setting certain fields changes the value of others...
+ (CGEventRef)createEventWithValuesFromEvent:(CGEventRef)event {
    CGEventRef newEvent = CGEventCreate(NULL);
    for (int field = 255; field >= 0; field--) { // I think there are only 256 fields, that's what we seem to have assumed in macos-touch-reverse-engineering
        int64_t value = CGEventGetIntegerValueField(event, field);
        CGEventSetIntegerValueField(newEvent, field, value);
    }
    
//    [self printEventFieldDifferencesBetween:event and:newEvent];
    
    return newEvent;
}
+ (void)printEventFieldDifferencesBetween:(CGEventRef)event1 and:(CGEventRef)event2 {
    DDLogInfo(@"Field differences for event: %@, and event: %@", event1, event2);
    for (int field = 0; field < 256; field++) { // I think there are only 256 fields, that's what we seem to have assumed in macos-touch-reverse-engineering
        int64_t value1 = CGEventGetIntegerValueField(event1, field);
        int64_t value2 = CGEventGetIntegerValueField(event2, field);
        if (value1 != value2) {
            DDLogInfo(@"%@: %@ vs %@", @(field), @(value1), @(value2));
        }
    }
}

+ (NSString *)binaryRepresentation:(int64_t)value {
    
    uint64_t one = 1; /// A literal 1 is apparently 32 bits, so we need to declare it here to make it 64 bits. Declaring as unsigned only to silence an error when shiftting this left by 63 places.
    
    int64_t nibbleCount = sizeof(value) * 2;
    NSMutableString *bitString = [NSMutableString stringWithCapacity:nibbleCount * 5];
    
    for (int64_t index = 4 * nibbleCount - 1; index >= 0; index--)
    {
        [bitString appendFormat:@"%i", value & (one << index) ? 1 : 0];
        if (index % 4 == 0)
        {
            [bitString appendString:@" "];
        }
    }
    return bitString;
}

/// Get modifier flags

+ (CGEventFlags)modifierFlags {
    CGEventRef flagEvent = CGEventCreate(NULL);
    CGEventFlags flags = CGEventGetFlags(flagEvent);
    CFRelease(flagEvent);
    return flags;
}

+ (CGEventFlags)modifierFlagsWithEvent:(CGEventRef)flagEvent {
    CGEventFlags flags = CGEventGetFlags(flagEvent);
    return flags;
}

/// Get pointer location

+ (CGPoint)pointerLocation {
    CGEventRef locEvent = CGEventCreate(NULL);
    CGPoint mouseLoc = CGEventGetLocation(locEvent);
    CFRelease(locEvent);
    return mouseLoc;
}

+ (CGPoint)pointerLocationWithEvent:(CGEventRef)locEvent {
    CGPoint mouseLoc = CGEventGetLocation(locEvent);
    return mouseLoc;
}

/**
 I just did some performance testing on 3 functions to get pointer locations functions found in this file:
 For a thousand runs I got these times:
 
 - pointerLocation: 0.000117s
 - pointerLocationWithEvent: 0.000015s
 - pointerLocationNS: 0.001375s
 
 -> All of them are plenty fast. It shouldn't matter at all which I use from a performance standpoint.
    I think I got it in my head to use these `withEvent` functions because I had some troubles where I used an `eventLess` way to get modifier flags while implementing the remapping engine and that `eventLess` function caused some mean bug because it didn't provide completely up-to-date values. So it's valuable to have both `withEvent` and `eventLess` around. But I shouldn't think about performance when deciding what to use here
 -> NSEvent.mouseLocation is actually the slowest of the bunch, so there's no reason for us to use it at all.
 
 -> I should delete all the pointer-location-gettings functions below
 
 */

+ (NSPoint)pointerLocationNS {
    /// All of the CG APIs use a flipped coordinate system. This is not interchangeable with pointerLocationNS
    
    return NSEvent.mouseLocation;
}

+ (CGPoint)pointerLocationFlippedNS {
    /// Don't use this
    /// I think this might be faster or more up-to-date than using CGEventCreate(NULL) to get the flipped location, but I'm not sure
    /// However, I'm quite certain that this implementation can't work properly because we use zeroScreenHeight, which is the height of the main display not the height of the display under the mouse pointer. Even if it was, out coordinate conversion code wouldn't work I think.
    
    NSPoint loc = NSEvent.mouseLocation;
    
//    NSAffineTransform* xform = [NSAffineTransform transform];
//    [xform translateXBy:0.0 yBy:NSScreen.mainScreen.frame.size.height];
//    [xform scaleXBy:1.0 yBy:-1.0];
//    [xform transformPoint:loc];
    
    return NSPointFromCGPointWithCoordinateConversion(loc);
}

/// Helper functions for getting mouse location

NSPoint NSPointFromCGPointWithCoordinateConversion(CGPoint cgPoint) {
    return NSMakePoint(cgPoint.x, zeroScreenHeight() - cgPoint.y);
}
NSRect NSRectFromCGRectWithCoordinateConversion(CGRect cgRect) {
    return NSMakeRect(cgRect.origin.x,  zeroScreenHeight() - cgRect.origin.y -
    cgRect.size.height, cgRect.size.width, cgRect.size.height);
}
CGFloat zeroScreenHeight(void) {
    /// I don't think using this will work for converting CG coordinates to NSCoordinates in a multi screen environment.
    
   CGFloat result = 0;
   NSArray *screens = [NSScreen screens];
   if ([screens count] > 0) result = NSHeight([[screens objectAtIndex:
0] frame]);
   return result;
}


// -> Might wanna use this in some situations instead of [timer invalidate]
// After calling invalidate on a timer it is automatically released but the pointer to the timer is not set to nil
// That can lead to crashes when the timer is deallocated and we're trying to dereference the pointer as far as I understand
// So this function sets the pointer to nil after invalidating the timer to prevent these crashes
//
// I wrote this cause I thought it might fix crashes in ButtonInputParser where I stored NSTimers in a struct. But it didn't help.
// Instead I replaced the struct with a private class which fixed the issue. Idk what exactly caused the crashes but apparently it's a bad idea to store NSObject pointers in C structs
//      cause it messes with ARC or something.
//          I think the NSTimers became unsafe__unretained automatically from what I saw in the debugger, this is not the case when using the class instead of the struct.
//+ (void)coolInvalidate:(NSTimer * __strong *)timer {
//    if (*timer != nil) {
//        if ([*timer isValid]) {
//            [*timer invalidate];
//        }
//        *timer = nil;
//    }
//}

@end
