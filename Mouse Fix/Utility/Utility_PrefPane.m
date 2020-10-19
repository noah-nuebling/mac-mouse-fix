//
// --------------------------------------------------------------------------
// Utility_PrefPane.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
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

+ (BOOL)appIsInstalled:(NSString *)bundleID {
    NSString *appPath = [NSWorkspace.sharedWorkspace absolutePathForAppBundleWithIdentifier:bundleID];
    if (appPath) {
        return YES;
    }
    return NO;
}

@end
