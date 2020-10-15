//
// --------------------------------------------------------------------------
// RemapUtility.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "RemapUtility.h"
#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <ApplicationServices/ApplicationServices.h>
#import "CGSPrivate.h"

@implementation RemapUtility

+ (void)hideMousePointer:(BOOL)B {
    
    if (B) {
        void CGSSetConnectionProperty(int, int, CFStringRef, CFBooleanRef);
        int _CGSDefaultConnection(void);
        CFStringRef propertyString;

        // Hack to make background cursor setting work
        propertyString = CFStringCreateWithCString(NULL, "SetsCursorInBackground", kCFStringEncodingUTF8);
        CGSSetConnectionProperty(_CGSDefaultConnection(), _CGSDefaultConnection(), propertyString, kCFBooleanTrue);
        CFRelease(propertyString);
        // Hide the cursor and wait
        CGDisplayHideCursor(kCGDirectMainDisplay);
//        pause();
    } else {
        CGDisplayShowCursor(kCGDirectMainDisplay);
    }
}

@end
