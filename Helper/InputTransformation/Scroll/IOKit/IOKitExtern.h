//
// --------------------------------------------------------------------------
// HIDEvent_Imports.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

#ifndef HIDEvent_Imports_h
#define HIDEvent_Imports_h

#import "HIDEvent.h"
#import "HIDEvent+HIDEventFields.h"
#import "HIDEventAccessors.h"
#import "HIDEventAccessors_Private.h"

#import <IOKit/hid/IOHIDKeys.h>
//#import "IOHIDEventTypes.h"

@import Cocoa;

/// Convert CGEvent -> IOHIDEvent

HIDEvent *CGEventCopyIOHIDEvent(CGEventRef);

/// Defining our own HIDEvent -> CGEvent function, because we can't find one;

//CGEventRef IOHIDEventCreateCGEvent(HIDEvent *);

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

#endif /* HIDEvent_Imports_h */
