//
// --------------------------------------------------------------------------
// ButtonInputReceiver.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "ButtonInputReceiver.h"
#import "DeviceManager.h"
#import <IOKit/hid/IOHIDManager.h>
#import "ButtonTriggerGenerator.h"
#import "Queue.h"
#import "SharedUtility.h"
#import "ModificationUtility.h"
#import "HelperUtility.h"
#import "GestureScrollSimulator.h"
#import "Mac_Mouse_Fix_Helper-Swift.h"

@implementation ButtonInputReceiver

///
/// On getting the sending device:
/// - There is an "old Method" and a "new Method"
/// - How does old method work? - For the old method, we registered input callbacks on the HIDDevices and put those low level inputs in with co-occuring CGEvents to find which device sent a CGEvent
/// - Why switch away from old method? - Under Ventura I think the HID callback API broke for some devices. See https://github.com/noah-nuebling/mac-mouse-fix/issues/424. I remember similar bugs in the API in older macOS versions a few years back.
/// - Some time after moving to the newMethod I deleted the old method. You can still find it in ButtonInputReceiver_old.m and in the the MMF 1 and MMF 2 source. We might have moved away from it under MMF 2 as well to fix Ventura problems, not sure. 

static CFMachPortRef _eventTap;

+ (void)load_Manual {
    registerInputCallback();
    _buttonParseBlacklist = @[@(1),@(2)]; /// Ignore inputs from left and right mouse buttons
}

+ (void)start {
    CGEventTapEnable(_eventTap, true);
}
+ (void)stop {
    CGEventTapEnable(_eventTap, false);
}
+ (BOOL)isRunning {
    /// Only used for debug inspection at the time of writing. Shouldn't need it for anything else.
    return CGEventTapIsEnabled(_eventTap);
}

static void registerInputCallback() {
    
    ///
    /// Register event Tap Callback
    ///
    
    /// Declare events of interest
    /// I think we need to also listen to lmb and rmb here (even though we don't use them for remapping) to keep some stuff in sync with the HID callbacks / `_buttonInputsFromRelevantDevices`. Not sure though. Maybe that was just when we did the event Einschleusung for the old device seizing stuff.
    ///     Edit: will just see what happens when we turn it off.
    
    CGEventMask mask =
    CGEventMaskBit(kCGEventOtherMouseDown) | CGEventMaskBit(kCGEventOtherMouseUp);
//    | CGEventMaskBit(kCGEventLeftMouseDown) | CGEventMaskBit(kCGEventLeftMouseUp)
//    | CGEventMaskBit(kCGEventRightMouseDown) | CGEventMaskBit(kCGEventRightMouseUp);

    /// Create tap
    _eventTap = CGEventTapCreate(kCGHIDEventTap, kCGHeadInsertEventTap, kCGEventTapOptionDefault, mask, eventTapCallback, NULL);
    
    /// Get source
    CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, _eventTap, 0);
    
    /// Add to runLoop
    ///     Running on `GlobalEventTapThread`. Used to run on main. We made this change as a hotfix to the StatusBarItem only reacting to mouseHover if you click and then move mouse outside of the menu and then back in.
    ///     This might have unforseen consequences. E.g. the stuff we call from the tap must dispatch to mainThread at some points, so this changes the threading model, and might introduce raceConditions
    ///     Edit: Yes this is causing race conditions. The click and drag gestures get stuck all the time now. Alternative solution: Run on main thread and just don't capture MB1.

    CFRunLoopAddSource(/* GlobalEventTapThread.runLoop */ CFRunLoopGetMain(), runLoopSource, kCFRunLoopDefaultMode);
    
    CFRelease(runLoopSource);
}

NSArray *_buttonParseBlacklist; /// Don't send inputs from these buttons to ButtonInputParser

static CGEventRef eventTapCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo) {
    
    /// Re-enable on timeout
    /// Maybe it would be better to do the heavy lifting on a background queue, so this never times out, but this is easier, and it times out quite rarely anyways so this should be fine.
   
    if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) {
        
        DDLogDebug(@"ButtonInputReceiver eventTap was disabled by %@", type == kCGEventTapDisabledByTimeout ? @"timeout. Re-enabling." : @"user input.");
        
        if (type == kCGEventTapDisabledByTimeout) {
            CGEventTapEnable(_eventTap, true);
        }
        return event;
    }
    
    /// Debug
    
    if (runningPreRelease()) {
        @try {
            NSUInteger buttonNumber = CGEventGetIntegerValueField(event, kCGMouseEventButtonNumber) + 1;
            if (buttonNumber != 1 && buttonNumber != 2) { /// Don't print left and right click cause that'll clog the logs
                
                DDLogDebug(@"Received CG Button Input - %@", [NSEvent eventWithCGEvent:event]);
                /// ^ This crashes sometimes.
                /// I think it's because the timeout events can't be translated to NSEvent
                ///  I usually see it crash with the message "Invalid parameter not satisfying: _type > 0 && _type <= kCGSLastEventType", so I it seems there are some events with weird types being passed to this function, I don't know why that would happen though, because it should only receive normal mouse down and mouse up events.
                /// I used to speculate that it's connected to attaching / deatching devices, but I don't remember why.
                /// I feel like it might be connected to inserting events but I'm not sure why
                /// I saw this error in some log messages which people sent me. I feel like it might be interfering with logging other important stuff because maybe the eventTap will break or the program will crash when this error occurs. Not sure thought. See the logs in GH Issue #103, for an example. They contain the error and I think that might have prevented logging of device re-attachment.
                /// TODO: Investigate when and why exactly this crashes (when you have time)
            }
        } @catch (NSException *exception) {
            DDLogDebug(@"Received CG Button Input which can't be printed normally - Exception while printing: %@", exception);
        }
    }
    
    ///
    /// Testing HelperState.swift
    ///
    /// Measurement results (from when we were optimizing HelperState.swift):
    /// - 1. Measurement: ca 1ms after moving pointer (sometimes up to 2ms). ca. 0.01 ms when keeping pointer still.
    /// - 2. Measurement: We moved getPIDUnderMousePointer from Swift to C: Still 1ms after moving pointer but with somewhat frequent dips to 3ms or even 5ms. Swift seems to be faster!
    /// - 3. Measurement: We did some more optimizations and measurements. Everything I could think of. The slowest part is mostly getPIDUnderMousePointer() I think. We got the speed up to be pretty consistently under 1 ms. Relatively rarely it goes to like 4ms. Once I saw it go to 7ms. Not sure what causes those random-seeming dips in performance. But it's rare enough that I think performance is good enough for now.
    
    BOOL enableHelperStateSwiftTests = NO;
    
    if (enableHelperStateSwiftTests && CGEventGetIntegerValueField(event, kCGMouseEventPressure) != 0) {
        
        /// Measure performance
        CFTimeInterval startTS = CACurrentMediaTime();
        
        /// Get configOverrideConditions
        [HelperState.shared updateBaseValuesWithEvent:event];
        NSDictionary *configOverrideConditions = [HelperState.shared configOverrideConditions];
        
        /// Measure performance
        CFTimeInterval endTS = CACurrentMediaTime();
        NSLog(@"HelperState - derived new configOverrideConditions in %f ms: %@", (endTS - startTS)*1000, configOverrideConditions);
    }
    
    ///
    /// Main logic
    ///
    
    /// Get info from cgEvent
    NSUInteger buttonNumber = CGEventGetIntegerValueField(event, kCGMouseEventButtonNumber) + 1;
    BOOL mouseDown = CGEventGetIntegerValueField(event, kCGMouseEventPressure) != 0;
    
    /// Filter buttons
    if ([_buttonParseBlacklist containsObject:@(buttonNumber)]) return event;
    
    /// Debug
    DDLogDebug(@"Input Receiver - Received event: %@", [NSEvent eventWithCGEvent:event].description);
    
    ///
    /// Get device
    ///     & filter input from irrelevant devices
    ///     TODO: If new method works. Remove old method - including the callbacks in Device.m and the input queue and stuff.
    
    /// New method for getting device
    ///  - Using reverse engineered knowledge about CGEventFields to get the sender directly from the CGEvent
    ///  - Tested this method under 10.13, 10.14, 10.15 Beta, 13.0, - it works!
    ///  - Performance: Under newMethod, spamming a button in release build with debugger attached had up to 1.6% CPU usage in Activitry Monitor. OldMethod had up to 1.9%, but it went up and down a lot more.
    
    IOHIDDeviceRef iohidDevice = CGEventGetSendingDevice(event);
    Device *device = iohidDevice == NULL ? nil : [DeviceManager attachedDeviceWithIOHIDDevice:iohidDevice];
    
    /// Filter out events from sources other than attached devices
    ///     Notes:
    ///     - Set the `NO_FILTER` preprocessor macro to disable filtering. This allows artificial events to be processed, which we plan to use so that playbacks of event recordings from our CGEventRecorder work.
    ///     - I'm not sure `NO_FILTER` should be a preprocessor macro? Maybe we should put it in Constants or config or something.
    ///     - We're leaving `NO_FILTER` on for now, because I can't really think of a good reason to filter, and maybe some people will benefit. E.g. I remember some dude with a hackintosh had a PS-2 mouse that was seemingly filtered out, and he'll be happy about this.
    ///
    
    if (iohidDevice == NULL || device == nil) {

#if NO_FILTER
        device = [Device strangeDevice];
#else
        if (iohidDevice == NULL) {
            DDLogDebug(@"Input Receiver - Couldn't determine sending device for event. It might have been artificially generated by another app. Letting the event pass through. Event description: %@", [NSEvent eventWithCGEvent:event]);
        } else if (device == nil) {
            DDLogDebug(@"Input Receiver - Sending device is not among attached devices. Letting the event pass through. Event description: %@", [NSEvent eventWithCGEvent:event]);
        }
        
        return event;
#endif
    }
    
    /// Log
    DDLogDebug(@"Input Receiver - Device for CG Button Input - iohidDevice: %@, device: %@", iohidDevice, device);
    
    /// Pass to buttonInput processor
    MFEventPassThroughEvaluation eval = [Buttons handleInputWithDevice:device button:@(buttonNumber) downNotUp:mouseDown event:event];
    
    /// Set the `RECORDING_MODE` flag when you want to record video demos, so that cleanshot can properly highlight when a button or keyboard key is pressed
    
#if RECORDING_MODE
    return event;
#endif
    
    /// Let events pass through
    if (eval == kMFEventPassThroughRefusal) {
        return nil;
    } else {
        DDLogDebug(@"... letting event pass through");
        return event;
    }

}

@end
