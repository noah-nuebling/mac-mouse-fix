//
// --------------------------------------------------------------------------
// SharedUtil.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "SharedUtil.h"
#import "Objects.h"


@implementation SharedUtil

+ (void)launchCLT:(NSURL *)commandLineTool
         withArgs:(NSArray <NSString *> *)args {
    [self launchCLT:commandLineTool withArgs:args callback:nil];
}
+ (void)launchCLT:(NSURL *)commandLineTool
         withArgs:(NSArray <NSString *> *)args
         callback:(MFCTLCallback _Nullable)callback {
    
    if (@available(macOS 10.13, *)) {
        
        NSLog(@"Launching CLT at: %@, with args: %@, from bundle at: %@, from thread: %@", commandLineTool, args, Objects.mainAppBundle.bundleURL, NSThread.currentThread);
        
//        NSTask *task = [[NSTask alloc] init];
//        task.executableURL = commandLineTool;
//        task.arguments = args;
//        NSPipe *pipe = NSPipe.pipe;
//        task.standardError = pipe;
//        task.standardOutput = pipe;
//        NSError *error;
//        task.terminationHandler = ^(NSTask *task) {
//            NSLog(@"CLT %@ terminated with stdout/stderr: %@, error: %@", commandLineTool.lastPathComponent, [NSString.alloc initWithData:pipe.fileHandleForReading.readDataToEndOfFile encoding:NSUTF8StringEncoding], error);
//            callback(task, pipe, error);
//        };
//        [task launchAndReturnError:&error]; // [task launch];
            
        // ^ This code gets the stdout and stderr of the task and prints that once it's done, which is nice for debugging.
        //      But for some reason, when we launch Mac Mouse Fix Accomplice using this, after the accomplice kills this process, the accomplice terminates as well..
        
        // v This weird behaviour ((doesn't happen)) when we use `launchedTaskWithExecutableURL:` - Actually still happening sometimes...
        
        [NSTask launchedTaskWithExecutableURL:commandLineTool arguments:args error:nil terminationHandler:nil];
        
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
