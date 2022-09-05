//
// --------------------------------------------------------------------------
// MessagePort_Helper.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "MessagePort_Helper.h"
#import "Config.h"
#import "TransformationManager.h"
#import <AppKit/NSWindow.h>
#import "AccessibilityCheck.h"
#import "Constants.h"
#import "SharedMessagePort.h"
#import "ButtonLandscapeAssessor.h"
#import "DeviceManager.h"

#import <CoreFoundation/CoreFoundation.h>
#import "WannabePrefixHeader.h"

@implementation MessagePort_Helper

#pragma mark - local (incoming messages)

/// I'm not sure this is supposed to be load_Manual instead of load
+ (void)load_Manual {
    
    DDLogInfo(@"Initializing MessagePort...");
    
    CFMessagePortRef localPort =
    CFMessagePortCreateLocal(NULL,
                             (__bridge CFStringRef)kMFBundleIDHelper,
                             didReceiveMessage,
                             nil,
                             nil);
    
    DDLogInfo(@"localPort: %@ (MessagePortReceiver)", localPort);
    
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
        DDLogError(@"Failed to create a local message port. This might be because there is another instance of %@ already running. Crashing the app.", kMFHelperName);
        @throw [NSException exceptionWithName:@"NoMessagePortException" reason:@"Couldn't create a local CFMessagePort. Can't function properly without local CFMessagePort" userInfo:nil];
    }
}

static CFDataRef didReceiveMessage(CFMessagePortRef port, SInt32 messageID, CFDataRef data, void *info) {
    
    NSDictionary *messageDict = [NSKeyedUnarchiver unarchiveObjectWithData:(__bridge NSData *)data];
    
    NSString *message = messageDict[kMFMessageKeyMessage];
    NSObject *payload = messageDict[kMFMessageKeyPayload];
    
    NSData *response = nil;
    
    DDLogInfo(@"Helper Received Message: %@ with payload: %@", message, payload);
    
    if ([message isEqualToString:@"configFileChanged"]) {
        [Config handleConfigFileChange];
    } else if ([message isEqualToString:@"terminate"]) {
//        [NSApp.delegate applicationWillTerminate:[[NSNotification alloc] init]]; /// This creates an infinite loop or something? The statement below is never executed.
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
        DDLogInfo(@"Unknown message received: %@", message);
    }
    
    return (__bridge CFDataRef)response;
}

@end

