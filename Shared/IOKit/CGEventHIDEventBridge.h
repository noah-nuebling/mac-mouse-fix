//
// --------------------------------------------------------------------------
// CGEventHIDEventBridge.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
@import CoreGraphics.CGEventTypes;
#import "HIDEvent.h"
@import Cocoa;

NS_ASSUME_NONNULL_BEGIN

@interface CGEventHIDEventBridge : NSObject

/// How we came up with this:
///     We know there are many useful functions for interacting with the 'Window Server' in the private 'SkyLight' framework. (Formerly Core Graphics Services afaik). Some of these private functions have been discovered and documented in the CGSInternal repo (https://github.com/NUIKit/CGSInternal/). We've been using some of these for a long time for example to trigger 'SymbolicHotKeys' which lets us trigger many system functions like 'Look Up' and 'Mission Control'.
///     It is difficult to discover new functions since BigSur made it almost impossible to reverse engineer System Frameworks like SkyLight. But there is still a '.tbd' file for the Skylight framework which lists its function names. More on this here: https://github.com/NUIKit/CGSInternal/issues/2
///
///     However in this .tbd file we found the functions `_SLEventSetIOHIDEvent` and `_SLEventCopyIOHIDEvent`. `SL` types are usually just a different name for `CG` types, so we thought that we might be able to bridge between CGEvent and 'IOHIDEvent' using these functions. This is really promising, because CGEvent is opaque. It's not documented what the 'valueFields' mean. Whereas many 'IOHID' types are documented in the open source IOKit source code, so we would know what the data they contain means!
///
///     So we tried to link the symbol SLEventCopyIOHIDEvent. It didn't work for some reason. But CGEventCopyIOHIDEvent did! Then we called the function and stepped into the assembly code (hold control and click the step button in Xcode) to see what it does.
///     After we read up on some ARM assembly we could figure out what it does and infer what the arguments and return must be.
///
///     We saw that he function returns an NSObject of type 'HIDEvent'. Then we used VSCode to search Apples open source projects IOHIDFamily-1633.100.36, IOKitUser-1845.100.19, and xnu-7195.101.1 for the headers declaring 'HIDEvent' and their dependencies and added the to the project until everything compiled.
///
///     We then tried to find _SLEventSetIOHIDEvent, but we couldn't manage to. However, we could build our own equivalent function based on reversing the process seen in the assembly of CGEventCopyIOHIDEvent and shifting around pointers between memory addresses.
///
/// Old Notes from TouchSimulator.m: (These observations led us to this)
///     I just saw in Instruments that when CFRelease is called on the scrollEvents we capture in Scroll.m, then the following function are called:
///         `CGSEventReclaimObjects()`, which then calls `[HIDEvent dealloc]`
///         This Suggests that CGEvent is an interface / wrapper / different name for for CGSEvent, and CGSEvent is an interface / wrapper for HIDEvent. Kernel drivers send IOHIDEvent IIRC, so possible HIDEvent is an interface / wrapper for IOHIDEvent.
///
///     In the private Skylight framework there are the functions: _SLEventSetIOHIDEvent and _SLEventCopyIOHIDEvent.
///         SLEvent is a differnent name for CGSEvent as far as I understand.
///         Maybe we can use these functions to create CGEvents from IOHIDEvents.
///         This would be great because IOHIDEvents are not opaque. All their fields are documented.
///         See: https://github.com/NUIKit/CGSInternal/issues/2 for more info.
///         -> This is not really necessary because we can already simulate all the important events (except force touch) by just setting fields on CGEvent.
///         See https://opensource.apple.com/source/IOHIDFamily/IOHIDFamily-1633.100.36/IOHIDFamily/IOHIDEventTypes.h.auto.html
///         Another reason to use IOHIDEvent:
///             `typedef uint64_t IOHIDEventSenderID` - Registry entry id in the IOHIDEvent!!

/// MARK: HIDEvent <-> CGEvent

HIDEvent *CGEventGetHIDEvent(CGEventRef _Nonnull);
void CGEventSetHIDEvent(CGEventRef _Nonnull, HIDEvent * _Nonnull);

/// MARK: v Attempts to find a HIDEvent -> CGEvent function

/// Unsuccessful, we ended up writing our own function.
/// Actually in `SkyLight.tbd` there is `_SLEventSetIOHIDEvent`, but I can't find a definition that works

/// Trying to find a function that converts HIDEvent -> CGEvent
///     (__bridge doesn't work)
///     (Cast to NSEvent doesn't work)

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
