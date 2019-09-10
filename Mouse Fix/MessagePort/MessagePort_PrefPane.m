//
// --------------------------------------------------------------------------
// MessagePort_PrefPane.m
// Created for: Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by: Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "MessagePort_PrefPane.h"
#import "../Accessibility/AuthorizeAccessibilityView.h"

@implementation MessagePort_PrefPane


#pragma mark - local (incoming messages)

+ (void)load {
    
    if (self == [MessagePort_PrefPane class]) {
        CFMessagePortRef localPort =
        CFMessagePortCreateLocal(NULL,
                                 CFSTR("com.nuebling.mousefix.port"),
                                 didReceiveMessage,
                                 nil,
                                 nil);
        
        
        CFRunLoopSourceRef runLoopSource =
        CFMessagePortCreateRunLoopSource(kCFAllocatorDefault, localPort, 0);
        
        CFRunLoopAddSource(CFRunLoopGetMain(),
                           runLoopSource,
                           kCFRunLoopCommonModes);
        
        CFRelease(runLoopSource);
    }
}

static CFDataRef didReceiveMessage(CFMessagePortRef port, SInt32 messageID, CFDataRef data, void *info) {
    
    NSString *message = [[NSString alloc] initWithData:(__bridge NSData *)data encoding:NSUTF8StringEncoding];
    
    NSLog(@"PrefPane Received Message: %@", message);
    
    if ([message isEqualToString:@"accessibilityDisabled"]) {
        [AuthorizeAccessibilityView add];
    }
    
    NSData *response = NULL;
    return (__bridge CFDataRef)response;
}


#pragma mark - remote (outgoing messages)

+ (void)sendMessageToHelper:(NSString *)message {
    
    NSLog(@"Sending message to Helper");
    
    CFMessagePortRef remotePort = CFMessagePortCreateRemote(kCFAllocatorDefault, CFSTR("com.nuebling.mousefix.helper.port"));
    if (remotePort == NULL) {
        NSLog(@"there is no CFMessagePort");
        return;
    }
    
    SInt32 messageID = 0x420666; // Arbitrary
    CFDataRef messageData = (__bridge CFDataRef)[message dataUsingEncoding:kUnicodeUTF8Format];
    CFTimeInterval sendTimeout = 0.0;
    CFTimeInterval recieveTimeout = 0.0;
    CFStringRef replyMode = NULL;
    CFDataRef returnData = nil;
    SInt32 status = CFMessagePortSendRequest(remotePort, messageID, messageData, sendTimeout, recieveTimeout, replyMode, &returnData);
    if (status != 0) {
        NSLog(@"CFMessagePortSendRequest status: %d", status);
    }
}

//+ (NSString *)sendMessageWithReplyToHelper:(NSString *)message {
//    
//    NSLog(@"Sending message to Helper");
//    
//    CFMessagePortRef remotePort = CFMessagePortCreateRemote(kCFAllocatorDefault, CFSTR("com.nuebling.mousefix.helper.port"));
//    if (remotePort == NULL) {
//        NSLog(@"there is no CFMessagePort");
//        return NULL;
//    }
//    
//    SInt32 messageID = 0x420666; // Arbitrary
//    CFDataRef messageData = (__bridge CFDataRef)[message dataUsingEncoding:kUnicodeUTF8Format];
//    CFTimeInterval sendTimeout = 0.0;
//    CFTimeInterval recieveTimeout = 1;
//    CFStringRef replyMode = kCFRunLoopDefaultMode;
//    CFDataRef returnData;
//    SInt32 status = CFMessagePortSendRequest(remotePort, messageID, messageData, sendTimeout, recieveTimeout, replyMode, &returnData);
//    if (status != 0) {
//        NSLog(@"CFMessagePortSendRequest status: %d", status);
//    }
//    
//    return [[NSString alloc] initWithData:(__bridge NSData *)returnData encoding:NSUTF8StringEncoding];
//}


@end
