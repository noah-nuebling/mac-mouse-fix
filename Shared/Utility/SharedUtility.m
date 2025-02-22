//
// --------------------------------------------------------------------------
// SharedUtility.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "SharedUtility.h"
#import "Locator.h"
#import "Config.h"
#import "Config.h"
#import "SharedUtility.h"
@import AppKit.NSScreen;
#import <objc/runtime.h>
#import "MFSemaphore.h"

@implementation SharedUtility

#pragma mark - runLoops

void MFCFRunLoopPerform(CFRunLoopRef _Nonnull rl, NSArray<NSRunLoopMode> *_Nullable modes, void (^_Nonnull workload)(void)) {
    
    /// Usage:
    ///     `modes` arg:
    ///     - Pass nil to fall back to the default value.
    ///     - You can also pass a single NSRunLoopMode (instead of an array of NSRunLoopModes)
    
    /// Meta-Discussion: Which API to use to perform stuff on a different runLoop?
    ///     - `dispatch_async()`? Maybe, but only works on the mainRunLoop (?). Also I'd like to use the lower-level APIs directly. It also doesn't let us control the runLoopMode.
    ///     - `-[NSRunLoop performInModes:block:]`? Maybe, but the docs say NSRunLoop APIs aren't thread-safe.
    ///         Sidenote: Uses CFRunLoopPerformBlock() under-the-hood.
    ///         Sidenote: The simpler variant -[NSRunLoop performBlock:] only runs in the default mode based on my assembly-investigations.
    ///     - `-[NSObject performSelector:onThread:...]`? Should work, is flexible (can be delayed, and canceled just like NSTimer, can also be awaited like `dispatch_sync`) but the API is cumbersome for simple stuff. - maybe we could wrap it?
    ///     - `CFRunLoopPerformBlock()`? >> Yes sounds good. <<
    ///
    /// Sidenote: NSRunLoop vs CFRunLoop:
    ///     They are not the same. NSRunLoop is a higher-level wrapper around CFRunLoop. Every NSThread has an NSRunLoop. NSRunLoop APIs are generally not thread safe (according to the docs), while CFRunLoop APIs seem to be.
    ///
    /// Discussion: Which runLoop mode(s) to use?
    ///     In MMF, we're usually processing user input. When we run that stuff on the mainThread, we want it to have the highest priority on the thread to maximize responsiveness.
    ///     Using `NSRunLoopCommonModes`, our workload runs if the runLoop is in default, modal, or eventTracking mode (by default) (Source: https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Multithreading/RunLoopManagement/RunLoopManagement.html#//apple_ref/doc/uid/10000057i-CH16)
    ///     To run our workload with higher priority, we can run our workload in *all modes*.
    ///     To run our workload with *even higher* priority, we could run the runLoop in a custom mode. But I'm not sure how to do that [Jan 2025]
    ///
    /// Thread-safety:
    ///     Should be pretty thread-safe as far as I can tell.
    ///
    /// Future plans:
    ///     TODO: (Over time) Replace uses of `dispatch_async()` with MFCFRunLoopPerform().
    ///     (Also (over time): remove DispatchQueues in favour of NSThread and NSRunLoop – so we can reduce thread count and gain more control over threading behavior.)
    
    if (modes && modes.count == 0) {
        assert(false && "modes should not be an empty array. Pass nil for the default value.");
        modes = nil;
    }
    if (!modes) {
        if ((1))    modes = (id)NSRunLoopCommonModes;                       /// Using CommonModes should grant our workload pretty high priorty || Note that we're passing the mode directly (instead of passing an array of modes) – that also works.
        else        modes = CFBridgingRelease(CFRunLoopCopyAllModes(rl));   /// Passing all modes should grant our workload very high priority. Could this lead to unforseen problems? ... Not using this for now out of fear and terror. Ahhhhh.
    }
    CFRunLoopPerformBlock(rl, (__bridge void *)modes, workload);
    CFRunLoopWakeUp(rl);
}

bool MFCFRunLoopPerform_sync(CFRunLoopRef _Nonnull rl, NSArray<NSRunLoopMode> *_Nullable modes, NSTimeInterval timeout, void (^_Nonnull workload)(void)) {
    
    /// Variant of MFCFRunLoopPerform which waits for the workload to complete (or does the workload immediately if `rl` is the current runLoop.)
    ///     Sort of an analog to `dispatch_sync()` (if `MFCFRunLoopPerform()` was `dispatch_async()`)
    ///     Returns `true` if waiting timed out. `false` otherwise.
    ///     Pass `timeout <= 0` to disable the timeout.
    ///
    /// Caution: If you don't pass a timeout, this can lead to deadlocks!
    ///     (Deadlocks can happen if you're waiting for a thread which (indirectly) waits for you. As long as `workload` doesn't wait for anything/acquire any locks, there can't be deadlocks.)
    
    bool didTimeOut = false;
    
    if (CFEqual(rl, CFRunLoopGetCurrent())) {
        workload();
        return didTimeOut;
    }
    
    NSDate *timeoutDate = (timeout <= 0) ? nil : [NSDate dateWithTimeIntervalSinceNow: timeout]; /// We calculate the timeoutDate early in the function, so that it's accurate. Not sure if that's silly.
    
    MFSemaphore *semaphore = [[MFSemaphore alloc] initWithUnits: 0];
    MFCFRunLoopPerform(rl, modes, ^{
        workload();
        [semaphore releaseUnit];
    });
    didTimeOut = [semaphore acquireUnit: timeoutDate]; /// We completely block the current thread/runloop. Do the waiting `-[NSObject performSelector:onThread:...]` APIs do that, too?
    
    return didTimeOut;
}

#pragma mark - Time

uint64_t secondsToMachTime(CFTimeInterval tsSeconds) {
    
    /// Convert to nanoseconds
    double tsNano = tsSeconds * NSEC_PER_SEC;
    
    /// Get the timebase info
    mach_timebase_info_data_t info;
    mach_timebase_info(&info);
    
    /// Convert to mach
    double tsMach = tsNano;
    tsMach /= ((double)info.numer)/((double)info.denom);
    uint64_t tsMachInt = (uint64_t)round(tsMach);
    
    /// Return
    return tsMachInt;
}

CFTimeInterval machTimeToSeconds(uint64_t tsMach) {
    
    /// Get the timebase info
    mach_timebase_info_data_t info;
    mach_timebase_info(&info);
    
    /// Convert to nanoseconds
    double tsNano = tsMach;
    tsNano *= ((double)info.numer)/((double)info.denom);
    
    /// Convert to seconds
    CFTimeInterval tsSeconds = tsNano / NSEC_PER_SEC;
    
    /// Return
    return tsSeconds;
}

#pragma mark - Catch NSException in Swift

NSException * _Nullable tryCatch(void (^tryBlock)(void)) {
    
    /// Src: https://stackoverflow.com/a/32991585/10601702
    ///     Haven't tested this.
    ///     Might be better to return a struct with the exception and the block result?
    
    NSException *e = nil;
    @try {
        tryBlock();
    }
    @catch (NSException *exception) {
        e = exception;
    }
    @finally {
        return e;
    }
}

#pragma mark - Use private classes

+ (id)getPrivateValueOf:(id)obj forName:(NSString *)name {
    
    /// Look through all ivars and properties of `obj` and return the first value with name `name`
    /// -> Actually this only looks at ivars, and ignores values that aren't objects. Because that's all we need it for right now.
    /// -> We use this for changing tabs programmatically in `coolSelectTab(identifier: String)`, so don't break it!
    
    id result;
    id __strong * resultPtr = &result;
    
    iterateIvarsOn(obj, ^(Ivar ivar, BOOL *stop) {
        
        NSString *ivarName = @(ivar_getName(ivar));
        
        if ([name isEqual:ivarName]) {
            
            const char *typeEncoding = ivar_getTypeEncoding(ivar);
            BOOL isObject = typeEncoding[0] == '@';
            if (!isObject) return; /// Ignore everything except objects, because we don't need more rn
            
            id value = (id)object_getIvar(obj, ivar);
            if (value == nil) return;
            
            *resultPtr = value;
            
            *stop = YES;
        }
    });
    
    return result;
}

#pragma mark - Investigate private classes

+ (NSString *)dumpClassInfo:(id)obj {
    /// See this article to understand type encodings: https://nshipster.com/type-encodings/
    
    Class class = [obj class];
    
    /// Name
    const char *className = class_getName(class);
    
    /// Properties
    NSMutableArray *properties = [NSMutableArray array];
    
    iteratePropertiesOn(obj, ^(objc_property_t property, NSString *name, NSString *attributes, BOOL *stop) {
        [properties addObject:name];
    });

    /// Ivars
    NSMutableArray *ivars = [NSMutableArray array];
    
    iterateIvarsOn(obj, ^(Ivar ivar, BOOL *stop) {
        
        NSString *name = [@(ivar_getName(ivar)) copy];
        [ivars addObject:name];
    });

    /// Methods
    NSMutableArray *methods = [NSMutableArray array];
    iterateMethodsOn(obj, ^(Method method, struct objc_method_description *description, BOOL *stop) {
        
        [methods addObject:[NSString stringWithFormat: @"%@ | type: \'%@\'", @(sel_getName(description->name)), @(description->types)]];
    });

    /// Class Methods
    NSMutableArray *classMethods = [NSMutableArray array];
    iterateMethodsOn([obj class], ^(Method method, struct objc_method_description *description, BOOL *stop) {
        
        [classMethods addObject:[NSString stringWithFormat: @"%@ | type: \'%@\'", @(sel_getName(description->name)), @(description->types)]];
    });
    

    
    /// Return string
    return [NSString stringWithFormat:@"Info on class %@ - properties: %@, ivars: %@, methods: %@, classMethods: %@", @(className), properties, ivars, methods, classMethods];
}

#pragma mark - Core class accessor funcs

static void iterateIvarsOn(id obj, void(^callback)(Ivar ivar, BOOL *stop)) {
 
    Class class = [obj class];
    
    unsigned int nIvars;
    Ivar *ivarList = class_copyIvarList(class, &nIvars);
    
    for (int i = 0; i < nIvars; i++) {
        
        Ivar m = ivarList[i];
        BOOL shouldStop = NO;
        callback(m, &shouldStop);
        if (shouldStop) break;
    }
}

//static void iteratePropertyLikeMethods(id obj, void(^callback)(Method method, struct objc_method_description *description, id value, BOOL *stop)) {
//    
//    /// This can cause leaks. See https://stackoverflow.com/questions/7017281/performselector-may-cause-a-leak-because-its-selector-is-unknown
//    ///     -> I think the iterateIvars function can also cause leaks in the same way.
//    
//    iterateMethodsOn(obj, ^(Method method, struct objc_method_description *description, BOOL *stop) {
//        
//        /// Check if last char is `:` to see if method has arguments
//        SEL sel = description->name;
//        const char *name = sel_getName(sel);
//        unsigned long len = strlen(name);
//        char lastChar = name[len-1];
//        if (lastChar == ':') return;
//        id value = [obj performSelector:sel];
//        if (value == nil) return;
//        callback(method, description, value, stop);
//    });
//}

static void iterateMethodsOn(id obj, void(^callback)(Method method, struct objc_method_description *description, BOOL *stop)) {
    
    /// To iterate class methods, pass in [obj class]
    
    Class class = [obj class];
    
    unsigned int nMethods;
    Method *methodList = class_copyMethodList(class, &nMethods);
    
    for (int i = 0; i < nMethods; i++) {
        
        Method m = methodList[i];
        struct objc_method_description *d = method_getDescription(m);
        
        BOOL shouldStop = NO;
        callback(m, d, &shouldStop);
        if (shouldStop) break;
    }
    
    free(methodList);
}

static void iteratePropertiesOn(id obj, void(^callback)(objc_property_t property, NSString *name, NSString *attributes, BOOL *stop)) {
    
    Class class = [obj class];
    
    /// Properties
    unsigned int nProperties;
    objc_property_t *propertyList = class_copyPropertyList(class, &nProperties);
    
    for (int i = 0; i < nProperties; i++) {
        objc_property_t m = propertyList[i];
        const char *name = property_getName(m);
        const char *attrs = property_getAttributes(m);
        BOOL shouldStop = NO;
        callback(m, @(name), @(attrs), &shouldStop);
        if (shouldStop) break;
    }
    
    free(propertyList);
}

#pragma mark - Check if pointer is object


#pragma mark - Check if this is a prerelease version

bool runningPreRelease(void) {

    /// Caching this seems excessive but it's called a lot and actually has a huge performance impact. We also moved to from ObjC to being a pure C function because that improves performance of the app by a few percentage points.
    
    static BOOL _isCached = NO;
    static BOOL _runningPrerelease = NO;
    
    if (_isCached) {
        
        return _runningPrerelease;
        
    } else{
        
        
        /// Check debug configuration
        
#if DEBUG
        _runningPrerelease = YES;
#endif
        
        /// Check app name for 'beta' or 'alpha'
        ///     We've started shipping release builds as betas because under MMF 3 using Swift, the debug builds are very very slow.
        ///     Notes:
        ///     - Why are we using the 'localized' search? What does that do?
        ///     - Attention! This makes the version names magic. Make sure you always include 'beta' or 'alpha' in the prerelease version names!
        
        if (!_runningPrerelease) {
            
            NSString *versionName = Locator.bundleVersionShort;
            if ([versionName localizedCaseInsensitiveContainsString:@"beta"] || [versionName localizedCaseInsensitiveContainsString:@"alpha"]) {
                _runningPrerelease = YES;
            }
        }
        
        /// Update flag
        _isCached = YES;
        
        /// Return
        return _runningPrerelease;
    }
}

#pragma mark - Check which executable is running
/// TODO: Maybe move this to `Locator.m`
/// TODO: Make these NS_INLINE

bool runningMainApp(void) {
    
#if IS_MAIN_APP
    return true;
#endif
    return false;

//    return [NSBundle.mainBundle.bundleIdentifier isEqual:kMFBundleIDApp];
}
bool runningHelper(void) {
    
#if IS_HELPER
    return true;
#endif
    return false;
    
//    return [NSBundle.mainBundle.bundleIdentifier isEqual:kMFBundleIDHelper];
}
//bool runningAccomplice(void) {
//    
//    /// Return YES if called by accomplice
//    return [NSFileManager.defaultManager isExecutableFileAtPath:[NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:kMFAccompliceName]];
//}

#pragma mark - Use command-line tools

+ (NSString *)launchCLT:(NSURL *)executableURL withArguments:(NSArray<NSString *> *)arguments error:(NSError *_Nullable * _Nullable)errorPtr {
    
    /// In contrast to the other launchCTL method below, this waits for the CLTs exit and then returns the output of the CLT as well as an error
    /// TODO: Make this take an executablePath instead of an executableURL, because that makes it much easier to use with our constants like kMFLaunchctlPath
    
    
    /// Declare error if none is passed in
    ///     So we can still retrieve errors for internal logic and debug messages. Not sure about the __autoreleasing stuff.
    NSError *__autoreleasing localError;
    if (errorPtr == nil) {
        errorPtr = &localError;
    }
    
    /// Init pipes
    NSPipe *pipe = [NSPipe pipe];
    NSPipe *errorPipe = [NSPipe pipe];
    
    /// Init task
    NSTask *task = [[NSTask alloc] init];
    [task setExecutableURL: executableURL.absoluteURL];
    [task setArguments: arguments];
    [task setStandardOutput:pipe];
    [task setStandardError:errorPipe];
    
    /// Launch task and wait
    [task launchAndReturnError:errorPtr];
    [task waitUntilExit];
    
    /// Get Result
    
    NSString *result;
    
    if (*errorPtr != nil) {
        result = @"";
    } else {
        
        /// Get stdout
        NSFileHandle *output_fileHandle = [pipe fileHandleForReading];
        NSData *output_data = [output_fileHandle readDataToEndOfFile];
        NSString *output_string = [[NSString alloc] initWithData:output_data encoding:NSUTF8StringEncoding];
        
        /// Get stderr
        NSFileHandle *error_fileHandle = [errorPipe fileHandleForReading];
        NSData *error_data = [error_fileHandle readDataToEndOfFile];
        NSString *error_string = [[NSString alloc] initWithData:error_data encoding:NSUTF8StringEncoding];
        
        /// Process stdout
        if (output_string != nil) {
            result = output_string;
        } else {
            result = @"";
        }
        /// Process stderr
        if (error_string != nil && ![error_string isEqual:@""]) {
            *errorPtr = [NSError errorWithDomain:@"MFStderrDomain" code:0 userInfo:@{
                @"stderr": error_string,
            }];
        }
    }
    
    /// Debug
    if (runningPreRelease()) {
        NSString *errorDesc = @"";
        if (errorPtr != nil && *errorPtr != nil) {
            errorDesc = (*errorPtr).debugDescription;
        }
        DDLogDebug(@"Called command line tool at %@ with args: %@ - result: %@, error: %@", executableURL, arguments, result, errorDesc);
    }
    
    /// Return
    return result;
}

+ (void)launchCLT:(NSURL *)commandLineTool
         withArgs:(NSArray <NSString *> *)args {
        
    /// TODO: Think about when / why we're using this instead of the other launchCTL method. Should we really just ignore errors?
    
    DDLogDebug(@"Calling command line tool at %@ with args: %@ using async API", commandLineTool, args);
    
    [NSTask launchedTaskWithExecutableURL:commandLineTool arguments:args error:nil terminationHandler:nil];
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
    DDLogInfo(@"PRINTING STACK TRACE: %@", [NSThread callStackSymbols]);
}

+ (NSString *)currentDispatchQueueDescription {
    return dispatch_get_current_queue().description;
}

/// For debugging.
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
    
    DDLogInfo(@"%@: %d", strId, counterForId);
    
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

#pragma mark - Coordinate conversion

#pragma mark NSView frame conversion

/// See NSView+Additions

#pragma mark Flipping

/// The *cocoa*  global "display" coordinate system starts at the bottom left of the zero screen, while the *quartz* coordinate system starts at the top left
/// We sometimes need to convert between them
/// I've tried to write conversion functions before (Find them in HelperUtility) but I don't think they worked. I'll give it one more try. Edit: This works!

/// Convenience wrappers

+ (NSPoint)quartzToCocoaScreenSpace_Point:(CGPoint)quartzPoint {
    return [self quartzToCocoaScreenSpace:CGRectMake(quartzPoint.x, quartzPoint.y, 0, 0)].origin;
}

+ (CGPoint)cocoaToQuartzScreenSpace_Point:(NSPoint)cocoaPoint {
    return [self cocoaToQuartzScreenSpace:NSMakeRect(cocoaPoint.x, cocoaPoint.y, 0, 0)].origin;
}

+ (NSRect)quartzToCocoaScreenSpace:(CGRect)quartzFrame {
    return [self cocoaToQuartzScreenSpaceConversionWithOriginFrame:quartzFrame];
}
+ (CGRect)cocoaToQuartzScreenSpace:(NSRect)cocoaFrame {
    return [self cocoaToQuartzScreenSpaceConversionWithOriginFrame:cocoaFrame];
}

/// Base function

+ (CGRect)cocoaToQuartzScreenSpaceConversionWithOriginFrame:(CGRect)originFrame {
    
    /// Src: https://stackoverflow.com/questions/19884363/in-objective-c-os-x-is-the-global-display-coordinate-space-used-by-quartz-d
    
    /// Get zero screen
    NSScreen *zeroScreen = NSScreen.screens[0]; /// TODO: Simplify/optimize this: Use [NSScreen +_zeroScreenHeight]
    CGFloat screenHeight = zeroScreen.frame.size.height;
    
    /// Extract values
    CGFloat originY = originFrame.origin.y;
    CGFloat frameHeight = originFrame.size.height;
    
    /// Get new y
    CGFloat destinationY = screenHeight - (originY + frameHeight);
    
    /// Get new frame
    CGRect destinationFrame = originFrame;
    destinationFrame.origin.y = destinationY;
    
    /// return
    return destinationFrame;
}

#pragma mark - Deep copies

+ (id) deepMutableCopyOf: (id)object {
    
    /// NSPropertyListSerialization fails for our remapDict because we're using NSNumber as dictionary keys. CFPropertyListCreateDeepCopy doesn't work either.
    ///     So we're doing this manually...
    /// Edit: Doesn't NSPropertyListSerialization work? That can also create mutable containers. Maybe this is faster though.
        
    if ([object isKindOfClass:NSDictionary.class]) {
        ///
        /// Dict
        ///
        NSDictionary *og = (NSDictionary *)object;
        NSMutableDictionary *new = [NSMutableDictionary dictionary];
        [og enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull value, BOOL * _Nonnull stop) {
            id newKey = [SharedUtility deepMutableCopyOf:key];
            id newValue = [SharedUtility deepMutableCopyOf:value];
            new[newKey] = newValue;
        }];
        return new;
    } else if ([object isKindOfClass:NSArray.class]) {
        ///
        /// Array
        ///
        NSArray *og = (NSArray *)object;
        NSMutableArray *new = [NSMutableArray array];
        for (id element in og) {
            [new addObject:[SharedUtility deepMutableCopyOf:element]];
        }
        return new;
    } else {
        ///
        /// Leave node
        ///
        if ([object conformsToProtocol:@protocol(NSMutableCopying)]) {
            return [object mutableCopy];
        } else {
            return object;
        }
    }
}

+ (id)deepCopyOf:(id)object {

    /// TODO: Replace this with the error-returning implementation (below)
    
    /// Check nil
    if (object == nil) return nil;
    
    /// New approach
//    return [self deepCopyOf:object error:nil];
    
    /// Old approach
    return [NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:object]];
}

+ (id<NSCoding>)deepCopyOf:(id<NSCoding>)original error:(NSError *_Nullable *_Nullable)error {
    
    /// Copied this from the Swift implementation in SharedUtilitySwift, since the Swift implementation wasn't compatible with ObjC. We still like to keep both around since the Swift version is nicer with it's generic types. Maybe generics are also possible in this form in ObjC but I don't know how.
    /// The simpler default methods only work with `NSSecureCoding` objects. This implementation also works with `NSCoding` objects.
    /// Src:  https://developer.apple.com/forums/thread/107533
    /// Performance: This is actually superrrr slow. Was the old one this slow as well? Edit: I think the old one was also very slow.
    ///     Edit: [Feb 2025] I implemented a custom MFDeepCopyCoder but I could only make it 20% faster than the NSKeyedArchiver. Maybe NSKeyedArchver got faster, or keyed archiving/unarchiving of objc objects is just inherently slow?
    ///     Edit: [Feb 2025] Also, is manual recursion (Which we use in `deepMutableCopyOf:`) perhaps faster than an archiver? MFDeepCopyCoder was doing recursion like that afaik, so maybe not.
    /// TODO: Use MFEncode() and MFDecode() instead of this.
    
    assert(original != nil);
    
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:original requiringSecureCoding:false error:error];
    if (data == nil) {
        assert(false);
        return nil;
    }
    
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:error];
    unarchiver.requiresSecureCoding = false;
    
    id<NSCoding> copy = [unarchiver decodeObjectForKey:NSKeyedArchiveRootObjectKey];
    
    return copy;
}

#pragma mark - Other

+ (NSDictionary *)dictionaryWithOverridesAppliedFrom:(NSDictionary *)src to: (NSDictionary *)dst {
    
    // TODO: Consider returning a mutable dict to avoid constantly using `- mutableCopy`. Maybe even alter `dst` in place and return nothing (And rename to `applyOverridesFrom:to:`).
    /// Copy all leaves (elements which aren't dictionaries) from `src` to `dst`. Return the result. (`dst` itself isn't altered)
    /// Recursively search for leaves in `src`. For each srcLeaf found, create / replace a leaf in `dst` at a keyPath identical to the keyPath of srcLeaf and with the value of srcLeaf.
    
    NSMutableDictionary *dstMutable = [dst mutableCopy];
    if (dstMutable == nil) {
        dstMutable = [NSMutableDictionary dictionary];
    }
    for (id<NSCopying> key in src) {
        NSObject *dstVal = dst[key];
        NSObject *srcVal = src[key];
        if ([srcVal isKindOfClass: [NSDictionary class]] || [srcVal isKindOfClass: [NSMutableDictionary class]]) { // Not sure if checking for mutable dict AND dict is necessary
            /// Nested dictionary found. Recursing.
            NSDictionary *recursionResult = [self dictionaryWithOverridesAppliedFrom: (NSDictionary *)srcVal to: (NSDictionary *)dstVal];
            dstMutable[key] = recursionResult;
        } else {
            // Leaf found
            dstMutable[key] = srcVal;
        }
    }
    return dstMutable;
}

+ (int8_t) signOf: (double)x { /// TODO: Remove this in favor of sign(double x)
    return sign(x);
}
int8_t sign(double x) {
    return (0 < x) - (x < 0);
}

+ (void)setupBasicCocoaLumberjackLogging {
    
    /// Start logging to console and to Xcode output
    /// Call this at the entry point of an app, so that DDLog statements work.
    
    /// Need to enable Console.app > Action > Include Info Messages & Include Debug Messages to see these messages in Console. See https://stackoverflow.com/questions/65205310/ddoslogger-sharedinstance-logging-only-seems-to-log-error-level-logging-in-conso
    /// Will have to update instructions on Mac Mouse Fix Feedback Assistant when this releases.
    
    /// Use `os_log` backend for CocoaLumberjack.
    ///     Notes:
    ///     - This should log to console and terminal and be faster than the old methods.
    ///     - Specifying a subsystem and category allows us to configure logging using `Info.plist > OSLogPreferences`
    ///         > Also See: https://github.com/noah-nuebling/mac-mouse-fix-error-logging-improvement-ideas-october-2024?tab=readme-ov-file
    
    #define kMFOSLogSubsystem   @"com.nuebling.mac-mouse-fix"
    #define kMFOSLogCategory    @"main-category"
    DDOSLogger *logger = [[DDOSLogger alloc] initWithSubsystem: kMFOSLogSubsystem category: kMFOSLogCategory logLevelMapper: [[DDOSLogLevelMapperDefault alloc] init]];
    [DDLog addLogger: logger];
    
    /// Set logging format
    //    DDOSLogger.sharedInstance.logFormatter = DDLogFormatter.
    
    if ((NO) /*runningPreRelease()*/) {
        
        /// Setup logging  file
        /// Copied this from https://github.com/CocoaLumberjack/CocoaLumberjack/blob/master/Documentation/GettingStarted.md
        /// Haven't thought about whether the exact settings make sense.
        
        DDFileLogger *fileLogger = [[DDFileLogger alloc] init];
        fileLogger.rollingFrequency = 60 * 60 * 24; /// 24 hour rolling
        fileLogger.logFileManager.maximumNumberOfLogFiles = 2;
        
        [DDLog addLogger:fileLogger];
        
        DDLogInfo(@"Logging to directory: \'%@\'", fileLogger.logFileManager.logsDirectory);
    }
}

+ (void)resetDispatchGroupCount:(dispatch_group_t)group {
    /// Reset smoothing group counter to 0
    /// This doesn't work, don't use this.
    
    assert(false);
    
    /// Method 2
    
//    dispatch_group_wait(group, DISPATCH_TIME_NOW); /// Time out immediately to reset state. Doesn't work....
    
    /// Method 1 (kinda hacky and unstable method)
    
    NSString *groupDebugDescription = group.debugDescription;
    NSRange groupCountRange = [groupDebugDescription rangeOfString:@"(?<= count = ).*?(?=,)" options:NSRegularExpressionSearch];
    /// ^ Actual Regex for count (?<= count = ).*?(?=,)
    NSString *groupCountString = [groupDebugDescription substringWithRange:groupCountRange];
    NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
    numberFormatter.numberStyle = NSNumberFormatterDecimalStyle;
    int groupCount = [numberFormatter numberFromString:groupCountString].intValue;
    for (int i = 0; i < groupCount; i++) {
        dispatch_group_leave(group);
    }
}

@end
