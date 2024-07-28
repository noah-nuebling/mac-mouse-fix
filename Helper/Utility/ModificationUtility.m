//
// --------------------------------------------------------------------------
// ModificationUtility.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "ModificationUtility.h"
#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <ApplicationServices/ApplicationServices.h>
//#import "CGSPrivate.h"
#import "SharedUtility.h"
#import "HelperUtility.h"
#import "CGSCursor.h"
#include <sys/types.h>
#include <sys/sysctl.h>
#import "Logging.h"

@implementation ModificationUtility


/// NOTE:
/// At the time of writing this class is a bit of a hodgepodge of utility methods for both scroll modifications and drag modifications. Should probably split this up.


BOOL directionChanged(MFDirection direction1, MFDirection direction2) {
    
    if (direction1 == kMFDirectionNone || direction2 == kMFDirectionNone) {
        return NO;
    }
    
    if (direction1 == direction2) {
        return NO;
    }
    
    return YES;
}

+ (double)roundUp:(double)numToRound toMultiple:(double)multiple {
    /// Src: https://stackoverflow.com/a/3407254/10601702
    
    if (multiple == 0) return numToRound;
    
    double remainder = fmod(numToRound, multiple);
    
    if (remainder == 0) return numToRound;
    
    return numToRound + multiple - remainder;
}

+ (NSTimeInterval)nsTimeStamp {
    /// Time since system startup in seconds. This value is used in NSEvent timestamps

    int MIB_SIZE = 2;
    
    int mib[MIB_SIZE];
    size_t size;
    struct timeval boottime;
    
    mib[0] = CTL_KERN;
    mib[1] = KERN_BOOTTIME;
    size = sizeof(boottime);
    if (sysctl(mib, MIB_SIZE, &boottime, &size, NULL, 0) != -1) {
        return boottime.tv_sec + (((double)boottime.tv_usec) / USEC_PER_SEC);
    }
    
    return 0.0;
}

+ (CFMachPortRef)createEventTapWithLocation:(CGEventTapLocation)location
                                       mask:(CGEventMask)mask
                                     option:(CGEventTapOptions)option
                                  placement:(CGEventTapPlacement)placement
                                   callback:(CGEventTapCallBack)callback {
    
    CFRunLoopRef rl = CFRunLoopGetMain();
    return [self createEventTapWithLocation:location mask:mask option:option placement:placement callback:callback runLoop:rl];
}

+ (CFMachPortRef)createEventTapWithLocation:(CGEventTapLocation)location
                                       mask:(CGEventMask)mask
                                     option:(CGEventTapOptions)option
                                  placement:(CGEventTapPlacement)placement
                                   callback:(CGEventTapCallBack)callback
                                    runLoop:(CFRunLoopRef)runLoop {
    CFMachPortRef eventTap = CGEventTapCreate(location, placement, option, mask, callback, NULL);
    /// ^ Make sure to use the same EventTapLocation and EventTapPlacement here as you do in ButtonInputReceiver, otherwise there'll be timing and ordering issues! (This was one of the causes for the stuck bug and also caused other issues)
    CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0);
    CFRunLoopAddSource(runLoop, runLoopSource, kCFRunLoopCommonModes);
    CFRelease(runLoopSource);
    CGEventTapEnable(eventTap, false);
    return eventTap;
}

+ (void)makeCursorSettable {
    
    /// Only do this once
    static BOOL cursorIsSettable = NO;
    if (cursorIsSettable) return;
    
    /// Declare func
    CGSConnectionID _CGSDefaultConnection(void);
    /// Call func -> Get connection
    CGSConnectionID cid = _CGSDefaultConnection();
    /// ^ Alternative funcs: CGSMainConnectionID(), CGSDefaultConnectionForThread()
    ///     _CGSDefaultConnection() works fine so far though
    /// Make cursor settable!
    CGSSetConnectionProperty(cid, cid, (__bridge CFStringRef)@"SetsCursorInBackground", kCFBooleanTrue);
    
    /// Note that cursor is now settable
    cursorIsSettable = YES;
}

+ (void)hideMousePointer:(BOOL)B {
    
    /// Source: https://stackoverflow.com/a/3939241/10601702
    /// Normally, hiding  only works from foreground apps
    
    /// Hack to make background cursor setting work
    [self makeCursorSettable];
        
    if (B) {
        
        DDLogDebug(@"Hiding pointer");
        
//        CGSHideCursor(cid);
        CGDisplayHideCursor(kCGDirectMainDisplay);
//        [NSCursor hide];
        
    } else {
        
        DDLogDebug(@"UNHiding pointer");
        
//        CGSShowCursor(cid);
        CGDisplayShowCursor(kCGDirectMainDisplay); /// Do it twice for good measure.
        CGError result = CGDisplayShowCursor(kCGDirectMainDisplay);
        if (result != kCGErrorSuccess) {
            DDLogDebug(@"Unhiding pointer failed. CGError: %d", result);
        }
//        [NSCursor unhide];
        
    }
}

#pragma mark - Button clicks

+ (void)postMouseButtonClicks:(MFMouseButtonNumber)button nOfClicks:(int64_t)nOfClicks {
    
    DDLogDebug(@"Posting %lld mouse button %u clicks", nOfClicks, button);
    
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
    
    /// I tried dispatching this event at a point other than the current cursor position, without moving the cursor.
    /// That would maybe help with this issue:  https://github.com/noah-nuebling/mac-mouse-fix/issues/157#issuecomment-932108105)
    /// I couldn't do it, though/ Here's what I tried:
    ///     Sending another mouse click at the original location - Only works like 1/4
    ///     Sending another mouse up event at the original location - Works exactly 1/3
    ///  I know this won't work:
    ///     CGWarpMousePointer - I'm using this in version-3 branch and has a delay after it where you can't move the poiner at all. If you turn off the delay it doesn't work anymore.
    ///  If feel like this might be impossible because macOS might need this small delay to move the pointer programmatically.
    
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
