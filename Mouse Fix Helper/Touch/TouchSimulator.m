//
// --------------------------------------------------------------------------
// TouchSimulator.m
// Created for: Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by: Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "TouchSimulator.h"
#import <Foundation/Foundation.h>

@implementation TouchSimulator

static NSArray *_nullArray;
static NSMutableDictionary *_swipeInfo;

+ (void)initialize{
    
    // setup touch event constants
    _nullArray = @[];
    _swipeInfo = [NSMutableDictionary dictionary];
    for (NSNumber* direction in @[ @(kTLInfoSwipeUp), @(kTLInfoSwipeDown), @(kTLInfoSwipeLeft), @(kTLInfoSwipeRight) ]) {
        NSDictionary* swipeInfo1 = [NSDictionary dictionaryWithObjectsAndKeys:
                                    @(kTLInfoSubtypeSwipe), kTLInfoKeyGestureSubtype,
                                    @(1), kTLInfoKeyGesturePhase,
                                    nil];
        
        NSDictionary* swipeInfo2 = [NSDictionary dictionaryWithObjectsAndKeys:
                                    @(kTLInfoSubtypeSwipe), kTLInfoKeyGestureSubtype,
                                    direction, kTLInfoKeySwipeDirection,
                                    @(4), kTLInfoKeyGesturePhase,
                                    nil];
        
        _swipeInfo[direction] = @[ swipeInfo1, swipeInfo2 ];
    }
}

+ (void)SBFFakeSwipe:(TLInfoSwipeDirection)dir {
    
    NSArray *nullArray = @[];
    
    CGEventRef event1 = tl_CGEventCreateFromGesture((__bridge CFDictionaryRef)(_swipeInfo[@(dir)][0]), (__bridge CFArrayRef)nullArray);
    CGEventRef event2 = tl_CGEventCreateFromGesture((__bridge CFDictionaryRef)(_swipeInfo[@(dir)][1]), (__bridge CFArrayRef)nullArray);
    
    CGEventPost(kCGHIDEventTap, event1);
    CGEventPost(kCGHIDEventTap, event2);
    
    CFRelease(event1);
    CFRelease(event2);
}

+ (void)postEventWithMagnification:(double)magnification phase:(IOHIDEventPhaseBits)phase {
    
    NSDictionary *magnifyInfo = [NSDictionary dictionaryWithObjectsAndKeys:
    @(kTLInfoSubtypeMagnify), kTLInfoKeyGestureSubtype,
    @(phase), kTLInfoKeyGesturePhase,
    @(-magnification), kTLInfoKeyMagnification,
    nil];
    
    CGEventRef event = tl_CGEventCreateFromGesture((__bridge CFDictionaryRef)(magnifyInfo), (__bridge CFArrayRef) @[]);
    
    CGEventPost(kCGHIDEventTap, event);
    CFRelease(event);
}

@end

