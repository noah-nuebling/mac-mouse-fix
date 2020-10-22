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
#import "ButtonInputParser.h"
#import "MFQueue.h"


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
    CGEventMask mask = CGEventMaskBit(kCGEventOtherMouseDown) | CGEventMaskBit(kCGEventOtherMouseUp); // Note that we're not registering from events from left mouse button and right mouse button

    _eventTap = CGEventTapCreate(kCGHIDEventTap, kCGTailAppendEventTap, kCGEventTapOptionDefault, mask, handleInput, NULL);
    CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, _eventTap, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopDefaultMode);
    
    CFRelease(runLoopSource);
}

+ (void)insertFakeEvent:(CGEventRef)event {
    
    NSLog(@"Inserting event");
    
    CGEventRef ret = handleInput(0,0,event,nil);
    if (ret) {
        CGEventPost(kCGSessionEventTap, ret);
    }
}

/// _buttonInputsFromRelevantDevices is a queue with one entry for each unhandled button input coming from a relevant device
/// Instances of MFDevice insert themselves into this queue  when they receive input from the IOHIDDevice which they own.
/// Input from the IOHIDDevice will always occur shortly before `ButtonInputReceiver_CG::handleIput()`. (Pretty sure)
/// This allows `ButtonInputReceiver_CG::handleIput()` to gain information about the device causing the incoming event.
///     It also allows us to filter out input from devices which aren't relevant
///         (Because don't create an MFDevice instance for irrelevant devices)
///         (All MFDevice instances for relevant devices can be found in DeviceManager.relevantDevices).
static MFQueue<MFDevice *> *_buttonInputsFromRelevantDevices;
+ (void)handleButtonInputFromRelevantDeviceOccured:(MFDevice *)dev button:(NSNumber *)btn {
    if ([_buttonParseBlacklist containsObject:btn] || !CGEventTapIsEnabled(_eventTap)) return;
    [_buttonInputsFromRelevantDevices enqueue: dev];
}
+ (BOOL)allRelevantButtonInputsHaveBeenProcessed {
    return [_buttonInputsFromRelevantDevices isEmpty];
}
NSArray *_buttonParseBlacklist; // Don't send inputs from these buttons to ButtonInputParser

CGEventRef handleInput(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo) {
        
#if DEBUG
    //NSLog(@"CGG");
    //    NSLog(@"devices which produced relevant inputs: %lld", _buttonInputsFromRelevantDevices.count);
    //    NSLog(@"Incoming event: %@", [NSEvent eventWithCGEvent:event]); // TODO: Sometimes events seem to be deallocated when reaching this point, causing a crash. This is likely to do with inserting fake events.
#endif
    
    if ([_buttonInputsFromRelevantDevices isEmpty]) {
#if DEBUG
        NSLog(@"_buttonInputsFromRelevantDevices is empty."); // This should only happen if the input comes from a device which is not relevant
#endif
        return event;
    }
    
    NSUInteger buttonNumber = CGEventGetIntegerValueField(event, kCGMouseEventButtonNumber) + 1;
    
    if ([_buttonParseBlacklist containsObject:@(buttonNumber)]) {
#if DEBUG
//        NSLog(@"Received input from blacklisted mouse button: %lu", (unsigned long)buttonNumber); // This should only happen when inserting fake events
#endif
        return event;
    };
    
    MFDevice *dev = [_buttonInputsFromRelevantDevices dequeue];
    
    long long pr = CGEventGetIntegerValueField(event, kCGMouseEventPressure);
    MFButtonInputType triggertType = pr == 0 ? kMFButtonInputTypeButtonUp : kMFButtonInputTypeButtonDown;
    
    MFEventPassThroughEvaluation eval = [ButtonInputParser parseInputWithButton:@(buttonNumber) triggerType:triggertType inputDevice:dev];
    if (eval == kMFEventPassThroughRefusal) {
        return nil;
    }
    
    return event;

}

@end
