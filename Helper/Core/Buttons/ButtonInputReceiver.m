//
// --------------------------------------------------------------------------
// ButtonInputReceiver.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

#import "ButtonInputReceiver.h"
#import "DeviceManager.h"
#import <IOKit/hid/IOHIDManager.h>
#import "ButtonTriggerGenerator.h"
#import "Queue.h"
#import "SharedUtility.h"
#import "TransformationUtility.h"
#import "HelperUtility.h"
#import "GestureScrollSimulator.h"
#import "Mac_Mouse_Fix_Helper-Swift.h"


@implementation ButtonInputReceiver

static CGEventSourceRef _eventSource;
static CFMachPortRef _eventTap;

+ (void)load_Manual {
    _eventSource = CGEventSourceCreate(kCGEventSourceStatePrivate);
    registerInputCallback();
    _buttonInputsFromRelevantDevices = [Queue queue];
    _buttonParseBlacklist = @[@(1),@(2)]; /// Ignore inputs from left and right mouse buttons
}

+ (void)decide {
    if ([DeviceManager devicesAreAttached]) {
        DDLogInfo(@"started ButtonInputReceiver");
        [ButtonInputReceiver start];
    } else {
        DDLogInfo(@"stopped ButtonInputReceiver");
        [ButtonInputReceiver stop];
    }
}

+ (void)start {
    _buttonInputsFromRelevantDevices = [Queue queue]; /// Not sure if resetting here necessary
    CGEventTapEnable(_eventTap, true);
}
+ (void)stop {
    CGEventTapEnable(_eventTap, false);
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

//+ (void)insertFakeEventWithButton:(MFMouseButtonNumber)button isMouseDown:(BOOL)isMouseDown {
//    
//    DDLogInfo(@"Inserting event");
//    
//    /// Create event
//    CGEventType mouseEventType = [SharedUtility CGEventTypeForButtonNumber:button isMouseDown:isMouseDown];
//    CGPoint mouseLoc = getPointerLocation();
//    CGEventRef fakeEvent = CGEventCreateMouseEvent(NULL, mouseEventType, mouseLoc, [SharedUtility CGMouseButtonFromMFMouseButtonNumber:button]);    
//    /// Insert event
//    CGEventRef ret = eventTapCallback(0, CGEventGetType(fakeEvent), fakeEvent, nil);
//    CFRelease(fakeEvent);
//    if (ret) {
//        CGEventPost(kCGSessionEventTap, ret);
//    }
//}

/// `_buttonInputsFromRelevantDevices` is a queue with one entry for each unhandled button input coming from a relevant device
/// Instances of Device insert values into this queue  when they receive input from the IOHIDDevice which they own.
/// Input from the IOHIDDevice will always occur shortly before `ButtonInputReceiver->eventTapCallback()`. (Pretty sure)
/// This allows `ButtonInputReceiver->eventTapCallback()` to gain information about the nature of the incoming event, especially the device it stems from.
///     It also allows us to filter out input from devices which aren't relevant
///         (Because we don't create an Device instance for irrelevant devices, and so they can't insert their events into `_buttonInputsFromRelevantDevices`)
///         (All Device instances for relevant devices can be found in DeviceManager.attachedDevices).
static Queue<NSDictionary *> *_buttonInputsFromRelevantDevices;

+ (void)handleHIDButtonInputFromRelevantDeviceOccured:(Device *)dev button:(NSNumber *)btn {
    if ([_buttonParseBlacklist containsObject:btn]) return;
    if (!CGEventTapIsEnabled(_eventTap)) return;
    
    [_buttonInputsFromRelevantDevices enqueue: @{
        @"dev": dev, /// TODO: Now that this has only 1 value – make it not a dict
    }];
}
+ (BOOL)allRelevantButtonInputsHaveBeenProcessed {
    return [_buttonInputsFromRelevantDevices isEmpty];
}

NSArray *_buttonParseBlacklist; /// Don't send inputs from these buttons to ButtonInputParser

static CGEventRef eventTapCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo) {
    
    /// Re-enable on timeout
    /// Maybe it would be better to do the heavy lifting on a background queue, so this never times out, but this is easier, and it times out quite rarely anyways so this should be fine.
    if (type == kCGEventTapDisabledByTimeout) {
        DDLogInfo(@"ButtonInputReceiver eventTap timed out. Re-enabling.");
        CGEventTapEnable(_eventTap, true);
    } else if (type == kCGEventTapDisabledByUserInput) {
        DDLogInfo(@"ButtonInputReceiver eventTap was disabled by user input");
    }
    
    /// Debug
    
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
    
    ///
    /// Main logic
    ///
    
    /// Get info from cgEvent
    NSUInteger buttonNumber = CGEventGetIntegerValueField(event, kCGMouseEventButtonNumber) + 1;
    BOOL mouseDown = CGEventGetIntegerValueField(event, kCGMouseEventPressure) != 0;
    
    /// Filter buttons
    if ([_buttonParseBlacklist containsObject:@(buttonNumber)]) return event;
    
    ///
    /// Get device
    ///     & filter input from irrelevant devices
    ///     TODO: If new method works. Remove old method - including the callbacks in Device.m and the input queue and stuff.
    
    /// New method
    ///  - Using reverse engineered knowledge about CGEventFields to get the sender directly from the CGEvent
    ///  - Tested this method under 10.13, 10.14, 10.15 Beta, 13.0, - it works!
    ///  - Performance: Under newMethod, spamming a button in release build with debugger attached had up to 1.6% CPU usage in Activitry Monitor. OldMethod had up to 1.9%, but it went up and down a lot more.
    
    IOHIDDeviceRef iohidDevice = CGEventGetSendingDevice(event);
    Device *device = [DeviceManager attachedDeviceWithIOHIDDevice:iohidDevice];
    
    DDLogDebug(@"Device for CG Button Input - iohidDevice: %@, device: %@", iohidDevice, device);
    
    if (device == nil) return event;
    
    /// Old method
    /// - How does old method work? - For the old method, we registered input callbacks on the HIDDevices and put those low level inputs in with co-occuring CGEvents to find which device sent a CGEvent
    /// - Why switch away from old method? - Under Ventura I think the HID callback API broke for some devices. See https://github.com/noah-nuebling/mac-mouse-fix/issues/424. I remember similar bugs in the API in older macOS versions a few years back.
    
//    if ([_buttonInputsFromRelevantDevices isEmpty]) return event;
//    NSDictionary *lastInputFromRelevantDevice = [_buttonInputsFromRelevantDevices dequeue];
//    Device *dev = lastInputFromRelevantDevice[@"dev"];
    
    /// Pass to buttonInput processor
    MFEventPassThroughEvaluation eval = [Buttons handleInputWithDevice:device button:@(buttonNumber) downNotUp:mouseDown event: event];
    /// Let events pass through
    if (eval == kMFEventPassThroughRefusal) {
        return nil;
    } else {
        DDLogDebug(@"... letting event pass through");
        return event;
    }

}

@end
