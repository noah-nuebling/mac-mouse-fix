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
#import "ButtonLandscapeAssessor.h"

#import <CoreFoundation/CoreFoundation.h>

@implementation MessagePort_Helper

#pragma mark - local (incoming messages)

/// I'm not sure this is supposed to be load_Manual instead of load
+ (void)load_Manual {
    
    NSLog(@"Initializing MessagePort...");
    
    CFMessagePortRef localPort =
    CFMessagePortCreateLocal(NULL,
                             (__bridge CFStringRef)kMFBundleIDHelper,
                             didReceiveMessage,
                             nil,
                             nil);
    
    NSLog(@"localPort: %@ (MessagePortReceiver)", localPort);
    
    if (localPort != NULL) {
        /// CFMessagePortCreateRunLoopSource() used to crash when another instance of MMF Helper was already running.
        /// It would log this: `*** CFMessagePort: bootstrap_register(): failed 1100 (0x44c) 'Permission denied', port = 0x1b03, name = 'com.nuebling.mac-mouse-fix.helper'`
        /// I think the reason for this messate is that the existing instance would already 'occupy' the kMFBundleIDHelper name.
        /// Checking if `localPort != nil` should detect this case
    
        CFRunLoopSourceRef runLoopSource =
            CFMessagePortCreateRunLoopSource(kCFAllocatorDefault, localPort, 0);
        
        CFRunLoopAddSource(CFRunLoopGetCurrent(),
                           runLoopSource,
                           kCFRunLoopCommonModes);
        
        CFRelease(runLoopSource);
    } else {
        NSLog(@"Failed to create a local message port. This might be because there is another instance of Helper already running. Crashing the app.");
        @throw [NSException exceptionWithName:@"NoMessagePortException" reason:@"Couldn't create a local CFMessagePort. Can't function properly without local CFMessagePort" userInfo:nil];
    }
}

static CFDataRef didReceiveMessage(CFMessagePortRef port, SInt32 messageID, CFDataRef data, void *info) {
    
    NSDictionary *messageDict = [NSKeyedUnarchiver unarchiveObjectWithData:(__bridge NSData *)data];
    
    NSString *message = messageDict[kMFMessageKeyMessage];
    NSObject *payload = messageDict[kMFMessageKeyPayload];
    
    NSData *response = nil;
    
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
    } else if ([message isEqualToString:@"enableKeyCaptureMode"]) {
        [TransformationManager enableKeyCaptureMode];
    } else if ([message isEqualToString:@"disableKeyCaptureMode"]) {
        [TransformationManager disableKeyCaptureMode];
    } else {
        NSLog(@"Unknown message received: %@", message);
    }
    
    return (__bridge CFDataRef)response;
}

@end

