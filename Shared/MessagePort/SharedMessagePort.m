//
// --------------------------------------------------------------------------
// SharedMessagePort.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

#import "SharedMessagePort.h"
#import <Cocoa/Cocoa.h>
#import "Constants.h"
#import "SharedUtility.h"

@implementation SharedMessagePort

+ (NSObject *_Nullable)sendMessage:(NSString * _Nonnull)message withPayload:(NSObject <NSCoding> * _Nullable)payload expectingReply:(BOOL)replyExpected { // TODO: Consider renaming last arg to `expectingReturn`
    
    NSDictionary *messageDict;
    if (payload) {
        messageDict = @{
            kMFMessageKeyMessage: message,
            kMFMessageKeyPayload: payload, /// This crashes if payload is nil for some reason
        };
    } else {
        messageDict = @{
            kMFMessageKeyMessage: message,
        };
    }
    
    DDLogInfo(@"Sending message: %@ with payload: %@ from bundle: %@ via message port", message, payload, NSBundle.mainBundle.bundleIdentifier);
    
    NSString *remotePortName;
    if (SharedUtility.runningMainApp) {
        remotePortName = kMFBundleIDHelper;
    } else if (SharedUtility.runningHelper) {
        remotePortName = kMFBundleIDApp;
    }
    
    static CFMessagePortRef _remotePort = NULL;
//    if (_remotePort == NULL) { /// Checking for NULL and storing `_remotePort` in a static var  is unnecessary, since `CFMessagePortCreateRemote()` will return the existing instance if invoked several times.
    _remotePort = CFMessagePortCreateRemote(kCFAllocatorDefault, (__bridge CFStringRef)remotePortName);
    if (_remotePort == NULL) {
        DDLogInfo(@"Can't send message, because there is no CFMessagePort");
        return nil;
    }
//    }
    
    CFMessagePortSetInvalidationCallBack(_remotePort, invalidationCallback);
    
    SInt32 messageID = 0x420666; /// Arbitrary
    CFDataRef messageData = (__bridge CFDataRef)[NSKeyedArchiver archivedDataWithRootObject:messageDict];
    CFTimeInterval sendTimeout = 0.0;
    CFTimeInterval recieveTimeout = 0.0;
    CFStringRef replyMode = NULL;
    CFDataRef returnData = NULL;
    if (replyExpected) {
//        sendTimeout = 1.0;
        recieveTimeout = 1.0;
        replyMode = kCFRunLoopDefaultMode;
    }
    SInt32 status = CFMessagePortSendRequest(_remotePort, messageID, messageData, sendTimeout, recieveTimeout, replyMode, &returnData);
//    CFRelease(remotePort);
    if (status != 0) {
        DDLogError(@"Non-zero CFMessagePortSendRequest status: %d", status);
//        assert(false);
    }
    
    NSObject *returnObject = nil;
    if (returnData != NULL && replyExpected /*&& status == 0*/) {
        returnObject = [NSKeyedUnarchiver unarchiveObjectWithData:(__bridge NSData *)returnData];
    }
    return returnObject;
}

void invalidationCallback(CFMessagePortRef ms, void *info) {
    
    DDLogInfo(@"SharedMessagePort invalidated in %@", SharedUtility.runningHelper ? @"Helper" : @"MainApp");
}

//+ (CFDataRef _Nullable)sendMessage:(NSString *_Nonnull)message expectingReply:(BOOL)expectingReply {
//
//    DDLogInfo(@"Sending message: %@ via message port from bundle: %@", message, NSBundle.mainBundle);
//
//    CFMessagePortRef remotePort = CFMessagePortCreateRemote(kCFAllocatorDefault, CFSTR("com.nuebling.mousefix.helper.port"));
//    if (remotePort == NULL) {
//        DDLogInfo(@"There is no CFMessagePort");
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
//        DDLogInfo(@"Non-zero CFMessagePortSendRequest status: %d", status);
//    }
//    CFRelease(remotePort);
//
//    return returnData;
//}

@end
