#import "MessagePortHelper.h"
#import "ConfigFileInterfaceHelper.h"

#import <AppKit/NSWindow.h>

@implementation MessagePortHelper

#pragma mark - local (for incoming messages)

+ (void)load {
    
    CFMessagePortRef localPort =
    CFMessagePortCreateLocal(NULL,
                             CFSTR("com.nuebling.mousefix.helper.port"),
                             didReceiveMessage,
                             nil,
                             nil);
    
    NSLog(@"localPort: %@ (MessagePortReceiver)", localPort);
    
    CFRunLoopSourceRef runLoopSource =
    CFMessagePortCreateRunLoopSource(nil, localPort, 0);
    
    CFRunLoopAddSource(CFRunLoopGetCurrent(),
                       runLoopSource,
                       kCFRunLoopCommonModes);
    
    CFRelease(runLoopSource);
}

static CFDataRef didReceiveMessage(CFMessagePortRef port, SInt32 messageID, CFDataRef data, void *info) {
    
    NSString *message = [[NSString alloc] initWithData:(__bridge NSData *)data encoding:NSUTF8StringEncoding];
    NSLog(@"Helper Received Message: %@",message);
    
    if ([message isEqualToString:@"configFileChanged"]) {
        [ConfigFileInterfaceHelper reactToConfigFileChange];
    }
    
    NSData *response = NULL;
    return (__bridge CFDataRef)response;
}

#pragma mark - remote (for outgoing messages)

+ (void)sendMessageToPrefPane:(NSString *)message {
    
    NSLog(@"Sending message to PrefPane");
    
    CFMessagePortRef remotePort = CFMessagePortCreateRemote(kCFAllocatorDefault, CFSTR("com.nuebling.mousefix.port"));
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

