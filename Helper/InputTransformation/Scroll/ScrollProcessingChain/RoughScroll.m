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
#import "MainConfigInterface.h"
#import "ScrollModifiers.h"
#import "Mac_Mouse_Fix_Helper-Swift.h"

@implementation RoughScroll

#pragma mark - Globals

+ (void)start {
}

+ (void)stop {
}

+ (void)handleInput:(CGEventRef)event {
    
    // Process event
    
    if (ScrollConfig.scrollDirection == -1) { // TODO: Use kMFInvertedScrollDirection instead of -1. Implement same change where ever ScrollControl.scrollDirection is used.
        event = [ScrollUtility invertScrollEvent:event direction:ScrollConfig.scrollDirection];
    }
    if (ScrollModifiers.magnificationScrolling) {
        [ScrollModifiers handleMagnificationScrollWithAmount:CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1)/50.0];
    } else {
        if (ScrollModifiers.horizontalScrolling) {
            [ScrollUtility makeScrollEventHorizontal:event];
        }
        CGEventPost(kCGSessionEventTap, event);
    }
}

@end
