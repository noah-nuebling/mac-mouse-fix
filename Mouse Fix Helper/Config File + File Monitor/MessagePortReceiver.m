//
//  MessagePortReceiver.m
//  Mouse Fix Helper
//
//  Created by Noah Nübling on 03.12.18.
//  Copyright © 2018 Noah Nuebling Enterprises Ltd. All rights reserved.
//

#import "MessagePortReceiver.h"
#import "ConfigFileMonitor.h"

@implementation MessagePortReceiver

+ (void)start {
    
    CFMessagePortRef localPort =
    CFMessagePortCreateLocal(nil,
                             CFSTR("com.uebler.nuebler.mouse.fix.port"),
                             UIChangedCallback,
                             nil,
                             nil);
    
    CFRunLoopSourceRef runLoopSource =
    CFMessagePortCreateRunLoopSource(nil, localPort, 0);
    
    CFRunLoopAddSource(CFRunLoopGetCurrent(),
                       runLoopSource,
                       kCFRunLoopCommonModes);
}

static CFDataRef UIChangedCallback(CFMessagePortRef port, SInt32 messageID, CFDataRef data, void *info) {
    
    [ConfigFileMonitor reactToConfigFileChange];
    
    return nil;
}

@end
