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

+ (void)launchCLT:(NSURL *)commandLineTool
         withArgs:(NSArray <NSString *> *)args {
    [self launchCLT:commandLineTool withArgs:args callback:nil];
}
+ (void)launchCLT:(NSURL *)commandLineTool
         withArgs:(NSArray <NSString *> *)args
         callback:(MFCTLCallback)callback {
    
    if (@available(macOS 10.13, *)) {
        NSTask *task = [[NSTask alloc] init];
        task.executableURL = commandLineTool;
        task.arguments = args;
        NSPipe *pipe = NSPipe.pipe;
        task.standardError = pipe;
        task.standardOutput = pipe;
        NSError *error;
        task.terminationHandler = ^(NSTask *task) {
            NSLog(@"CLT %@ terminated with stdout/stderr: %@, error: %@", commandLineTool.lastPathComponent, [NSString.alloc initWithData:pipe.fileHandleForReading.readDataToEndOfFile encoding:NSUTF8StringEncoding], error);
            callback(task, pipe, error);
        };
        [task launchAndReturnError:&error];
        
    } else { // Fallback on earlier versions
        [NSTask launchedTaskWithLaunchPath:commandLineTool.path arguments: args]; // Can't clean up here easily cause there's no termination handler
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
