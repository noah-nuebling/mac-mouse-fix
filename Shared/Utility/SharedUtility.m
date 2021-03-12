//
// --------------------------------------------------------------------------
// SharedUtility.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "SharedUtility.h"
#import "Objects.h"

@implementation SharedUtility

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
        [NSTask launchedTaskWithLaunchPath:commandLineTool.path arguments: args];
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

+ (NSObject *)deepCopyOf:(NSObject *)object {
    return [NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:object]];
}

+ (void)printInfoOnCaller {
    NSLog(@"CALLING FUNCTION: %@", [[NSThread callStackSymbols] objectAtIndex:2]);
}
+ (void)printStackTrace {
    NSLog(@"PRINTING STACK TRACE: %@", [NSThread callStackSymbols]);
}

// TODO: Consider returning a mutable dict to avoid constantly using `- mutableCopy`. Maybe even alter `dst` in place and return nothing (And rename to `applyOverridesFrom:to:`).
/// Copy all leaves (elements which aren't dictionaries) from `src` to `dst`. Return the result. (`dst` itself isn't altered)
/// Recursively search for leaves in `src`. For each srcLeaf found, create / replace a leaf in `dst` at a keyPath identical to the keyPath of srcLeaf and with the value of srcLeaf.
+ (NSDictionary *)dictionaryWithOverridesAppliedFrom:(NSDictionary *)src to: (NSDictionary *)dst {
    NSMutableDictionary *dstMutable = [dst mutableCopy];
    if (dstMutable == nil) {
        dstMutable = [NSMutableDictionary dictionary];
    }
    for (id<NSCopying> key in src) {
        NSObject *dstVal = dst[key];
        NSObject *srcVal = src[key];
        if ([srcVal isKindOfClass:[NSDictionary class]] || [srcVal isKindOfClass:[NSMutableDictionary class]]) { // Not sure if checking for mutable dict AND dict is necessary
            // Nested dictionary found. Recursing.
            NSDictionary *recursionResult = [self dictionaryWithOverridesAppliedFrom:(NSDictionary *)srcVal to:(NSDictionary *)dstVal];
            dstMutable[key] = recursionResult;
        } else {
            // Leaf found
            dstMutable[key] = srcVal;
        }
    }
    return dstMutable;
}

+ (CGEventType)CGEventTypeForButtonNumber:(MFMouseButtonNumber)button isMouseDown:(BOOL)isMouseDown {
    
    CGEventType mouseEventType;
    
    if (isMouseDown) {
       if (button == kMFMouseButtonNumberLeft) {
           mouseEventType = kCGEventLeftMouseDown;
       } else if (button == kMFMouseButtonNumberRight) {
           mouseEventType = kCGEventRightMouseDown;
       } else {
           mouseEventType = kCGEventOtherMouseDown;
       }
   } else {
        if (button == kMFMouseButtonNumberLeft) {
            mouseEventType = kCGEventLeftMouseUp;
        } else if (button == kMFMouseButtonNumberRight) {
            mouseEventType = kCGEventRightMouseUp;
        } else {
            mouseEventType = kCGEventOtherMouseUp;
        }
    }
    
    return mouseEventType;
}

+ (CGMouseButton)CGMouseButtonFromMFMouseButtonNumber:(MFMouseButtonNumber)button {
    return (CGMouseButton) button - 1;
}

+ (int8_t)signOf:(double)x {
    return (0 < x) - (x < 0);
}

@end
