//
// --------------------------------------------------------------------------
// Utility_HelperApp.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "Utility_HelperApp.h"
#import "Constants.h"

@implementation Utility_HelperApp

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
    NSLog(@"Field differences for event: %@, and event: %@", event1, event2);
    for (int field = 0; field < 256; field++) { // I think there are only 256 fields, that's what we seem to have assumed in macos-touch-reverse-engineering
        int64_t value1 = CGEventGetIntegerValueField(event1, field);
        int64_t value2 = CGEventGetIntegerValueField(event2, field);
        if (value1 != value2) {
            NSLog(@"%@: %@ vs %@", @(field), @(value1), @(value2));
        }
    }
}

+ (NSString *)binaryRepresentation:(int)value {
    long nibbleCount = sizeof(value) * 2;
    NSMutableString *bitString = [NSMutableString stringWithCapacity:nibbleCount * 5];
    
    for (long index = 4 * nibbleCount - 1; index >= 0; index--)
    {
        [bitString appendFormat:@"%i", value & (1 << index) ? 1 : 0];
        if (index % 4 == 0)
        {
            [bitString appendString:@" "];
        }
    }
    return bitString;
}

// TODO: Move this to SharedUtility
// TODO: Consider returning a mutable dict to avoid constantly using `- mutableCopy`. Maybe even alter `dst` in place and return nothing (And rename to `applyOverridesFrom:to:`).
/// Copy all leaves (elements which aren't dictionaries) from `src` to `dst`. Return the result. (`dst` itself isn't altered)
/// Recursively search for leaves in `src`. For each srcLeaf found, create / replace a leaf in `dst` at a keyPath identical to the keyPath of srcLeaf and with the value of srcLeaf.
/// Has and exact copy in Utility_App
+ (NSDictionary *)dictionaryWithOverridesAppliedFrom:(NSDictionary *)src to: (NSDictionary *)dst {
    NSMutableDictionary *dstMutable = [dst mutableCopy];
    for (NSString *key in src) {
        NSObject *dstVal = [dst valueForKey:key];
        NSObject *srcVal = [src valueForKey:key];
        if ([srcVal isKindOfClass:[NSDictionary class]] || [srcVal isKindOfClass:[NSMutableDictionary class]]) { // Not sure if checking for mutable dict and dict is necessary
            // Nested dictionary found. Recursing.
            NSDictionary *recursionResult = [self dictionaryWithOverridesAppliedFrom:(NSDictionary *)srcVal to:(NSDictionary *)dstVal];
            [dstMutable setValue:recursionResult forKey:key];
        } else {
            // Leaf found
            [dstMutable setValue:srcVal forKey:key];
        }
    }
    return dstMutable;
}

// All of the CG APIs use a flipped coordinate system
+ (CGPoint)getCurrentPointerLocation_flipped {
    
    NSPoint loc = NSEvent.mouseLocation;
    
//    NSAffineTransform* xform = [NSAffineTransform transform];
//    [xform translateXBy:0.0 yBy:NSScreen.mainScreen.frame.size.height];
//    [xform scaleXBy:1.0 yBy:-1.0];
//    [xform transformPoint:loc];
    
    return NSPointFromCGPointWithCoordinateConversion(loc);
}

// All of the CG APIs use a flipped coordinate system
+ (CGPoint)getCurrentPointerLocation_flipped_slow {
    CGEventRef locEvent = CGEventCreate(NULL);
    CGPoint loc = CGEventGetLocation(locEvent);
    CFRelease(locEvent);
    return loc;
}
NSPoint NSPointFromCGPointWithCoordinateConversion(CGPoint cgPoint) {
    return NSMakePoint(cgPoint.x, zeroScreenHeight() - cgPoint.y);
}
NSRect NSRectFromCGRectWithCoordinateConversion(CGRect cgRect) {
    return NSMakeRect(cgRect.origin.x,  zeroScreenHeight() - cgRect.origin.y -
    cgRect.size.height, cgRect.size.width, cgRect.size.height);
}

CGFloat zeroScreenHeight(void) {
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
//          I think the NSTimers became usafe__unretained automatically from what I saw in the debugger, this is not the case when using the class instead of the struct.   
//+ (void)coolInvalidate:(NSTimer * __strong *)timer {
//    if (*timer != nil) {
//        if ([*timer isValid]) {
//            [*timer invalidate];
//        }
//        *timer = nil;
//    }
//}

@end
