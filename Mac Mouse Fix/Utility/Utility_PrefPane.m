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

+ (NSWindow *)mainWindow {
    for (NSWindow *w in NSApp.windows) {
        if ([w.identifier isEqualToString:@"mainWindow"]) {
            return w;
        }
    }
    return nil;
}
+ (void)centerWindow:(NSWindow *)win atPoint:(NSPoint)pt {
    
    NSRect frm = win.frame;
    
    NSPoint newOrg;
    newOrg.x = pt.x - (frm.size.width / 2);
    newOrg.y = pt.y - (frm.size.height / 2);
    
    [win setFrameOrigin:newOrg];
}
+ (NSPoint)getCenterOfRect:(NSRect)rect {
    NSPoint ctr;
    ctr.x = rect.origin.x + (0.5 * rect.size.width);
    ctr.y = rect.origin.y + (0.5 * rect.size.height);
    
    return ctr;
}

/// Copy of identically named function in `Mouse Fix Helper` > `Utility` > `Utility_HelperApp.m`
+ (NSDictionary *)dictionaryWithOverridesAppliedFrom:(NSDictionary *)src to:(NSDictionary *)dst {
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

+ (BOOL)appIsInstalled:(NSString *)bundleID {
    NSString *appPath = [NSWorkspace.sharedWorkspace absolutePathForAppBundleWithIdentifier:bundleID];
    if (appPath) {
        return YES;
    }
    return NO;
}

@end
