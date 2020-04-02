//
// --------------------------------------------------------------------------
// Utility_PrefPane.m
// Created for: Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by: Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "Utility_PrefPane.h"
#import <AppKit/AppKit.h>

@implementation Utility_PrefPane

+ (NSArray *)subviewsForView:(NSView *)view withIdentifier:(NSString *)identifier {
    
    NSMutableArray *subviews = [[NSMutableArray alloc] init];
    for (NSView *v in view.subviews) {
        if ([v.identifier isEqualToString:identifier]) {
            [subviews addObject:v];
        }
    }
    return subviews;
}

+ (float)preferenceWindowWidth {
    
    float result = 668.0; // default in case something goes wrong
    NSMutableArray *windows = (NSMutableArray *)CFBridgingRelease(CGWindowListCopyWindowInfo
                                                                  (kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements, kCGNullWindowID));
    int myProcessIdentifier = [[NSProcessInfo processInfo] processIdentifier];
    BOOL foundWidth = NO;
    for (NSDictionary *window in windows) {
        int windowProcessIdentifier = [[window objectForKey:@"kCGWindowOwnerPID"] intValue];
        if ((myProcessIdentifier == windowProcessIdentifier) && (!foundWidth)) {
            foundWidth = YES;
            NSDictionary *bounds = [window objectForKey:@"kCGWindowBounds"];
            result = [[bounds valueForKey:@"Width"] floatValue];
        }
    }
    return result;
}

/// Copy of identically named function in `Mouse Fix Helper` > `Utility` > `Utility_HelperApp.m`
+ (NSDictionary *)applyOverridesFrom:(NSDictionary *)src to: (NSDictionary *)dst {
    NSMutableDictionary *dstMutable = [dst mutableCopy];
    for (NSString *key in src) {
        NSObject *dstVal = [dst valueForKey:key];
        NSObject *srcVal = [src valueForKey:key];
        if ([srcVal isKindOfClass:[NSDictionary class]] || [srcVal isKindOfClass:[NSMutableDictionary class]]) { // Not sure if checking for mutable dict and dict is necessary
            // Nested dictionary found. Recursing.
            NSDictionary *recursionResult = [self applyOverridesFrom:(NSDictionary *)srcVal to:(NSDictionary *)dstVal];
            [dstMutable setValue:recursionResult forKey:key];
        } else {
            // Leaf found
            [dstMutable setValue:srcVal forKey:key];
        }
    }
    return dstMutable;
}

@end
