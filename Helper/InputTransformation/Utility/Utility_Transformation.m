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
//#import "CGSPrivate.h"
#import "SharedUtility.h"
#import "Utility_Helper.h"
#import "CGSCursor.h"

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

+ (void)makeCursorSettable {
    CGSConnectionID _CGSDefaultConnection(void);
    CGSConnectionID cid = _CGSDefaultConnection();
    //    CGSConnectionID cn = CGSMainConnectionID();
    //    CGSConnectionID cid = CGSDefaultConnectionForThread();
    CGSSetConnectionProperty(cid, cid, (__bridge CFStringRef)@"SetsCursorInBackground", kCFBooleanTrue);
}

+ (void)hideMousePointer:(BOOL)B {
    
    /// Source: https://stackoverflow.com/a/3939241/10601702
    /// Normally, hiding  only works from foreground apps
    
    /// Hack to make background cursor setting work
    [self makeCursorSettable];
        
    if (B) {
        
        /// Hide till mouse moves
        
        
//        CGSObscureCursor(cid);
//        [NSCursor setHiddenUntilMouseMoves:YES];
        
        /// Hide unconditionally
        
//        CGSHideCursor(cid);
        CGDisplayHideCursor(kCGDirectMainDisplay);
//        [NSCursor hide];
        
    } else {

        /// Simulate mouse moved event
        
//        CGSRevealCursor(cid);
//        [NSCursor setHiddenUntilMouseMoves:NO];
        
        /// Unhide unconditionally
        
//        CGSShowCursor(cid);
        CGDisplayShowCursor(kCGDirectMainDisplay);
        [NSCursor unhide];
        
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
