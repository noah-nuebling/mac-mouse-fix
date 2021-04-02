//
// --------------------------------------------------------------------------
// SharedUtility.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "SharedUtility.h"
#import "Objects.h"


@implementation SharedUtility

/// This returns the output of the CLT, in contrast to the `launchCTL` functions further down
+ (NSString *)launchCTL:(NSURL *)executableURL withArguments:(NSArray<NSString *> *)arguments error:(NSError ** _Nullable)error {
    
    NSPipe * launchctlOutput = [NSPipe pipe];
    
    if (@available(macOS 10.13, *)) { // macOS version 10.13+
        
        NSTask *task = [[NSTask alloc] init];
        [task setExecutableURL: executableURL.absoluteURL];
        [task setArguments: arguments];
        [task setStandardOutput: launchctlOutput];
        
        [task launchAndReturnError:error];
    } else { // Fallback on earlier versions
        NSTask *task = [[NSTask alloc] init];
        [task setLaunchPath: executableURL.path];
        [task setArguments: arguments];
        [task setStandardOutput: launchctlOutput];
        
        [task launch];
    }
    
    // Get output
    
    NSFileHandle *output_fileHandle = [launchctlOutput fileHandleForReading];
    NSData *output_data = [output_fileHandle readDataToEndOfFile];
    NSString *output_string = [[NSString alloc] initWithData:output_data encoding:NSUTF8StringEncoding];
    
    if (output_string == nil) {
        output_string = @"";
    }
    
    return output_string;
}

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
