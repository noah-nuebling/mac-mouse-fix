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
#import "Utility_HelperApp.h"
#import "SharedUtility.h"
#import "VectorSubPixelator.h"


@implementation GestureScrollSimulator

static MFVector _lastInputGestureVector = { .x = 0, .y = 0 };

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
    
#if DEBUG
//    NSLog(@"GESTURE DELTAS: %f, %f, PHASE: %d", dx, dy, phase);
#endif
    
    CGPoint loc = CGEventGetLocation(CGEventCreate(NULL));
    if (!isGestureDelta) {
        loc.x += dx;
        loc.y += dy;
    }
    
    if (phase != kIOHIDEventPhaseEnded) {
        
        _breakMomentumScrollFlag = true;
        
        if (phase == kIOHIDEventPhaseChanged && dx == 0.0 && dy == 0.0) {
            return;
        }
        
        MFVector vecGesture;
        MFVector vecScrollPoint;
        MFVector vecScroll;
        if (isGestureDelta) {
            vecGesture = (MFVector){ .x = dx, .y = dy };
            vecScrollPoint = scrollPointVectorWithGestureVector(vecGesture);
            vecScroll = scrollVectorWithScrollPointVector(vecScrollPoint);
        } else { // Is scroll point delta
            vecScrollPoint = (MFVector){ .x = dx, .y = dy };
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
        [self postGestureScrollEventWithGestureVector:(MFVector){}
                                         scrollVector:(MFVector){}
                                    scrollVectorPoint:(MFVector){}
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

+ (void)postGestureScrollEventWithGestureVector:(MFVector)vecGesture
                                   scrollVector:(MFVector)vecScroll
                              scrollVectorPoint:(MFVector)vecScrollPoint
                                          phase:(IOHIDEventPhaseBits)phase
                                  momentumPhase:(CGMomentumScrollPhase)momentumPhase
                                      locaction:(CGPoint)loc {
    
    
//    printf("Posting gesture scroll event with delta values:\n");
//    printf("gesture: x:%f y:%f \nscroll: x:%f y:%f \nscrollPt: x:%f y:%f\n",
//          vecGesture.x, vecGesture.y, vecScroll.x, vecScroll.y, vecScrollPoint.x, vecScrollPoint.y);
    
    //
    // Create type 22 event
    //
    
    CGEventRef e22 = CGEventCreate(NULL);
    
    // Set static fields
    
    CGEventSetDoubleValueField(e22, 55, 22); // 22 -> NSEventTypeScrollWheel // Setting field 55 is the same as using CGEventSetType(), I'm not sure if that has weird side-effects though, so I'd rather do it this way.
    CGEventSetDoubleValueField(e22, 88, 1); // magic?
    
    // Set dynamic fields
    
    // Scroll deltas
    
    CGEventSetDoubleValueField(e22, kCGScrollWheelEventDeltaAxis1, floor(vecScroll.y));
    CGEventSetDoubleValueField(e22, kCGScrollWheelEventPointDeltaAxis1, round(vecScrollPoint.y));
    
    CGEventSetDoubleValueField(e22, kCGScrollWheelEventDeltaAxis2, floor(vecScroll.x));
    CGEventSetDoubleValueField(e22, kCGScrollWheelEventPointDeltaAxis2, round(vecScrollPoint.x));
    
    // Phase
    
    CGEventSetDoubleValueField(e22, 99, phase);
    CGEventSetDoubleValueField(e22, 123, momentumPhase);
    
    // Testing
    
//    CGPoint flippedNSLoc = [Utility_HelperApp getCurrentPointerLocation_flipped];
//    CGPoint CGLoc = CGEventGetLocation(CGEventCreate(NULL));
//    NSLog(@"\nFLIPPED NS: %f, %f \nCG: %f, %f", flippedNSLoc.x, flippedNSLoc.y, CGLoc.x, CGLoc.y);
    
    // Post t22s0 event
    CGEventSetLocation(e22, [Utility_HelperApp getCurrentPointerLocation_flipped]);
    CGEventPost(kCGHIDEventTap, e22);
    CFRelease(e22);
    
    if (momentumPhase == 0) {
        
        //
        // Create type 29 subtype 6 event
        //
        
        CGEventRef e29 = CGEventCreate(NULL);
        
        // Set static fields
        
        CGEventSetDoubleValueField(e29, 55, 29); // 29 -> NSEventTypeGesture // Setting field 55 is the same as using CGEventSetType()
        CGEventSetDoubleValueField(e29, 110, 6); // Field 110 -> subtype // 6 -> kIOHIDEventTypeScroll
        
        // Set dynamic fields
        
        double xVec = (double)vecGesture.x;
        if (xVec == 0) {
            xVec = -0.0f; // The original events only contain -0 but this probs doesn't make a difference.
        }
        CGEventSetDoubleValueField(e29, 116, xVec);
        
        double yVec = (double)vecGesture.y;
        if (yVec == 0) {
            yVec = -0.0f; // The original events only contain -0 but this probs doesn't make a difference.
        }
        CGEventSetDoubleValueField(e29, 119, yVec);
        
        CGEventSetIntegerValueField(e29, 132, phase);
        
        // Post t29s6 events
        CGEventSetLocation(e29, [Utility_HelperApp getCurrentPointerLocation_flipped]);
        CGEventPost(kCGHIDEventTap, e29);
        //    printEvent(e29);
        CFRelease(e29);
    }
}

static bool _momentumScrollIsActive; // Should only be manipulated by `startPostingMomentumScrollEventsWithInitialGestureVector()`
static bool _breakMomentumScrollFlag; // Should only be manipulated by `breakMomentumScroll`

+ (void)breakMomentumScroll {
    _breakMomentumScrollFlag = true;
}
static void startPostingMomentumScrollEventsWithInitialGestureVector(MFVector initGestureVec, CFTimeInterval tick, int thresh, double dragCoeff, double dragExp) {
    
    _breakMomentumScrollFlag = false;
    _momentumScrollIsActive = true;
    
    MFVector emptyVec = (const MFVector){};
    
    MFVector vecPt = initalMomentumScrollPointVectorWithGestureVector(initGestureVec);
    MFVector vec = scrollVectorWithScrollPointVector(vecPt);
    double magPt = magnitudeOfVector(vecPt);
    CGMomentumScrollPhase ph = kCGMomentumScrollPhaseBegin;
    
    CFTimeInterval prevTs = CACurrentMediaTime();
    while (magPt > thresh) {
        if (_breakMomentumScrollFlag == true) {
            NSLog(@"BREAKING MOMENTUM SCROLL");
            break;
        }
        CGPoint loc = CGEventGetLocation(CGEventCreate(NULL));
        [GestureScrollSimulator postGestureScrollEventWithGestureVector:emptyVec scrollVector:vec scrollVectorPoint:vecPt phase:kIOHIDEventPhaseUndefined momentumPhase:ph locaction:loc];
        
        [NSThread sleepForTimeInterval:tick];
        CFTimeInterval ts = CACurrentMediaTime();
        CFTimeInterval timeDelta = ts - prevTs;
        prevTs = ts;
        
        vecPt = momentumScrollPointVectorWithPreviousVector(vecPt, dragCoeff, dragExp, timeDelta);
        vec = scrollVectorWithScrollPointVector(vecPt);
        magPt = magnitudeOfVector(vecPt);
        ph = kCGMomentumScrollPhaseContinue;
        
    }
    CGPoint loc = CGEventGetLocation(CGEventCreate(NULL));
    [GestureScrollSimulator postGestureScrollEventWithGestureVector:emptyVec
                                                       scrollVector:emptyVec
                                                  scrollVectorPoint:emptyVec
                                                              phase:kIOHIDEventPhaseUndefined
                                                      momentumPhase:kCGMomentumScrollPhaseEnd
                                                          locaction:loc];
    _momentumScrollIsActive = false;
    
}

static MFVector momentumScrollPointVectorWithPreviousVector(MFVector velocity, double dragCoeff, double dragExp, double timeDelta) {
    
    double a = magnitudeOfVector(velocity);
    double b = pow(a, dragExp);
    double dragMagnitude = b * dragCoeff;
    
    MFVector unitVec = normalizedVector(velocity);
    MFVector dragForce = scaledVector(unitVec, dragMagnitude);
    dragForce = scaledVector(dragForce, -1);
    
    MFVector velocityDelta = scaledVector(dragForce, timeDelta);
    
    MFVector newVelocity = addedVectors(velocity, velocityDelta);
    
    double dp = dotProduct(velocity, newVelocity);
    if (dp < 0) { // Vector has changed direction (crossed zero)
        newVelocity = (const MFVector){}; // Set to zero
    }
    return newVelocity;
}

typedef double (^VectorScalerFunction)(double);
static MFVector scaledVectorWithFunction(MFVector vec, VectorScalerFunction f) {
    double magIn = magnitudeOfVector(vec);
    if (magIn == 0) return (MFVector){0};  // To prevent division by 0 from producing nan
    double magOut = f(magIn);
    double scale = magOut / magIn;
    return scaledVector(vec, scale);
}
static MFVector scrollVectorWithScrollPointVector(MFVector vec) {
    VectorScalerFunction f = ^double(double x) {
        return 0.1 * (x-1); // Approximation from looking at real trackpad events
    };
    return scaledVectorWithFunction(vec, f);
}
static MFVector scrollPointVectorWithGestureVector(MFVector vec) {
    VectorScalerFunction f = ^double(double x) {
        //    double magOut = 0.01 * pow(magIn, 2) + 0.3 * magIn; // Got these values through curve fitting
        //    double magOut = 0.05 * pow(magIn, 2) + 0.8 * magIn; // These feel better for mouse
        return 0.08 * pow(x, 2) + 0.8 * x; // Even better feel - precise and fast at the same time
    };
    return scaledVectorWithFunction(vec, f);
}
static MFVector gestureVectorFromScrollPointVector(MFVector vec) {
    VectorScalerFunction f = ^double(double x) {
//        return 0.54 * x; // For input pixels to equal animation pixels
        return x;
    };
    return scaledVectorWithFunction(vec, f);
}

static MFVector initalMomentumScrollPointVectorWithGestureVector(MFVector vec) {
    MFVector vecScale = scaledVector(vec, 2.2); // This is probably not very accurate to real events, as I didn't test this at all.
    return scrollPointVectorWithGestureVector(vecScale);
}

// v Original delta conversion formulas which are the basis for the vector conversion functions above. These are relatively accurated to real events.

//static int scrollDeltaWithGestureDelta(int d) {
//    return floor(0.1 * (d-1));
//}
//static int scrollPointDeltaWithGestureDelta(int d) {
//    return round(0.01 * pow(d,2) + 0.3 * d);
//}

static double magnitudeOfVector(MFVector vec) {
    return sqrt(pow(vec.x, 2) + pow(vec.y, 2));
}
MFVector normalizedVector(MFVector vec) {
    return scaledVector(vec, 1.0/magnitudeOfVector(vec));
}
MFVector scaledVector(MFVector vec, double scalar) {
    MFVector outVec;
    outVec.x = vec.x * scalar;
    outVec.y = vec.y * scalar;
    return outVec;
}
MFVector addedVectors(MFVector vec1, MFVector vec2) {
    MFVector outVec;
    outVec.x = vec1.x + vec2.x;
    outVec.y = vec1.y + vec2.y;
    return outVec;
}
double dotProduct(MFVector vec1, MFVector vec2) {
    return vec1.x * vec2.x + vec1.y * vec2.y;
}

@end
