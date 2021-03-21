//
// --------------------------------------------------------------------------
// MessagePort_Helper.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "MessagePort_Helper.h"
#import "ConfigFileInterface_Helper.h"
#import "TransformationManager.h"
#import <AppKit/NSWindow.h>
#import "AccessibilityCheck.h"
#import "Constants.h"
#import "SharedMessagePort.h"

#import <CoreFoundation/CoreFoundation.h>

@implementation MessagePort_Helper

#pragma mark - local (incoming messages)

+ (void)load_Manual {
    
    CFMessagePortRef localPort =
    CFMessagePortCreateLocal(NULL,
                             CFSTR("com.nuebling.mousefix.helper.port"),
                             didReceiveMessage,
                             nil,
                             nil);
    
    NSLog(@"localPort: %@ (MessagePortReceiver)", localPort);
    
    CFRunLoopSourceRef runLoopSource =
	    CFMessagePortCreateRunLoopSource(kCFAllocatorDefault, localPort, 0);
    
    CFRunLoopAddSource(CFRunLoopGetCurrent(),
                       runLoopSource,
                       kCFRunLoopCommonModes);
    
    CFRelease(runLoopSource);
}

static CFDataRef didReceiveMessage(CFMessagePortRef port, SInt32 messageID, CFDataRef data, void *info) {
    
    NSDictionary *messageDict = [NSKeyedUnarchiver unarchiveObjectWithData:(__bridge NSData *)data];
    
    NSString *message = messageDict[kMFMessageKeyMessage];
    NSObject *payload = messageDict[kMFMessageKeyPayload];
    
    NSLog(@"Helper Received Message: %@ with payload: %@", message, payload);
    
    if ([message isEqualToString:@"configFileChanged"]) {
        [ConfigFileInterface_Helper reactToConfigFileChange];
    } else if ([message isEqualToString:@"terminate"]) {
        [NSApp.delegate applicationWillTerminate:[[NSNotification alloc] init]];
        [NSApp terminate:NULL];
    } else if ([message isEqualToString:@"checkAccessibility"]) {
        if (![AccessibilityCheck check]) {
            [SharedMessagePort sendMessage:@"accessibilityDisabled" withPayload:nil expectingReply:NO];
        }
    } else if ([message isEqualToString:@"enableAddMode"]) {
        [TransformationManager enableAddMode];
    } else if ([message isEqualToString:@"disableAddMode"]) {
        [TransformationManager disableAddMode];
    } else if ([message isEqual:@"getCapturedButtons"]) {
        
    } else {
        NSLog(@"Unknown message received: %@", message);
    }
    
    NSData *response = nil;
    return (__bridge CFDataRef)response;
}

@end

