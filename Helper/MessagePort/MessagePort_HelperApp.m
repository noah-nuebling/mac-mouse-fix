//
// --------------------------------------------------------------------------
// MessagePort_HelperApp.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "MessagePort_HelperApp.h"
#import "ConfigFileInterface_Helper.h"
#import "TransformationManager.h"
#import <AppKit/NSWindow.h>
#import "AccessibilityCheck.h"
#import "Constants.h"

#import <CoreFoundation/CoreFoundation.h>

@implementation MessagePort_HelperApp

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
    
    NSString *message = [[NSString alloc] initWithData:(__bridge NSData *)data encoding:NSUTF8StringEncoding];
    NSLog(@"Helper Received Message: %@",message);
    
    if ([message isEqualToString:@"configFileChanged"]) {
        [ConfigFileInterface_Helper reactToConfigFileChange];
    } else if ([message isEqualToString:@"terminate"]) {
        [NSApp.delegate applicationWillTerminate:[[NSNotification alloc] init]];
        [NSApp terminate:NULL];
    } else if ([message isEqualToString:@"checkAccessibility"]) {
        if (![AccessibilityCheck check]) {
            [MessagePort_HelperApp sendMessageToMainApp:@"accessibilityDisabled" withPayload:nil];
        }
    } else if ([message isEqualToString:@"enableAddMode"]) {
        [TransformationManager enableAddMode];
    } else if ([message isEqualToString:@"disableAddMode"]) {
        [TransformationManager disableAddMode];
    } else {
        NSLog(@"Unknown message received: %@", message);
    }
    
    NSData *response = NULL;
    return (__bridge CFDataRef)response;
}


#pragma mark - remote (outgoing messages)

//+ (void)sendMessageToMainApp:(NSString *)message {
//    
//    NSLog(@"Sending message to main app: %@", message);
//    
//    CFMessagePortRef remotePort = CFMessagePortCreateRemote(kCFAllocatorDefault, CFSTR("com.nuebling.mousefix.port"));
//    if (remotePort == NULL) {
//        NSLog(@"there is no CFMessagePort");
//        return;
//    }
//    
//    SInt32 messageID = 0x420666; // Arbitrary
//    CFDataRef messageData = (__bridge CFDataRef)[message dataUsingEncoding:kUnicodeUTF8Format];
//    CFTimeInterval sendTimeout = 0.0;
//    CFTimeInterval recieveTimeout = 0.0;
//    CFStringRef replyMode = NULL;
//    CFDataRef returnData = nil;
//    SInt32 status = CFMessagePortSendRequest(remotePort, messageID, messageData, sendTimeout, recieveTimeout, replyMode, &returnData);
//    CFRelease(remotePort);
//    if (status != 0) {
//        NSLog(@"CFMessagePortSendRequest status: %d", status);
//    }
//}

+ (void)sendMessageToMainApp:(NSString *)message withPayload:(NSObject <NSCoding> * _Nullable)payload {
    NSDictionary *messageDict;
    if (payload) {
        messageDict = @{
            kMFMessageKeyMessage: message,
            kMFMessageKeyPayload: payload, // This crashes if payload is nil for some reason
        };
    } else {
        messageDict = @{
            kMFMessageKeyMessage: message,
        };
    }
    
    NSLog(@"Sending message to main app: %@ with payload: %@", message, payload);
    
    CFMessagePortRef remotePort = CFMessagePortCreateRemote(kCFAllocatorDefault, CFSTR("com.nuebling.mousefix.port"));
    if (remotePort == NULL) {
        NSLog(@"there is no CFMessagePort");
        return;
    }
    SInt32 messageID = 0x420666; // Arbitrary
    CFDataRef messageData = (__bridge CFDataRef)[NSKeyedArchiver archivedDataWithRootObject:messageDict];;
    CFTimeInterval sendTimeout = 0.0;
    CFTimeInterval recieveTimeout = 0.0;
    CFStringRef replyMode = NULL;
    CFDataRef returnData = nil;
    SInt32 status = CFMessagePortSendRequest(remotePort, messageID, messageData, sendTimeout, recieveTimeout, replyMode, &returnData);
    CFRelease(remotePort);
    if (status != 0) {
        NSLog(@"CFMessagePortSendRequest status: %d", status);
    }
    
}

@end

