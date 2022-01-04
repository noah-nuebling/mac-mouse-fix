//
// --------------------------------------------------------------------------
// ModifierInputReceiver.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "ScrollModifiers.h"
#import "ScrollControl.h"
#import "SmoothScroll.h"
#import "TouchSimulator.h"

// TODO: Rename to ScrollModifierInputReceiver. Maybe merge this into ScrollControl or put the modifier properties from ScrollControl into this.
@implementation ScrollModifiers

#pragma mark - Public class variables

static BOOL _magnificationScrollHasBeenUsed = NO;
+ (BOOL)magnificationScrollHasBeenUsed {
    return _magnificationScrollHasBeenUsed;
}
+ (void)setMagnificationScrollHasBeenUsed:(BOOL)B {
    _magnificationScrollHasBeenUsed = B;
}

static BOOL _horizontalScrolling;
+ (BOOL)horizontalScrolling {
    return _horizontalScrolling;
}
+ (void)setHorizontalScrolling:(BOOL)B {
    _horizontalScrolling = B;
}
static BOOL _magnificationScrolling;
+ (BOOL)magnificationScrolling {
    return _magnificationScrolling;
}
/**
   \note `_magnificationScrolling` should only ever be set through `setMagnificationScrolling:`!
*/
+ (void)setMagnificationScrolling:(BOOL)B {
    if (!_magnificationScrolling && B) { // Magnification scrolling is being turned on
        ScrollModifiers.magnificationScrollHasBeenUsed = false;
        if (SmoothScroll.isScrolling) { // To avoid random zooming when the user is pressing `magnificationScrollModifierKey` (Command) while scrolling
            [SmoothScroll stop];
            [SmoothScroll start];
        }
    } else if (_magnificationScrolling && !B) { // Magnification scrolling is being turned off
        if (ScrollModifiers.magnificationScrollHasBeenUsed) {
            [TouchSimulator postMagnificationEventWithMagnification:0.0 phase:kIOHIDEventPhaseEnded];
        }
    }
    _magnificationScrolling = B;
}
+ (void)handleMagnificationScrollWithAmount:(double)amount {
    if (ScrollModifiers.magnificationScrollHasBeenUsed == false) {
        ScrollModifiers.magnificationScrollHasBeenUsed = true;
        [TouchSimulator postMagnificationEventWithMagnification:0.0 phase:kIOHIDEventPhaseBegan];
    }
    [TouchSimulator postMagnificationEventWithMagnification:amount phase:kIOHIDEventPhaseChanged];
}

static BOOL _horizontalScrollModifierKeyEnabled = YES;
+ (BOOL)horizontalScrollModifierKeyEnabled {
    return _horizontalScrollModifierKeyEnabled;
}
+ (void)setHorizontalScrollModifierKeyEnabled:(BOOL)B {
    _horizontalScrollModifierKeyEnabled = B;
}
static BOOL _magnificationScrollModifierKeyEnabled = YES;
+ (BOOL)magnificationScrollModifierKeyEnabled {
    return _magnificationScrollModifierKeyEnabled;
}
+ (void)setMagnificationScrollModifierKeyEnabled:(BOOL)B {
    _magnificationScrollModifierKeyEnabled = B;
}

static CGEventFlags _horizontalScrollModifierKeyMask = 0;
+ (void)setHorizontalScrollModifierKeyMask:(CGEventFlags)F {
    _horizontalScrollModifierKeyMask = F;
}
static CGEventFlags _magnificationScrollModifierKeyMask = 0;
+ (void)setMagnificationScrollModifierKeyMask:(CGEventFlags)F {
    _magnificationScrollModifierKeyMask = F;
}

#pragma mark - Private class variables

CFMachPortRef _eventTapKey;

#pragma mark - Public functions

+ (void)initialize {
    
    if (self == ScrollModifiers.class) {
        setupModifierKeyCallback();
    }
}

+ (void)start {
    CGEventTapEnable(_eventTapKey, true);
}
+ (void)stop {
    CGEventTapEnable(_eventTapKey, false);
}

#pragma mark - Private functions

static void setupModifierKeyCallback() {
    CGEventMask mask = CGEventMaskBit(kCGEventFlagsChanged);
    _eventTapKey = CGEventTapCreate(kCGHIDEventTap, kCGHeadInsertEventTap, kCGEventTapOptionDefault, mask, Handle_ModifierChanged, NULL);
    CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, _eventTapKey, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopDefaultMode);
    CFRelease(runLoopSource);
}

CGEventRef Handle_ModifierChanged(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo) {
    CGEventFlags flags = CGEventGetFlags(event);
    if (flags & _horizontalScrollModifierKeyMask && _horizontalScrollModifierKeyEnabled) {
        ScrollModifiers.horizontalScrolling = YES;
    } else {
        ScrollModifiers.horizontalScrolling = NO;
    }
    if (flags & _magnificationScrollModifierKeyMask && _magnificationScrollModifierKeyEnabled) {
        ScrollModifiers.magnificationScrolling = YES;
    } else {
        ScrollModifiers.magnificationScrolling = NO;
    }
    
    /*
     if (flags & kCGEventFlagMaskSecondaryFn) {
     [MomentumScroll temporarilyDisable:TRUE];
     } else {
     [MomentumScroll temporarilyDisable:FALSE];
     }
     */
    
    return event;
}

//static CGEventFlags stringToEventFlagMask(NSString *string) {
//    switch(string) {
//        case @"command":
//            return kCGEventFlagMaskCommand;
//            break;
//        case @"control":
//            return kCGEventFlagMaskControl;
//        case @"option":
//            return kCGEventFlagMaskAlternate;
//            break;
//        case @"shift":
//            return kCGEventFlagMaskShift;
//            break;
//    }
//}

@end
