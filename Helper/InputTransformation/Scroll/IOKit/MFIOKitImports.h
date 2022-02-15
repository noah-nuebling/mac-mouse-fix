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
#import "MFIOKitTools.h"

@import Cocoa;

HIDEvent *CGEventCopyIOHIDEvent(CGEventRef);

#endif /* HIDEvent_Imports_h */
