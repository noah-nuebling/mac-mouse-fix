//
// --------------------------------------------------------------------------
// TouchSimulator.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

/// Credits:
/// I originally found the code for the `postNavigationSwipeWithDirection:` function in Alexei Baboulevitch's SensibleSideButtons project under the name `SBFFakeSwipe:`. SensibleSideButtons was itself heavily based on natevw's macOS touch reverse engineering work ("CalfTrail Touch") for his app Sesamouse from wayy back in the day. Nate's work was the basis for all all of this. Thanks Nate! :)

#import "TouchSimulator.h"
#import <Foundation/Foundation.h>
#import "ScrollControl.h"
#import <Cocoa/Cocoa.h>

@implementation TouchSimulator

static NSArray *_nullArray;
static NSMutableDictionary *_swipeInfo;

/// This function allows you to go back and forward in apps like Safari.
///
/// Navigation swipe events are actually quite complex and seem to be similar to dock swipes internally (They seem to also have an origin offset and other similar fields from what i've seen)
/// However, this simple function replicates all of their interesting functionality, so I didn't bother reverse engineering them more thoroughly.
/// Navigation swipes are naturally produced by three finger swipes, but only if you set "System Preferences > Trackpad > More Gestures > Swipe between pages" to "Swipe with three fingers" or to "Swipe with two or three fingers"
+ (void)postNavigationSwipeEventWithDirection:(IOHIDSwipeMask)dir {
    
    CGEventRef e = CGEventCreate(NULL);
    CGEventSetIntegerValueField(e, 55, NSEventTypeGesture);
    CGEventSetIntegerValueField(e, 110, kIOHIDEventTypeNavigationSwipe);
    CGEventSetIntegerValueField(e, 132, kIOHIDEventPhaseBegan);
    CGEventSetIntegerValueField(e, 115, dir);
    
    CGEventPost(kCGHIDEventTap, e);
    CGEventSetIntegerValueField(e, 115, kIOHIDSwipeNone);
    CGEventSetIntegerValueField(e, 132, kIOHIDEventPhaseEnded);
    CGEventPost(kCGHIDEventTap, e);
    CFRelease(e);
}

+ (void)postSmartZoomEvent {
    
    CGEventRef e = CGEventCreate(NULL);
    CGEventSetIntegerValueField(e, 55, 29); // NSEventTypeGesture
    CGEventSetIntegerValueField(e, 110, 22); // kIOHIDEventTypeZoomToggle
    CGEventPost(kCGHIDEventTap, e);
    CFRelease(e);
}

+ (void)postRotationEventWithRotation:(double)rotation phase:(IOHIDEventPhaseBits)phase {
    
    CGEventRef e = CGEventCreate(NULL);
    // Could also use CGEventSetType() here
    CGEventSetIntegerValueField(e, 55, 29); // NSEventTypeGesture
    CGEventSetIntegerValueField(e, 110, 5); // kIOHIDEventTypeRotation
    CGEventSetDoubleValueField(e, 114, rotation);
    CGEventSetIntegerValueField(e, 132, phase);
    CGEventPost(kCGHIDEventTap, e);
    CFRelease(e);
}

+ (void)postMagnificationEventWithMagnification:(double)magnification phase:(IOHIDEventPhaseBits)phase { // TODO: CLEAN this up.
    
    // Using undocumented CGEventFields found through Calftrail TouchExtractor and through analyzing Calftrail TouchSynthesis to create a working magnification event from scratch
    
    CGEventRef event = CGEventCreate(NULL);
    CGEventSetType(event, 29); // 29 -> NSEventTypeGesture
    CGEventSetIntegerValueField(event, 110, 8); // 8 -> kIOHIDEventTypeZoom
    CGEventSetIntegerValueField(event, 132, phase);
    CGEventSetDoubleValueField(event, 113, magnification);
    CGEventPost(kCGHIDEventTap, event);
    CFRelease(event);
}

double _threeFingerSwipeOriginOffset = 0;
+ (void)postDockSwipeEventWithDelta:(double)d type:(MFDockSwipeType)type phase:(IOHIDEventPhaseBits)phase {
    
    int valFor41 = 33231;
    
    if (phase == kIOHIDEventPhaseBegan) {
        _threeFingerSwipeOriginOffset = d;
    } else if (phase == kIOHIDEventPhaseChanged){
        if (d == 0) {
            return;
        }
        _threeFingerSwipeOriginOffset += d;
    }
    
    // Create type 29 (NSEventTypeGesture) event
    
    CGEventRef e29 = CGEventCreate(NULL);
    CGEventSetDoubleValueField(e29, 55, NSEventTypeGesture); // Set event type
    CGEventSetDoubleValueField(e29, 41, valFor41); // No idea what this does but it might help. // TODO: Why?
    
    // Create type 30 event
    
    CGEventRef e30 = CGEventCreate(NULL);
    
    CGEventSetDoubleValueField(e30, 55,  NSEventTypeMagnify); // Set event type (idk why it's magnify but it is...)
    CGEventSetDoubleValueField(e30, 110, kIOHIDEventTypeDockSwipe); // Set subtype
    CGEventSetDoubleValueField(e30, 132, phase);
    CGEventSetDoubleValueField(e30, 134, phase); // TODO: Check if necessary

    CGEventSetDoubleValueField(e30, 124, _threeFingerSwipeOriginOffset); // origin offset
    Float32 ofsFloat32 = (Float32)_threeFingerSwipeOriginOffset;
    uint32_t ofsInt32; // Has to be uint32_t not int32_t!
    memcpy(&ofsInt32, &ofsFloat32, sizeof(ofsFloat32));
    int64_t ofsInt64 = (int64_t)ofsInt32;
    CGEventSetIntegerValueField(e30, 135, ofsInt64); // Weird ass encoded version of origin offset. It's a 64 bit integer containing the bits for a 32 bit float. No idea why this is necessary, but it is.
    
    CGEventSetDoubleValueField(e30, 41, valFor41); // This mighttt help not sure what it do
    
    double weirdTypeOrSum = 1.401298464324817e-45; // Magic horizontal type
    if (type == kMFDockSwipeTypeVertical) {
        weirdTypeOrSum = 2.802596928649634e-45; // Magic vertical type
    } // TODO: Find the value for Type Pinch events (These values are probably an encoded version of the values in MFDockSwipeType. We can probs just convert that and put it in here)
    
    CGEventSetDoubleValueField(e30, 119, weirdTypeOrSum);
    CGEventSetDoubleValueField(e30, 139, weirdTypeOrSum);  // Probs not necessary
    
    CGEventSetDoubleValueField(e30, 123, type); // Horizontal or vertical
    CGEventSetDoubleValueField(e30, 165, type); // Horizontal or vertical // Probs not necessary
    
    CGEventSetDoubleValueField(e30, 136, 1); // Vertical invert
    
//    if (phase == kIOHIDEventPhaseEnded) {
//        CGEventSetDoubleValueField(e30, 129, -d); // Momentum or something // Setting it doesn't seem to do anything
//        CGEventSetDoubleValueField(e30, 130, -d); // Momentum or something
//    }
    
    
    // Send events
    
    CGEventPost(kCGHIDEventTap, e30); // TODO: Check if order matters
    CGEventPost(kCGHIDEventTap, e29);
    
    if (phase == kIOHIDEventPhaseEnded) {
        CGEventPost(kCGHIDEventTap, e29); // Probs not necessary
    }
    
    CFRelease(e29);
    CFRelease(e30);

}


@end

