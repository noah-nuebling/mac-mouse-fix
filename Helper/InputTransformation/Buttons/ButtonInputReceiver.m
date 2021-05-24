//
// --------------------------------------------------------------------------
// ButtonInputReceiver.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "ButtonInputReceiver.h"
#import "DeviceManager.h"
#import <IOKit/hid/IOHIDManager.h>
#import "ButtonTriggerGenerator.h"
#import "MFQueue.h"
#import "SharedUtility.h"
#import "Utility_Transformation.h"


@implementation ButtonInputReceiver

static CGEventSourceRef _eventSource;
static CFMachPortRef _eventTap;


+ (void)load_Manual {
    _eventSource = CGEventSourceCreate(kCGEventSourceStatePrivate);
    registerInputCallback();
    _buttonInputsFromRelevantDevices = [MFQueue queue];
    _buttonParseBlacklist = @[@(1),@(2)]; // Ignore inputs from left and right mouse buttons
}

+ (void)decide {
    if ([DeviceManager devicesAreAttached]) {
        NSLog(@"started ButtonInputReceiver");
        [ButtonInputReceiver start];
    } else {
        NSLog(@"stopped ButtonInputReceiver");
        [ButtonInputReceiver stop];
    }
}

+ (void)start {
    _buttonInputsFromRelevantDevices = [MFQueue queue]; // Not sure if resetting here necessary
    CGEventTapEnable(_eventTap, true);
}
+ (void)stop {
    CGEventTapEnable(_eventTap, false);
}

static void registerInputCallback() {
    // Register event Tap Callback
    CGEventMask mask =
    CGEventMaskBit(kCGEventOtherMouseDown) | CGEventMaskBit(kCGEventOtherMouseUp)
    | CGEventMaskBit(kCGEventLeftMouseDown) | CGEventMaskBit(kCGEventLeftMouseUp)
    | CGEventMaskBit(kCGEventRightMouseDown) | CGEventMaskBit(kCGEventRightMouseUp);

    _eventTap = CGEventTapCreate(kCGHIDEventTap, kCGHeadInsertEventTap, kCGEventTapOptionDefault, mask, handleInput, NULL);
    CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, _eventTap, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopDefaultMode);
    
    CFRelease(runLoopSource);
}

+ (void)insertFakeEventWithButton:(MFMouseButtonNumber)button isMouseDown:(BOOL)isMouseDown {
    
    NSLog(@"Inserting event");
    
    // Create event
    CGEventType mouseEventType = [SharedUtility CGEventTypeForButtonNumber:button isMouseDown:isMouseDown];
    CGPoint mouseLoc = Utility_Transformation.CGMouseLocationWithoutEvent;
    CGEventRef fakeEvent = CGEventCreateMouseEvent(NULL, mouseEventType, mouseLoc, [SharedUtility CGMouseButtonFromMFMouseButtonNumber:button]);    
    // Insert event
    CGEventRef ret = handleInput(0, CGEventGetType(fakeEvent), fakeEvent, nil);
    CFRelease(fakeEvent);
    if (ret) {
        CGEventPost(kCGSessionEventTap, ret);
    }
}

/// _buttonInputsFromRelevantDevices is a queue with one entry for each unhandled button input coming from a relevant device
/// Instances of MFDevice insert values into this queue  when they receive input from the IOHIDDevice which they own.
/// Input from the IOHIDDevice will always occur shortly before `ButtonInputReceiver_CG::handleIput()`. (Pretty sure)
/// This allows `ButtonInputReceiver_CG::handleIput()` to gain information about the nature of the incoming event, especially the device it stems from.
///     It also allows us to filter out input from devices which aren't relevant
///         (Because don't create an MFDevice instance for irrelevant devices, and so they can't insert their events into _buttonInputsFromRelevantDevices)
///         (All MFDevice instances for relevant devices can be found in DeviceManager.relevantDevices).
static MFQueue<NSDictionary *> *_buttonInputsFromRelevantDevices;
/// @param stemsFromSeize
/// When an IOHIDDevice device is seized, the system will automatically send fake mouse up CG events for each of its pressed buttons.
/// So when seizing, MFDevice objects will call this function once for each pressed button, with the stemsFromSeize parameter set to YES.
/// This way `handleInput()` knows whats up when these fake mouse up events occur.
+ (void)handleHIDButtonInputFromRelevantDeviceOccured:(MFDevice *)dev button:(NSNumber *)btn stemsFromDeviceSeize:(BOOL)stemsFromSeize {
    if ([_buttonParseBlacklist containsObject:btn] && !stemsFromSeize) return;
    if (!CGEventTapIsEnabled(_eventTap)) return;
    
    [_buttonInputsFromRelevantDevices enqueue: @{
        @"dev": dev,
        @"stemsFromSeize": @(stemsFromSeize),
    }];
}
+ (BOOL)allRelevantButtonInputsHaveBeenProcessed {
    return [_buttonInputsFromRelevantDevices isEmpty];
}
NSArray *_buttonParseBlacklist; // Don't send inputs from these buttons to ButtonInputParser

CGEventRef handleInput(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo) {
    
#if DEBUG
    @try {
        NSLog(@"Received CG Button Input - %@", [NSEvent eventWithCGEvent:event]);
        // ^ This crashes sometimes.
        //  I usually see it crash with the message "Invalid parameter not satisfying: _type > 0 && _type <= kCGSLastEventType", so I it seems there are some events with weird types being passed to this function, I don't know why that would happen though, because it should only receive normal mouse down and mouse up events.
        // I used to speculate that it's connected to attaching / deatching devices, but I don't remember why.
        // I feel like it might be connected to inserting events but I'm not sure why
        // I saw this error in some log messages which people sent me. I feel like it might be interfering with logging other important stuff because maybe the eventTap will break or the program will crash when this error occurs. Not sure thought. See the logs in GH Issue #103, for an example. They contain the error and I think that might have prevented logging of device re-attachment.
        // TODO: Investigate when and why exactly this crashes (when you have time)
    } @catch (NSException *exception) {
        NSLog(@"Received CG Button Input which can't be printed normally - Exception while printing: %@", exception);
    }
#endif
    
    if ([_buttonInputsFromRelevantDevices isEmpty]) return event;
    
    NSDictionary *lastInputFromRelevantDevice = [_buttonInputsFromRelevantDevices dequeue];
    
    if (((NSNumber *)lastInputFromRelevantDevice[@"stemsFromSeize"]).boolValue) {
        return nil;
    }
    
    NSUInteger buttonNumber = CGEventGetIntegerValueField(event, kCGMouseEventButtonNumber) + 1;
    
    if ([_buttonParseBlacklist containsObject:@(buttonNumber)]) return event;
    
    MFDevice *dev = lastInputFromRelevantDevice[@"dev"];
    
    long long pr = CGEventGetIntegerValueField(event, kCGMouseEventPressure);
    MFButtonInputType triggertType = pr == 0 ? kMFButtonInputTypeButtonUp : kMFButtonInputTypeButtonDown;
        
    MFEventPassThroughEvaluation eval = [ButtonTriggerGenerator parseInputWithButton:@(buttonNumber) triggerType:triggertType inputDevice:dev];
    
    if (eval == kMFEventPassThroughRefusal) {
        return nil;
    }
    
#if DEBUG
    NSLog(@"... letting event pass through");
#endif
    
    return event;

}

@end
