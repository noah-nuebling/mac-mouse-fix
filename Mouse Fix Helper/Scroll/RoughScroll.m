//
// --------------------------------------------------------------------------
// RoughScroll.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "RoughScroll.h"
#import "ScrollControl.h"
#import "TouchSimulator.h"
#import "ScrollUtility.h"
#import "ConfigFileInterface_HelperApp.h"
#import "ScrollModifiers.h"

@implementation RoughScroll

#pragma mark - Globals

+ (void)start {
}

+ (void)stop {
}

+ (void)handleInput:(CGEventRef)event info:(NSDictionary * _Nullable)info {
    
    // Process event
    
    if (ScrollControl.scrollDirection == -1) { // TODO: Use kMFInvertedScrollDirection instead of -1. Implement same change where ever ScrollControl.scrollDirection is used.
        event = [ScrollUtility invertScrollEvent:event direction:ScrollControl.scrollDirection];
    }
    if (ScrollModifiers.magnificationScrolling) {
        [TouchSimulator postEventWithMagnification:CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1)/50.0 phase:kIOHIDEventPhaseChanged];
    } else {
        if (ScrollModifiers.horizontalScrolling) {
            [ScrollUtility makeScrollEventHorizontal:event];
        }
        CGEventPost(kCGSessionEventTap, event);
    }
}

@end
