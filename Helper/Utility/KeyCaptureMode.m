//
// --------------------------------------------------------------------------
// KeyCaptureMode.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "KeyCaptureMode.h"
#import <Cocoa/Cocoa.h>
#import "ModificationUtility.h"
#import "MFMessagePort.h"
#import "Logging.h"
#import "Threads.h"
#import "MFEventTap.h"
#import "Mac_Mouse_Fix_Helper-Swift.h"

#define kListenerID @"KeyCaptureMode"

@implementation KeyCaptureMode

/// Explanation for this class:
///  When the user records keyboard shortcuts in the mainApp we wanted to use eventTaps for that. I think otherwise certain keys weren't captured. Not sure though. The helper already has permissions to use eventTaps so the mainApp delegates the capturing to the helper.

+ (void)enable {
    if (CFRunLoopGetCurrent() != IOThread.runLoop) {
        mfrun(IOThread.runLoop, ^{
            [self enable];
        });
        return;
    }

    DDLogInfo(@"Enabling keyCaptureMode");
    static dispatch_once_t onceToken; dispatch_once(&onceToken, ^{
        [MFEventTap registerListener: kListenerID forEvents: kMFEventType_KeyPress callback: keyCaptureModeCallback];
    });
    [MFEventTap enable: true forListener: kListenerID];
}

+ (void)disable {
    if (CFRunLoopGetCurrent() != IOThread.runLoop) {
        mfrun(IOThread.runLoop, ^{
            [self disable];
        });
        return;
    }
    [MFEventTap enable: false forListener: kListenerID];
}

void keyCaptureModeCallback(MFEventType eventType, CGEventRef *eventPtr) {
    assertRunLoop(IOThread.runLoop);

    CGEventRef event = *eventPtr;
    CGEventType type = CGEventGetType(event);

    CGEventFlags flags  = CGEventGetFlags(event);
    
    NSDictionary *payload;
    
    if (type == kCGEventKeyDown) {
        
        CGKeyCode keyCode = (CGKeyCode)CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
        
        if (keyCaptureModePayloadIsValidWithKeyCode(keyCode, flags)) {
            
            payload = @{
                @"keyCode": @(keyCode),
                @"flags": @(flags),
            };
            
            (void)[MFMessagePort sendMessage: @"keyCaptureModeFeedback" withPayload: payload waitForReply: NO];
            [KeyCaptureMode disable];
        }
        
    } else if (type == NX_SYSDEFINED) {
        
        NSEvent *e = [NSEvent eventWithCGEvent:event];
        
        MFSystemDefinedEventType sysType = (MFSystemDefinedEventType)(e.data1 >> 16);
        
        if (keyCaptureModePayloadIsValidWithEvent(e, flags, sysType)) {
            
            DDLogDebug(@"Capturing system event with data1: %ld, data2: %ld", e.data1, e.data2);
            
            payload = @{
                @"systemEventType": @(sysType),
                @"flags": @(flags),
            };
            
            (void)[MFMessagePort sendMessage: @"keyCaptureModeFeedbackWithSystemEvent" withPayload: payload waitForReply: NO];
            [KeyCaptureMode disable];
        }
        
    }
    
    *eventPtr = NULL;
}

static bool keyCaptureModePayloadIsValidWithKeyCode(CGKeyCode keyCode, CGEventFlags flags) {
    return true; /// keyCode 0 is 'A'
}
static bool keyCaptureModePayloadIsValidWithEvent(NSEvent *e, CGEventFlags flags, MFSystemDefinedEventType type) {

    BOOL isSub8 = (e.subtype == 8); /// 8 -> Maybe `NX_SUBTYPE_AUX_CONTROL_BUTTONS` says Opus 5.5
    BOOL isKeyDown = (e.data1 & kMFSystemDefinedEventPressedMask) == 0;
    BOOL secondDataIsNil = e.data2 == -1; /// The power key up event has both data fields be 0
    BOOL typeIsBlackListed = type == NX_KEYTYPE_CAPS_LOCK;
    
    BOOL isValid = isSub8 && isKeyDown && secondDataIsNil && !typeIsBlackListed;
    
    if (!isValid) {
        DDLogDebug("KeyCaptureMode received systemDefinedEvent but it is not valid – isSubtype8: %d, isKeyDown: %d, secondDataIsNil: %d, typeIsBlackListed: %d – event: %@, flags: %llu, type: %d", isSub8, isKeyDown, secondDataIsNil, typeIsBlackListed, e, flags, type);
    }
    
    return isValid;
}

@end
