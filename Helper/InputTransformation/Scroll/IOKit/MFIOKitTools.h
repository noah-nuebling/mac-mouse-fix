//
// --------------------------------------------------------------------------
// MFIOKitTools.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
@import CoreGraphics.CGEventTypes;
#import "HIDEvent.h"

NS_ASSUME_NONNULL_BEGIN

@interface MFIOKitTools : NSObject

/// Defining our own HIDEvent -> CGEvent function, because we can't find one;

CGEventRef _Nullable MFCGEventCreateWithIOHIDEvent(HIDEvent *);

/// v Attempts to find a HIDEvent -> CGEvent function

//IOHIDEventFromCGEvent()

/// Trying to find a function that converts HIDEvent -> CGEvent
///     (__bridge doesn't work)
///     Cast to NSEvent doesn't work

//SLEventSetIOHIDEvent();
//CGEventSetIOHIDEvent();
//CGSEventSetIOHIDEvent();
//SLEventSetHIDEvent();
//CGEventSetHIDEvent();
//CGSEventSetHIDEvent();

//CGEventCreateWithIOHIDEvent();
//CGEventCreateHIDEvent();
//CGEventCreateIOHIDEvent();

//SLEventCreateFromIOHIDEvent();
//SLEventCreateFromHIDEvent();
//CGEventCreateFromIOHIDEvent();
//CGEventCreateFromHIDEvent();
//CGSEventCreateFromIOHIDEvent();
//CGSEventCreateFromHIDEvent();

//CGEventFromIOHIDEvent();

//IOHIDEventCopyCGEvent();
//IOHIDEventCreateCGEvent();

@end

NS_ASSUME_NONNULL_END
