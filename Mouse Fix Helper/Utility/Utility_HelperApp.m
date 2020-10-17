//
// --------------------------------------------------------------------------
// Utility_HelperApp.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "Utility_HelperApp.h"
#import <AppKit/AppKit.h>

@implementation Utility_HelperApp

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

+ (NSBundle *)helperBundle {
    return [NSBundle bundleForClass:Utility_HelperApp.class];
}
+ (NSBundle *)prefPaneBundle {
    
    NSURL *prefPaneBundleURL = [self helperBundle].bundleURL;
    for (int i = 0; i < 4; i++) {
        prefPaneBundleURL = [prefPaneBundleURL URLByDeletingLastPathComponent];
    }
    NSBundle *prefPaneBundle = [NSBundle bundleWithURL:prefPaneBundleURL];
    
    NSLog(@"prefPaneBundleURL: %@", prefPaneBundleURL);
    NSLog(@"prefPaneBundle: %@", prefPaneBundle);
    
    return prefPaneBundle;
}

// TODO: Consider returning a mutable dict to avoid constantly using `- mutableCopy`. Maybe even alter `dst` in place and return nothing (And rename to `applyOverridesFrom:to:`).
/// Copy all leaves (elements which aren't dictionaries) from `src` to `dst`. Return the result. (`dst` itself isn't altered)
/// Recursively search for leaves in `src`. For each srcLeaf found, create / replace a leaf in `dst` at a keyPath identical to the keyPath of srcLeaf and with the value of srcLeaf.
/// ((Has and exact copy in Utility_PrefPane))
/// TODO: Transfer changes to copy in Utility_PrefPane
+ (NSDictionary *)dictionaryWithOverridesAppliedFrom:(NSDictionary *)src to: (NSDictionary *)dst {
    NSMutableDictionary *dstMutable = [dst mutableCopy];
    if (dstMutable == nil) {
        dstMutable = [NSMutableDictionary dictionary];
    }
    for (id<NSCopying> key in src) {
        NSObject *dstVal = dst[key];
        NSObject *srcVal = src[key];
        if ([srcVal isKindOfClass:[NSDictionary class]] || [srcVal isKindOfClass:[NSMutableDictionary class]]) { // Not sure if checking for mutable dict AND dict is necessary
            // Nested dictionary found. Recursing.
            NSDictionary *recursionResult = [self dictionaryWithOverridesAppliedFrom:(NSDictionary *)srcVal to:(NSDictionary *)dstVal];
            dstMutable[key] = recursionResult;
        } else {
            // Leaf found
            dstMutable[key] = srcVal;
        }
    }
    return dstMutable;
}

// All of the CG APIs use a flipped coordinate system
+ (CGPoint)getCurrentPointerLocation_flipped {
    
    NSPoint loc = [self getCurrentPointerLocation];
    
    NSAffineTransform* xform = [NSAffineTransform transform];
    [xform translateXBy:0.0 yBy:NSScreen.mainScreen.frame.size.height];
    [xform scaleXBy:1.0 yBy:-1.0];
    [xform transformPoint:loc];
    
    NSLog(@"PointerLoc flipped: x:%f, y:%f", loc.x, loc.y);
    
    return (CGPoint)loc;
}

// All of the CG APIs use a flipped coordinate system
+ (CGPoint)getCurrentPointerLocation_flipped_slow {
    CGEventRef locEvent = CGEventCreate(NULL);
    CGPoint loc = CGEventGetLocation(locEvent);
    CFRelease(locEvent);
    return loc;
}
+ (NSPoint)getCurrentPointerLocation {
    return NSEvent.mouseLocation;
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
