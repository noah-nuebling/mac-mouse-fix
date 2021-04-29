//
// --------------------------------------------------------------------------
// SharedMessagePort.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "SharedMessagePort.h"
#import <Cocoa/Cocoa.h>
#import "Constants.h"
#import "SharedUtility.h"

@implementation SharedMessagePort

+ (NSObject *_Nullable)sendMessage:(NSString * _Nonnull)message withPayload:(NSObject <NSCoding> * _Nullable)payload expectingReply:(BOOL)replyExpected {
    
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
    
    NSLog(@"Sending message: %@ with payload: %@ from bundle: %@ via message port", message, payload, NSBundle.mainBundle.bundleIdentifier);
    
    NSString *remotePortName;
    if (SharedUtility.runningMainApp) {
        remotePortName = kMFBundleIDHelper;
    } else if (SharedUtility.runningHelper) {
        remotePortName = kMFBundleIDApp;
    }
    
    CFMessagePortRef remotePort = CFMessagePortCreateRemote(kCFAllocatorDefault, (__bridge CFStringRef)remotePortName);
    if (remotePort == NULL) {
        NSLog(@"Can't send message, because there is no CFMessagePort");
        return nil;
    }
    
    SInt32 messageID = 0x420666; // Arbitrary
    CFDataRef messageData = (__bridge CFDataRef)[NSKeyedArchiver archivedDataWithRootObject:messageDict];;
    CFTimeInterval sendTimeout = 0.0;
    CFTimeInterval recieveTimeout = 0.0;
    CFStringRef replyMode = NULL;
    CFDataRef returnData;
    if (replyExpected) {
        recieveTimeout = 1.0;
        replyMode = kCFRunLoopDefaultMode;
    }
    SInt32 status = CFMessagePortSendRequest(remotePort, messageID, messageData, sendTimeout, recieveTimeout, replyMode, &returnData);
    CFRelease(remotePort);
    if (status != 0) {
        NSLog(@"Non-zero CFMessagePortSendRequest status: %d", status);
    }
    
    NSObject *returnObject = nil;
    if (replyExpected && status == 0) {
        returnObject = [NSKeyedUnarchiver unarchiveObjectWithData:(__bridge NSData *)returnData];
    }
    return returnObject;
}
//
//+ (CFDataRef _Nullable)sendMessage:(NSString *_Nonnull)message expectingReply:(BOOL)expectingReply {
//
//    NSLog(@"Sending message: %@ via message port from bundle: %@", message, NSBundle.mainBundle);
//
//    CFMessagePortRef remotePort = CFMessagePortCreateRemote(kCFAllocatorDefault, CFSTR("com.nuebling.mousefix.helper.port"));
//    if (remotePort == NULL) {
//        NSLog(@"There is no CFMessagePort");
//        return nil;
//    }
//
//    SInt32 messageID = 0x420666; // Arbitrary
//    CFDataRef messageData = (__bridge CFDataRef)[message dataUsingEncoding:kUnicodeUTF8Format];
//    CFTimeInterval sendTimeout = 0.0;
//    CFTimeInterval receiveTimeout = 0.0;
//    CFStringRef replyMode = NULL;
//    CFDataRef returnData;
//    if (expectingReply) {
//        receiveTimeout = 0.1; // 1.0
//        replyMode = kCFRunLoopDefaultMode;
//    }
//    SInt32 status = CFMessagePortSendRequest(remotePort, messageID, messageData, sendTimeout, receiveTimeout, replyMode, &returnData);
//    if (status != 0) {
//        NSLog(@"Non-zero CFMessagePortSendRequest status: %d", status);
//    }
//    CFRelease(remotePort);
//
//    return returnData;
//}

@end
