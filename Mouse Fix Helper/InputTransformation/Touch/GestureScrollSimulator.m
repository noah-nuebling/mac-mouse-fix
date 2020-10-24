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

@implementation GestureScrollSimulator

static MFVector _lastInputGestureVector = { .x = 0, .y = 0 };

/**
 Post scroll events that behave as if they are coming from an Apple Trackpad or Magic Mouse.
 This function is a wrapper for `postGestureScrollEventWithGestureVector:scrollVector:scrollVectorPoint:phase:momentumPhase:`

 Scrolling will continue automatically but get slower over time after the function has been called with phase kIOHIDEventPhaseEnded.
 
    - The initial speed of this "momentum phase" is based on the delta values of last time that this function is called with at least one non-zero delta and with phase kIOHIDEventPhaseBegan or kIOHIDEventPhaseChanged before it is called with phase kIOHIDEventPhaseEnded.
 
    - The reason behind this is that this is how real trackpad input seems to work. Some apps like Xcode will automatically keep scrolling if no events are sent after the event with phase kIOHIDEventPhaseEnded. And others, like Safari will not. This function wil automatically keep sending events after it has been called with kIOHIDEventPhaseEnded in order to make all apps react as consistently as possible.
 
 \note In order to minimize momentum scrolling,  send an event with a very small but non-zero scroll delta before calling the function with phase kIOHIDEventPhaseEnded.
 \note For more info on which delta values and which phases to use, see the documentation for `postGestureScrollEventWithGestureDeltaX:deltaY:phase:momentumPhase:scrollDeltaConversionFunction:scrollPointDeltaConversionFunction:`. In contrast to the aforementioned function, you shouldn't need to call this function with kIOHIDEventPhaseUndefined.
*/
+ (void)postGestureScrollEventWithGestureDeltaX:(int64_t)dx deltaY:(int64_t)dy phase:(IOHIDEventPhaseBits)phase {

    if (phase != kIOHIDEventPhaseEnded) {
        
        _breakMomentumScrollFlag = true;
        
        if (phase == kIOHIDEventPhaseChanged && dx == 0 && dy == 0) {
            return;
        }
        
        MFVector vecGesture = { .x = dx, .y = dy };
        MFVector vecScrollPoint = scrollPointVectorWithGestureVector(vecGesture);
        MFVector vecScroll = scrollVectorWithScrollPointVector(vecScrollPoint);
        
        if (phase == kIOHIDEventPhaseBegan || phase == kIOHIDEventPhaseChanged) {
            _lastInputGestureVector = vecGesture;
        }
        [self postGestureScrollEventWithGestureVector:vecGesture
                                         scrollVector:vecScroll
                                    scrollVectorPoint:vecScrollPoint
                                                phase:phase
                                        momentumPhase:kCGMomentumScrollPhaseNone];
    } else {
                    NSLog(@"Last gesture vec: %f %f", _lastInputGestureVector.x, _lastInputGestureVector.y);
        [self postGestureScrollEventWithGestureVector:(MFVector){}
                                         scrollVector:(MFVector){}
                                    scrollVectorPoint:(MFVector){}
                                                phase:kIOHIDEventPhaseEnded
                                        momentumPhase:0];
        
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
//            startPostingMomentumScrollEventsWithInitialGestureVector(_lastInputGestureVector, 0.016, 1.0, 4, 1.0);
            startPostingMomentumScrollEventsWithInitialGestureVector(_lastInputGestureVector, 0.016, 1.0, 4, 1.0);
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
                                  momentumPhase:(CGMomentumScrollPhase)momentumPhase {
    
    
//    printf("Posting gesture scroll event with delta values:\n");
//    printf("gesture: x:%f y:%f \nscroll: x:%f y:%f \nscrollPt: x:%f y:%f\n",
//          vecGesture.x, vecGesture.y, vecScroll.x, vecScroll.y, vecScrollPoint.x, vecScrollPoint.y);
    
    int valFor41 = 33231; // Not sure if this does anything
    
    //
    // Create type 22 event
    //
    
    CGEventRef e22 = CGEventCreate(NULL);
    
    // Set static fields
    
    CGEventSetDoubleValueField(e22, 41, valFor41);
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
    
    // Field 142
    
    int32_t weird96copyOrigin = (int32_t)vecScrollPoint.x;
    Float32 weird96copy;
    memcpy(&weird96copy, &weird96copyOrigin, sizeof(weird96copyOrigin));
    CGEventSetDoubleValueField(e22, 142, (double)weird96copy); // ??This doesn't work
    CGEventSetIntegerValueField(e22, 142, (double)weird96copy);
    
    if (momentumPhase == 0) {
        
        //
        // Create type 29 subtype 6 event
        //
        
        CGEventRef e29 = CGEventCreate(NULL);
        
        // Set static fields
        
        CGEventSetDoubleValueField(e29, 41, valFor41);
        CGEventSetDoubleValueField(e29, 55, 29); // 29 -> NSEventTypeGesture // Setting field 55 is the same as using CGEventSetType()
        CGEventSetDoubleValueField(e29, 110, 6); // Field 110 -> subtype // 6 -> kIOHIDEventTypeScroll
        
        // Set dynamic fields
        
        double val113 = (double)vecGesture.x;
        if (val113 == 0) {
            val113 = -0.0f; // The original events only contain -0 but this probs doesn't make a difference.
        }
        CGEventSetDoubleValueField(e29, 113, val113);
        
        double val119 = (double)vecGesture.y;
        if (val119 == 0) {
            val119 = -0.0f; // The original events only contain -0 but this probs doesn't make a difference.
        }
        CGEventSetDoubleValueField(e29, 119, val119);
        
        CGEventSetIntegerValueField(e29, 132, phase);
        
        // Post t29s0 events
//        CGEventSetLocation(e29, [Utility_HelperApp getCurrentPointerLocation_flipped]);
        CGEventPost(kCGHIDEventTap, e29);
        //    printEvent(e29);
        CFRelease(e29);
    }
    
    // Post t22s6 events
//    CGEventSetLocation(e22, [Utility_HelperApp getCurrentPointerLocation_flipped]);
    CGEventPost(kCGHIDEventTap, e22);
    CFRelease(e22);
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
        if (_breakMomentumScrollFlag == true) break;
        [GestureScrollSimulator postGestureScrollEventWithGestureVector:emptyVec
                                         scrollVector:vec
                                    scrollVectorPoint:vecPt
                                                phase:kIOHIDEventPhaseUndefined
                                        momentumPhase:ph];
        
        [NSThread sleepForTimeInterval:tick];
        CFTimeInterval ts = CACurrentMediaTime();
        CFTimeInterval timeDelta = ts - prevTs;
        prevTs = ts;
        
        vecPt = momentumScrollPointVectorWithPreviousVector(vecPt, dragCoeff, dragExp, timeDelta);
        vec = scrollVectorWithScrollPointVector(vecPt);
        magPt = magnitudeOfVector(vecPt);
        ph = kCGMomentumScrollPhaseContinue;
        
    }
    
    [GestureScrollSimulator postGestureScrollEventWithGestureVector:emptyVec
                                                       scrollVector:emptyVec
                                                  scrollVectorPoint:emptyVec
                                                              phase:kIOHIDEventPhaseUndefined
                                                      momentumPhase:kCGMomentumScrollPhaseEnd];
    _momentumScrollIsActive = false;
    
}

static MFVector momentumScrollPointVectorWithPreviousVector(MFVector velocity, double dragCoeff, double dragExp, double timeDelta) {
    
    dragExp = 0.8; dragCoeff = 8; // Easier to scroll far, kinda nice on a mouse, end still pretty realistic // Got these values by just seeing what feels good
    
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
static MFVector scrollVectorWithScrollPointVector(MFVector vec) {
    double magIn = magnitudeOfVector(vec);
    if (magIn == 0) { // To prevent division by 0 from producing nan
        return (MFVector){};
    }
    double magOut = 0.1 * (magIn-1); // Approximation from looking at real trackpad events
    double scale = magOut / magIn;
    MFVector vecOut;
    vecOut.x = [SharedUtility signOf:vec.x] * floor(fabs(vec.x * scale));
    vecOut.y = [SharedUtility signOf:vec.y] * floor(fabs(vec.y * scale));
    return vecOut;
}
static MFVector scrollPointVectorWithGestureVector(MFVector vec) {
    double magIn = magnitudeOfVector(vec);
    if (magIn == 0) { // To prevent division by 0 from producing nan
        return (MFVector){};
    }
    double magOut = 0.01 * pow(magIn, 2) + 0.3 * magIn; // Got these values through curve fitting
    magOut *= 2; // This makes it feel better on mouse
    double scale = magOut / magIn;
    MFVector vecOut;
    vecOut.x = round(vec.x * scale);
    vecOut.y = round(vec.y * scale);
    return vecOut;
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
