//
// --------------------------------------------------------------------------
// RemapUtility.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "Utility_Transformation.h"
#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <ApplicationServices/ApplicationServices.h>
#import "CGSPrivate.h"
#import "SharedUtility.h"
#import "Utility_Helper.h"

@implementation Utility_Transformation

+ (CFMachPortRef)createEventTapWithLocation:(CGEventTapLocation)location
                                       mask:(CGEventMask)mask
                                     option:(CGEventTapOptions)option
                                  placement:(CGEventTapPlacement)placement
                                   callback:(CGEventTapCallBack)callback {
    CFMachPortRef eventTap = CGEventTapCreate(location, placement, option, mask, callback, NULL);
    // ^ Make sure to use the same EventTapLocation and EventTapPlacement here as you do in ButtonInputReceiver, otherwise there'll be timing and ordering issues! (This was one of the causes for the stuck bug and also caused other issues)
    CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
    CFRelease(runLoopSource);
    CGEventTapEnable(eventTap, false);
    return eventTap;
}

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

#pragma mark - Button clicks

+ (void)postMouseButtonClicks:(MFMouseButtonNumber)button nOfClicks:(int64_t)nOfClicks {
    
    CGEventTapLocation tapLoc = kCGSessionEventTap;
    
    CGPoint mouseLoc = getPointerLocation();
    CGEventType eventTypeDown = [SharedUtility CGEventTypeForButtonNumber:button isMouseDown:YES];
    CGEventType eventTypeUp = [SharedUtility CGEventTypeForButtonNumber:button isMouseDown:NO];
    CGMouseButton buttonCG = [SharedUtility CGMouseButtonFromMFMouseButtonNumber:button];
    
    CGEventRef buttonDown = CGEventCreateMouseEvent(NULL, eventTypeDown, mouseLoc, buttonCG);
    CGEventRef buttonUp = CGEventCreateMouseEvent(NULL, eventTypeUp, mouseLoc, buttonCG);
    
    int clickLevel = 1;
    while (clickLevel <= nOfClicks) {
        
        CGEventSetIntegerValueField(buttonDown, kCGMouseEventClickState, clickLevel);
        CGEventSetIntegerValueField(buttonUp, kCGMouseEventClickState, clickLevel);
        
        CGEventPost(tapLoc, buttonDown);
        CGEventPost(tapLoc, buttonUp);
        
        clickLevel++;
    }
    
    CFRelease(buttonDown);
    CFRelease(buttonUp);
}
+ (void)postMouseButton:(MFMouseButtonNumber)button down:(BOOL)down {
    
    DDLogDebug(@"POSTING FAKE MOUSE BUTTON EVENT. btn: %d, down: %d", button, down);
    
    CGEventTapLocation tapLoc = kCGSessionEventTap;
    
    CGPoint mouseLoc = getPointerLocation();
    CGEventType eventTypeDown = [SharedUtility CGEventTypeForButtonNumber:button isMouseDown:down];
    CGMouseButton buttonCG = [SharedUtility CGMouseButtonFromMFMouseButtonNumber:button];
    
    CGEventRef event = CGEventCreateMouseEvent(NULL, eventTypeDown, mouseLoc, buttonCG);
    CGEventSetIntegerValueField(event, kCGMouseEventClickState, 1);
    
    CGEventPost(tapLoc, event);
    CFRelease(event);
}

@end
