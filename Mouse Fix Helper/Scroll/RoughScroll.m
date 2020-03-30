//
// --------------------------------------------------------------------------
// RoughScroll.m
// Created for: Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by: Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "RoughScroll.h"

@implementation RoughScroll

@end


//if (_isEnabled == FALSE) {
//    if (mouseMoved == TRUE) {
//        setConfigVariablesForActiveApp();
//    }
//    if (_scrollDirection == -1) {
//        event = [ScrollUtility invertScrollEvent:event direction:_scrollDirection];
//    }
//    if (_magnificationModifierIsPressed) { //TODO: TODO: Consider acitvating displayLink to send magnification events instead (After sorting out activity states of SmoothScroll.m)
//        [TouchSimulator postEventWithMagnification:CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1)/200.0 phase:kIOHIDEventPhaseChanged];
//        return nil;
//    } else {
//        return event;
//    }
//}
