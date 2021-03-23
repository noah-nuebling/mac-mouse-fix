//
// --------------------------------------------------------------------------
// Utility_App.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "Utility_App.h"
#import <AppKit/AppKit.h>

@implementation Utility_App

+ (NSArray *)subviewsForView:(NSView *)view withIdentifier:(NSString *)identifier {
    
    NSMutableArray *subviews = [[NSMutableArray alloc] init];
    for (NSView *v in view.subviews) {
        if ([v.identifier isEqualToString:identifier]) {
            [subviews addObject:v];
        }
    }
    return subviews;
}
+ (void)centerWindow:(NSWindow *)win atPoint:(NSPoint)pt {
    
    NSRect frm = win.frame;
    
    NSPoint newOrg;
    newOrg.x = pt.x - (frm.size.width / 2);
    newOrg.y = pt.y - (frm.size.height / 2);
    
    [win setFrameOrigin:newOrg];
}
+ (void)openWindowWithFadeAnimation:(NSWindow *)window fadeIn:(BOOL)fadeIn fadeTime:(NSTimeInterval)time {
    [window makeKeyAndOrderFront: self];
    [window setAlphaValue: fadeIn ? 0.0 : 1.0];
    [NSAnimationContext runAnimationGroup: ^(NSAnimationContext *context) {
        [context setDuration: time];
        [window.animator setAlphaValue:fadeIn ? 1.0 : 0.0];
    } completionHandler:^{
        if (!fadeIn) [window close];
    }];
}
+ (NSPoint)getCenterOfRect:(NSRect)rect {
    NSPoint ctr;
    ctr.x = NSMidX(rect);
    ctr.y = NSMidY(rect);
    
    return ctr;
}
+ (BOOL)appIsInstalled:(NSString *)bundleID {
    NSString *appPath = [NSWorkspace.sharedWorkspace URLForApplicationWithBundleIdentifier:bundleID].path;
    if (appPath) {
        return YES;
    }
    return NO;
}
+ (NSImage *)tintedImage:(NSImage *)image withColor:(NSColor *)tint {
    image = image.copy;
    if (tint) {
        [image lockFocus];
        
        NSRect imageRect = NSMakeRect(0, 0, image.size.width, image.size.height);
        [image drawInRect:imageRect fromRect:imageRect operation:NSCompositingOperationSourceOver fraction:tint.alphaComponent];
        [[tint colorWithAlphaComponent:1] set];
        NSRectFillUsingOperation(imageRect, NSCompositingOperationSourceAtop);
        [image unlockFocus];
    }
    [image setTemplate:NO];
    return image;
}

// Source: https://stackoverflow.com/a/25941139/10601702
+ (CGFloat)actualTextViewWidth:(NSTextView *)textView {
    CGFloat padding = textView.textContainer.lineFragmentPadding;
    CGFloat  actualPageWidth = textView.bounds.size.width - padding * 2;
    return actualPageWidth;
}
//+ (CGFloat)actualTextFieldWidth:(NSTextField *)textField {
//    // Don't know how to make this work
//}

+ (void)attachAddModeTrackingAreaToView:(NSView *)view withOwner:(id)owner {
    NSTrackingArea *addTrackingArea = [[NSTrackingArea alloc] initWithRect:view.frame options:NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways | NSTrackingEnabledDuringMouseDrag owner:owner userInfo:nil];
    // (Well I can't use ad tracking cause I claim to be privacy focused on the website, but at least I can use add tracking! Hmu if you can think of a way to monetize that.)
    [view addTrackingArea:addTrackingArea];
}

@end
