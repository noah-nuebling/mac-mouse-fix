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

@implementation KeyCaptureMode


/// Explanation for this class:
///  When the user records keyboard shortcuts in the mainApp we wanted to use eventTaps for that. I think otherwise certain keys weren't captured. Not sure though. The helper already has permissions to use eventTaps so the mainApp delegates the capturing to the helper.


CFMachPortRef _keyCaptureEventTap;

+ (void)enable {
    
    DDLogInfo(@"Enabling keyCaptureMode");
    
    if (_keyCaptureEventTap == nil) {
        _keyCaptureEventTap = [ModificationUtility createEventTapWithLocation:kCGHIDEventTap mask:CGEventMaskBit(kCGEventKeyDown) | CGEventMaskBit(NSEventTypeSystemDefined) option:kCGEventTapOptionDefault placement:kCGHeadInsertEventTap callback:keyCaptureModeCallback];
    }
    CGEventTapEnable(_keyCaptureEventTap, true);
}

+ (void)disable {
    CGEventTapEnable(_keyCaptureEventTap, false);
}

CGEventRef  _Nullable keyCaptureModeCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo) {
    
    CGEventFlags flags  = CGEventGetFlags(event);
    
    NSDictionary *payload;
    
    if (type == kCGEventKeyDown) {
        
        CGKeyCode keyCode = CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
        
        if (keyCaptureModePayloadIsValidWithKeyCode(keyCode, flags)) {
            
            payload = @{
                @"keyCode": @(keyCode),
                @"flags": @(flags),
            };
            
            [MFMessagePort sendMessage:@"keyCaptureModeFeedback" withPayload:payload waitForReply:NO];
            [KeyCaptureMode disable];
        }
        
    } else if (type == NSEventTypeSystemDefined) {
        
        NSEvent *e = [NSEvent eventWithCGEvent:event];
        
        MFSystemDefinedEventType type = (MFSystemDefinedEventType)(e.data1 >> 16);
        
        if (keyCaptureModePayloadIsValidWithEvent(e, flags, type)) {
            
            DDLogDebug(@"Capturing system event with data1: %ld, data2: %ld", e.data1, e.data2);
            
            payload = @{
                @"systemEventType": @(type),
                @"flags": @(flags),
            };
            
            [MFMessagePort sendMessage:@"keyCaptureModeFeedbackWithSystemEvent" withPayload:payload waitForReply:NO];
            [KeyCaptureMode disable];
        }
        
    }
    
    
    return nil;
}
bool keyCaptureModePayloadIsValidWithKeyCode(CGKeyCode keyCode, CGEventFlags flags) {
    return true; /// keyCode 0 is 'A'
}

bool keyCaptureModePayloadIsValidWithEvent(NSEvent *e, CGEventFlags flags, MFSystemDefinedEventType type) {
    
    BOOL isSub8 = (e.subtype == 8); /// 8 -> NSEventSubtypeScreenChanged
    BOOL isKeyDown = (e.data1 & kMFSystemDefinedEventPressedMask) == 0;
    BOOL secondDataIsNil = e.data2 == -1; /// The power key up event has both data fields be 0
    BOOL typeIsBlackListed = type == kMFSystemEventTypeCapsLock;
    
    BOOL isValid = isSub8 && isKeyDown && secondDataIsNil && !typeIsBlackListed;
    
    if (!isValid) {
        DDLogDebug(@"KeyCaptureMode received systemDefinedEvent but it is not valid – isSubtype8: %d, isKeyDown: %d, secondDataIsNil: %d, typeIsBlackListed: %d – event: %@, flags: %llu, type: %d", isSub8, isKeyDown, secondDataIsNil, typeIsBlackListed, e, flags, type);
    }
    
    return isValid;
}

@end
