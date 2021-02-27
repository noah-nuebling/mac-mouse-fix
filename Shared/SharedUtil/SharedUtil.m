//
// --------------------------------------------------------------------------
// SharedUtil.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "SharedUtil.h"

@implementation SharedUtil

+ (void)launchCLT:(NSURL *)commandLineTool withArgs:(NSArray <NSString *> *)args {
    if (@available(macOS 10.13, *)) {
        [[NSTask launchedTaskWithExecutableURL:commandLineTool arguments:args error:nil terminationHandler:nil] launch];
    } else { // Fallback on earlier versions
        [[NSTask launchedTaskWithLaunchPath:commandLineTool.path arguments:args] launch];
    }
}
+ (FSEventStreamRef)scheduleFSEventStreamOnPaths:(NSArray<NSString *> *)paths withCallback:(FSEventStreamCallback)callback {
    FSEventStreamRef stream = FSEventStreamCreate(kCFAllocatorDefault, callback, NULL, (__bridge CFArrayRef)paths, kFSEventStreamEventIdSinceNow, 1, kFSEventStreamCreateFlagIgnoreSelf ^ kFSEventStreamCreateFlagUseCFTypes);
    FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
    FSEventStreamStart(stream);
    return stream;
}
+ (void)destroyFSEventStream:(FSEventStreamRef)stream {
    if (stream != NULL) {
        FSEventStreamInvalidate(stream);
        FSEventStreamRelease(stream);
    }
}

@end
