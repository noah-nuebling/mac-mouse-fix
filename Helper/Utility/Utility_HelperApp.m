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

@end
