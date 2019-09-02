//
//  UtilityPrefPane.m
//  Mouse Fix
//
//  Created by Noah Nübling on 02.09.19.
//  Copyright © 2019 Noah Nuebling. All rights reserved.
//

#import "UtilityPrefPane.h"
#import <AppKit/AppKit.h>

@implementation UtilityPrefPane

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

@end
