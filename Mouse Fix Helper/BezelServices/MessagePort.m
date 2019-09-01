#import "MessagePort.h"
#import "ConfigFileInterface.h"

#import <AppKit/NSWindow.h>

@implementation MessagePort

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
    
    NSLog(@"Helper Received Message!");
    
    [ConfigFileInterface reactToConfigFileChange];
    
    return nil;
}

@end

