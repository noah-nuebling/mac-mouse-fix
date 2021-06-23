//
// --------------------------------------------------------------------------
// GestureScrollSimulator.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "GestureScrollSimulator.h"
#import <QuartzCore/QuartzCore.h>
#import <Cocoa/Cocoa.h>
#import "TouchSimulator.h"
#import "Utility_Helper.h"
#import "SharedUtility.h"
#import "VectorSubPixelator.h"
#import "Utility_Transformation.h"


@implementation GestureScrollSimulator

static Vector _lastInputGestureVector = { .x = 0, .y = 0 };

static VectorSubPixelator *_gesturePixelator;
static VectorSubPixelator *_scrollPointPixelator;
static VectorSubPixelator *_scrollPixelator;

+ (void)initialize
{
    if (self == [GestureScrollSimulator class]) {
        _gesturePixelator = [VectorSubPixelator pixelator];
        _scrollPointPixelator = [VectorSubPixelator pixelator];
        _scrollPixelator = [VectorSubPixelator pixelator];
    }
}

/**
 Post scroll events that behave as if they are coming from an Apple Trackpad or Magic Mouse.
 This function is a wrapper for `postGestureScrollEventWithGestureVector:scrollVector:scrollVectorPoint:phase:momentumPhase:`

 Scrolling will continue automatically but get slower over time after the function has been called with phase kIOHIDEventPhaseEnded.
 
    - The initial speed of this "momentum phase" is based on the delta values of last time that this function is called with at least one non-zero delta and with phase kIOHIDEventPhaseBegan or kIOHIDEventPhaseChanged before it is called with phase kIOHIDEventPhaseEnded.
 
    - The reason behind this is that this is how real trackpad input seems to work. Some apps like Xcode will automatically keep scrolling if no events are sent after the event with phase kIOHIDEventPhaseEnded. And others, like Safari will not. This function wil automatically keep sending events after it has been called with kIOHIDEventPhaseEnded in order to make all apps react as consistently as possible.
 
 \note In order to minimize momentum scrolling,  send an event with a very small but non-zero scroll delta before calling the function with phase kIOHIDEventPhaseEnded.
 \note For more info on which delta values and which phases to use, see the documentation for `postGestureScrollEventWithGestureDeltaX:deltaY:phase:momentumPhase:scrollDeltaConversionFunction:scrollPointDeltaConversionFunction:`. In contrast to the aforementioned function, you shouldn't need to call this function with kIOHIDEventPhaseUndefined.
*/
+ (void)postGestureScrollEventWithDeltaX:(double)dx deltaY:(double)dy phase:(IOHIDEventPhaseBits)phase isGestureDelta:(BOOL)isGestureDelta {
    
    CGPoint loc = Utility_Transformation.CGMouseLocationWithoutEvent;
    if (!isGestureDelta) {
        loc.x += dx;
        loc.y += dy;
    }
    
    if (phase != kIOHIDEventPhaseEnded) {
        
        _breakMomentumScrollFlag = true;
        
        if (phase == kIOHIDEventPhaseChanged && dx == 0.0 && dy == 0.0) {
            return;
        }
        
        Vector vecGesture;
        Vector vecScrollPoint;
        Vector vecScroll;
        if (isGestureDelta) {
            vecGesture = (Vector){ .x = dx, .y = dy };
            vecScrollPoint = scrollPointVectorWithGestureVector(vecGesture);
            vecScroll = scrollVectorWithScrollPointVector(vecScrollPoint);
        } else { // Is scroll point delta
            vecScrollPoint = (Vector){ .x = dx, .y = dy };
            vecGesture = gestureVectorFromScrollPointVector(vecScrollPoint);
            vecScroll = scrollVectorWithScrollPointVector(vecScrollPoint);
        }
        
        vecGesture = [_gesturePixelator intVectorWithDoubleVector:vecGesture];
        vecScrollPoint = [_scrollPointPixelator intVectorWithDoubleVector:vecScrollPoint];
        vecScroll = [_scrollPixelator intVectorWithDoubleVector:vecScroll];
        
        if (phase == kIOHIDEventPhaseBegan || phase == kIOHIDEventPhaseChanged) {
            _lastInputGestureVector = vecGesture;
        }
        [self postGestureScrollEventWithGestureVector:vecGesture
                                         scrollVector:vecScroll
                                    scrollVectorPoint:vecScrollPoint
                                                phase:phase
                                        momentumPhase:kCGMomentumScrollPhaseNone
         locaction:loc];
    } else {
        if (isZeroVector(_lastInputGestureVector)) { // This will never be called, because zero vectors will never be recorded into _lastInputGestureVector. Read the doc above to learn why. TODO: remove.
            [self postGestureScrollEventWithGestureVector:(Vector){}
                                             scrollVector:(Vector){}
                                        scrollVectorPoint:(Vector){}
                                                    phase:kIOHIDEventPhaseEnded
                                            momentumPhase:0
                                                 locaction:loc];
            
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
                //startPostingMomentumScrollEventsWithInitialGestureVector(_lastInputGestureVector, 0.016, 1.0, 4, 1.0);
                double dragCoeff = 8; // Easier to scroll far, kinda nice on a mouse, end still pretty realistic // Got these values by just seeing what feels good
                double dragExp = 0.8;
                startPostingMomentumScrollEventsWithInitialGestureVector(_lastInputGestureVector, 0.016, 1.0, dragCoeff, dragExp);
            });
        } else {
            [self postGestureScrollEventWithGestureVector:(Vector){}
                                             scrollVector:(Vector){}
                                        scrollVectorPoint:(Vector){}
                                                    phase:kIOHIDEventPhaseEnded
                                            momentumPhase:0
                                                locaction:loc];
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
                //startPostingMomentumScrollEventsWithInitialGestureVector(_lastInputGestureVector, 0.016, 1.0, 4, 1.0);
                double dragCoeff = 8; // Easier to scroll far, kinda nice on a mouse, end still pretty realistic // Got these values by just seeing what feels good
                double dragExp = 0.8;
                startPostingMomentumScrollEventsWithInitialGestureVector(_lastInputGestureVector, 0.016, 1.0, dragCoeff, dragExp);
            });
        }
        
    }
}

/// Post scroll events that behave as if they are coming from an Apple Trackpad or Magic Mouse.
/// This allows for swiping between pages in apps like Safari or Preview, and it also makes overscroll and inertial scrolling work.
/// Phases
///     1. kIOHIDEventPhaseMayBegin - First event. Deltas should be 0.
///     2. kIOHIDEventPhaseBegan - Second event. At least one of the two deltas should be non-0.
///     4. kIOHIDEventPhaseChanged - All events in between. At least one of the two deltas should be non-0.
///     5. kIOHIDEventPhaseEnded - Last event before momentum phase. Deltas should be 0.
///       - If you stop sending events at this point, scrolling will continue in certain apps like Xcode, but get slower with time until it stops. The initial speed and direction of this "automatic momentum phase" seems to be based on the last kIOHIDEventPhaseChanged event which contained at least one non-zero delta.
///       - To stop this from happening, either give the last kIOHIDEventPhaseChanged event very small deltas, or send an event with phase kIOHIDEventPhaseUndefined and momentumPhase kCGMomentumScrollPhaseEnd right after this one.
///     6. kIOHIDEventPhaseUndefined - Use this phase with non-0 momentumPhase values. (0 being kCGMomentumScrollPhaseNone)

+ (void)postGestureScrollEventWithGestureVector:(Vector)vecGesture
                                   scrollVector:(Vector)vecScroll
                              scrollVectorPoint:(Vector)vecScrollPoint
                                          phase:(IOHIDEventPhaseBits)phase
                                  momentumPhase:(CGMomentumScrollPhase)momentumPhase
                                      locaction:(CGPoint)loc {
    
    DDLogDebug(@"Posting: gesture: (%f,%f) --- scroll: (%f, %f) --- scrollPt: (%f, %f) --- phases: %d, %d\n",
          vecGesture.x, vecGesture.y, vecScroll.x, vecScroll.y, vecScrollPoint.x, vecScrollPoint.y, phase, momentumPhase);
    
    //
    //  Get stuff we need for both the type 22 and the type 29 event
    //
    
    CGPoint eventLocation = [Utility_Helper getCurrentPointerLocation_flipped]; /// This always resolves to the same location during a drag for some reason. But that's great, because it makes scrolling still work, even when the pointer leaves the window where you started scrolling!
    
    //
    // Create type 22 event
    //
    
    CGEventRef e22 = CGEventCreate(NULL);
    
    // Set static fields
    
    CGEventSetDoubleValueField(e22, 55, 22); // 22 -> NSEventTypeScrollWheel // Setting field 55 is the same as using CGEventSetType(), I'm not sure if that has weird side-effects though, so I'd rather do it this way.
    CGEventSetDoubleValueField(e22, 88, 1); // 88 -> kCGScrollWheelEventIsContinuous
    CGEventSetDoubleValueField(e22, 137, 1); /// Maybe NSEvent.directionInvertedFromDevice
    
    // Set dynamic fields
    
    // Scroll deltas
    // Not sure the rounding / flooring is necessary
    CGEventSetDoubleValueField(e22, 11, floor(vecScroll.y)); // 11 -> kCGScrollWheelEventDeltaAxis1
    CGEventSetDoubleValueField(e22, 96, round(vecScrollPoint.y)); // 96 -> kCGScrollWheelEventPointDeltaAxis1
    
    CGEventSetDoubleValueField(e22, 12, floor(vecScroll.x)); // 12 -> kCGScrollWheelEventDeltaAxis2
    CGEventSetDoubleValueField(e22, 97, round(vecScrollPoint.x)); // 97 -> kCGScrollWheelEventPointDeltaAxis2
    
    // Phase
    
    CGEventSetDoubleValueField(e22, 99, phase);
    CGEventSetDoubleValueField(e22, 123, momentumPhase);
    
    // Testing
    
//    CGPoint flippedNSLoc = [Utility_Helper getCurrentPointerLocation_flipped];
//    CGPoint CGLoc = Utility_Transformation.CG
//    DDLogInfo(@"\nFLIPPED NS: %f, %f \nCG: %f, %f", flippedNSLoc.x, flippedNSLoc.y, CGLoc.x, CGLoc.y);
    
    // Post t22s0 event
    
    CGEventSetLocation(e22, eventLocation);
    CGEventPost(kCGSessionEventTap, e22); // Needs to be kCGHIDEventTap instead of kCGSessionEventTap to work with Swish, but it will make the events feed back into our scroll event tap. That's not too bad though, because we ignore continuous events anyways.
    CFRelease(e22);
    
    if (momentumPhase == 0) {
        
        //
        // Create type 29 subtype 6 event
        //
        
        CGEventRef e29 = CGEventCreate(NULL);
        
        // Set static fields
        
        CGEventSetDoubleValueField(e29, 55, 29); // 29 -> NSEventTypeGesture // Setting field 55 is the same as using CGEventSetType()
        CGEventSetDoubleValueField(e29, 110, 6); // 110 -> subtype // 6 -> kIOHIDEventTypeScroll
        
        // Set dynamic fields
        
        double dxGesture = (double)vecGesture.x;
        double dyGesture = (double)vecGesture.y;
        if (dxGesture == 0) {
            dxGesture = -0.0f; // The original events only contain -0 but this probs doesn't make a difference.
        }
        if (dyGesture == 0) {
            dyGesture = -0.0f; // The original events only contain -0 but this probs doesn't make a difference.
        }
        CGEventSetDoubleValueField(e29, 116, dxGesture);
        CGEventSetDoubleValueField(e29, 119, dyGesture);
        
        CGEventSetIntegerValueField(e29, 132, phase);
        
        // Post t29s6 events
        CGEventSetLocation(e29, eventLocation);
        CGEventPost(kCGSessionEventTap, e29);

        CFRelease(e29);
    }
}

static bool _momentumScrollIsActive; // Should only be manipulated by `startPostingMomentumScrollEventsWithInitialGestureVector()`
static bool _breakMomentumScrollFlag; // Should only be manipulated by `breakMomentumScroll`

+ (void)breakMomentumScroll {
    _breakMomentumScrollFlag = true;
}
static void startPostingMomentumScrollEventsWithInitialGestureVector(Vector initGestureVec, CFTimeInterval tick, int thresh, double dragCoeff, double dragExp) {
    
    _breakMomentumScrollFlag = false;
    _momentumScrollIsActive = true;
    
    Vector emptyVec = (const Vector){};
    
    Vector vecPt = initalMomentumScrollPointVectorWithGestureVector(initGestureVec);
    Vector vec = scrollVectorWithScrollPointVector(vecPt);
    double magPt = magnitudeOfVector(vecPt);
    CGMomentumScrollPhase ph = kCGMomentumScrollPhaseBegin;
    
    CFTimeInterval prevTs = CACurrentMediaTime();
    while (magPt > thresh) {
        if (_breakMomentumScrollFlag == true) {
            DDLogInfo(@"BREAKING MOMENTUM SCROLL");
            break;
        }
        CGPoint loc = Utility_Transformation.CGMouseLocationWithoutEvent;
        [GestureScrollSimulator postGestureScrollEventWithGestureVector:emptyVec scrollVector:vec scrollVectorPoint:vecPt phase:kIOHIDEventPhaseUndefined momentumPhase:ph locaction:loc];
        
        [NSThread sleepForTimeInterval:tick]; // Not sure if it's good to pause the whole thread here, using a display link or ns timer or sth is probably much faster. But this seems to work fine so whatevs.
        CFTimeInterval ts = CACurrentMediaTime();
        CFTimeInterval timeDelta = ts - prevTs;
        prevTs = ts;
        
        vecPt = momentumScrollPointVectorWithPreviousVector(vecPt, dragCoeff, dragExp, timeDelta);
        vec = scrollVectorWithScrollPointVector(vecPt);
        magPt = magnitudeOfVector(vecPt);
        ph = kCGMomentumScrollPhaseContinue;
        
    }
    CGPoint loc = Utility_Transformation.CGMouseLocationWithoutEvent;
    [GestureScrollSimulator postGestureScrollEventWithGestureVector:emptyVec
                                                       scrollVector:emptyVec
                                                  scrollVectorPoint:emptyVec
                                                              phase:kIOHIDEventPhaseUndefined
                                                      momentumPhase:kCGMomentumScrollPhaseEnd
                                                          locaction:loc];
    _momentumScrollIsActive = false;
    
}

static Vector momentumScrollPointVectorWithPreviousVector(Vector velocity, double dragCoeff, double dragExp, double timeDelta) {
    
    double a = magnitudeOfVector(velocity);
    double b = pow(a, dragExp);
    double dragMagnitude = b * dragCoeff;
    
    Vector unitVec = unitVector(velocity);
    Vector dragForce = scaledVector(unitVec, dragMagnitude);
    dragForce = scaledVector(dragForce, -1);
    
    Vector velocityDelta = scaledVector(dragForce, timeDelta);
    
    Vector newVelocity = addedVectors(velocity, velocityDelta);
    
    double dp = dotProduct(velocity, newVelocity);
    if (dp < 0) { // Vector has changed direction (crossed zero)
        newVelocity = (const Vector){}; // Set to zero
    }
    return newVelocity;
}

static Vector scrollVectorWithScrollPointVector(Vector vec) {
    VectorScalerFunction f = ^double(double x) {
        return 0.1 * (x-1); // Approximation from looking at real trackpad events
    };
    return scaledVectorWithFunction(vec, f);
}
static Vector scrollPointVectorWithGestureVector(Vector vec) {
    VectorScalerFunction f = ^double(double x) {
        //    double magOut = 0.01 * pow(magIn, 2) + 0.3 * magIn; // Got these values through curve fitting
        //    double magOut = 0.05 * pow(magIn, 2) + 0.8 * magIn; // These feel better for mouse
        return 0.08 * pow(x, 2) + 0.8 * x; // Even better feel - precise and fast at the same time
    };
    return scaledVectorWithFunction(vec, f);
}
static Vector gestureVectorFromScrollPointVector(Vector vec) {
    VectorScalerFunction f = ^double(double x) {
//        x = 0.54 * x; // Tried to make input pixels to equal animation pixels, but the scaling seems to always be different and be dependent on page size. Might as well just leave it like it is because it feels decent enough
        return x;
    };
    return scaledVectorWithFunction(vec, f);
}

static Vector initalMomentumScrollPointVectorWithGestureVector(Vector vec) {
    Vector vecScale = scaledVector(vec, 2.2); // This is probably not very accurate to real events, as I didn't test this at all.
    return scrollPointVectorWithGestureVector(vecScale);
}

// v Original delta conversion formulas which are the basis for the vector conversion functions above. These are relatively accurated to real events.

//static int scrollDeltaWithGestureDelta(int d) {
//    return floor(0.1 * (d-1));
//}
//static int scrollPointDeltaWithGestureDelta(int d) {
//    return round(0.01 * pow(d,2) + 0.3 * d);
//}

@end
