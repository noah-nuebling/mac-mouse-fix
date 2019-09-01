//
//  MessagePortPref.m
//  Mouse Fix
//
//  Created by Noah Nübling on 01.09.19.
//  Copyright © 2019 Noah Nuebling. All rights reserved.
//

#import "MessagePortPrefPane.h"

@implementation MessagePortPrefPane

#pragma mark - local (for incoming messages)

+ (void)load {
    
    if (self == [MessagePortPrefPane class]) {
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
    
    NSData *response = NULL;
    return (__bridge CFDataRef)response;
}

#pragma mark - remote (for outgoing messages)

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
@end
