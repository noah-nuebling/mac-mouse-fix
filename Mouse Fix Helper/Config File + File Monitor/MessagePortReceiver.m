

//
//  MessagePortReceiver.m
//  Mouse Fix Helper
//
//  Created by Noah Nübling on 03.12.18.
//  Copyright © 2018 Noah Nuebling Enterprises Ltd. All rights reserved.
//

#import "MessagePortReceiver.h"
#import "ConfigFileInterface.h"

@implementation MessagePortReceiver

+ (void)load {
    
    CFMessagePortRef localPort =
    CFMessagePortCreateLocal(NULL,
                             CFSTR("com.uebler.nuebler.mouse.fix.port"),
                             UIChangedCallback,
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

static CFDataRef UIChangedCallback(CFMessagePortRef port, SInt32 messageID, CFDataRef data, void *info) {
    
    [ConfigFileInterface reactToConfigFileChange];
    
    return nil;
}

@end

