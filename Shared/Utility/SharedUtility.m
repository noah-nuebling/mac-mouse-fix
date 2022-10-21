//
// --------------------------------------------------------------------------
// SharedUtility.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "SharedUtility.h"
#import "Locator.h"
#import "ConfigFileInterface_App.h"
#import "ConfigFileInterface_Helper.h"

@implementation SharedUtility

#pragma mark - Check if this is a prerelease version

+ (BOOL)runningPreRelease {
    
    BOOL runningPrerelease = NO;
    
    /// Check debug configuration

#if DEBUG 
    runningPrerelease = YES;
#endif
    
    /// Check app name for 'beta' or 'alpha'
    ///     We've started shipping release builds as betas because under MMF 3 using Swift, the debug builds are very very slow.
    ///     Notes:
    ///     - Why are we using the 'localized' search? What does that do?
    ///     - Attention! This makes the version names magic. Make sure you always include 'beta' or 'alpha' in the prerelease version names!
    
    if (!runningPrerelease) {
        
        NSString *versionName = Locator.bundleVersionShort;
        if ([versionName localizedCaseInsensitiveContainsString:@"beta"] || [versionName localizedCaseInsensitiveContainsString:@"alpha"]) {
            runningPrerelease = YES;
        }
    }
    
    return runningPrerelease;
}

#pragma mark - Check which executable is running

/// Return YES if called by main app
+ (BOOL)runningMainApp {
    return [NSBundle.mainBundle.bundleIdentifier isEqual:kMFBundleIDApp];
}
/// Return YES if called by helper app
+ (BOOL)runningHelper {
    return [NSBundle.mainBundle.bundleIdentifier isEqual:kMFBundleIDHelper];
}
// Return YES if called by accomplice
+ (BOOL)runningAccomplice {
    return [NSFileManager.defaultManager isExecutableFileAtPath:[NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:kMFAccompliceName]];
}

#pragma mark - Use command-line tools

/// This returns the output of the CLT, in contrast to the `launchCTL` functions further down
+ (NSString *)launchCTL:(NSURL *)executableURL withArguments:(NSArray<NSString *> *)arguments error:(NSError ** _Nullable)error {
    
    NSPipe * launchctlOutput = [NSPipe pipe];
    
    if (@available(macOS 10.13, *)) { /// macOS version 10.13+
        
        NSTask *task = [[NSTask alloc] init];
        [task setExecutableURL: executableURL.absoluteURL];
        [task setArguments: arguments];
        [task setStandardOutput: launchctlOutput];
        
        [task launchAndReturnError:error];
    } else { /// Fallback on earlier versions
        NSTask *task = [[NSTask alloc] init];
        [task setLaunchPath: executableURL.path];
        [task setArguments: arguments];
        [task setStandardOutput: launchctlOutput];
        
        [task launch];
    }
    
    /// Get output
    
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
        
        NSLog(@"Launching CLT at: %@, with args: %@, from bundle at: %@, from thread: %@", commandLineTool, args, Locator.mainAppBundle.bundleURL, NSThread.currentThread);
        
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

#pragma mark - Monitor file system

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

#pragma mark - Debug

+ (NSString *)callerInfo {
    return [NSString stringWithFormat:@" - %@", [[NSThread callStackSymbols] objectAtIndex:2]];
}
+ (void)printStackTrace {
    NSLog(@"PRINTING STACK TRACE: %@", [NSThread callStackSymbols]);
}

+ (NSString *)currentDispatchQueueDescription {
    return dispatch_get_current_queue().description;
}

// For debugging.
+ (void)printInvocationCountWithId:(NSString *)strId {
    
    static NSMutableDictionary<NSString *, NSNumber *> *ids;
    static BOOL hasBeenInited = NO;
    
    if (hasBeenInited == NO) {
        ids = [NSMutableDictionary dictionary];
        hasBeenInited = YES;
    }
    
    int counterForId;
    
    NSNumber *counterForIdFromDict = ids[strId];
    if (counterForIdFromDict == nil) {
        counterForId = 0;
    } else {
        counterForId = counterForIdFromDict.intValue;
    }
    
    counterForId++;
    
    NSLog(@"%@: %d", strId, counterForId);
    
    ids[strId] = @(counterForId);
    
}

#pragma mark - Button Numbers

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

#pragma mark - Remaps data model assessment

+ (BOOL)button:(NSNumber * _Nonnull)button isPartOfModificationPrecondition:(NSDictionary *)modificationPrecondition {
    NSArray *buttonPreconditions = modificationPrecondition[kMFModificationPreconditionKeyButtons];
    NSIndexSet *buttonIndexes = [buttonPreconditions indexesOfObjectsPassingTest:^BOOL(NSDictionary *_Nonnull dict, NSUInteger idx, BOOL * _Nonnull stop) {
        return [dict[kMFButtonModificationPreconditionKeyButtonNumber] isEqualToNumber:button];
    }];
    return buttonIndexes.count != 0;
}

#pragma mark - Other

+ (NSObject *)deepCopyOf:(NSObject *)object {
    return [NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:object]];
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

+ (int8_t)signOf:(double)x {
    return (0 < x) - (x < 0);
}

+ (NSString *)binaryRepresentation:(int)value {
    
    long nibbleCount = sizeof(value) * 2;
    NSMutableString *bitString = [NSMutableString stringWithCapacity:nibbleCount * 5];
    
    for (long index = 4 * nibbleCount - 1; index >= 0; index--)
    {
        [bitString appendFormat:@"%i", value & (1 << index) ? 1 : 0];
        if (index % 4 == 0)
        {
            [bitString appendString:@" "];
        }
    }
    return bitString;
}

@end
