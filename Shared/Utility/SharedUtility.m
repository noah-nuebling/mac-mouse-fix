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
#import "Config.h"
#import "Config.h"
#import "SharedUtility.h"
@import AppKit.NSScreen;
#import <objc/runtime.h>

@implementation SharedUtility

#pragma mark - Catch NSException in Swift

NSException * _Nullable tryCatch(void (^tryBlock)(void)) {
    /// Src: https://stackoverflow.com/a/32991585/10601702
    ///     Haven't tested this.
    
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

#pragma mark - Get display under pointer

+ (CVReturn)displayUnderMousePointer:(CGDirectDisplayID *)dspID withEvent:(CGEventRef _Nullable)event {
    
    /// Get event
    if (event == NULL) {
        event = CGEventCreate(NULL);
    }
    /// Get mouse location
    CGPoint mouseLocation = CGEventGetLocation(event);
    
    /// Return
    return [self display:dspID atPoint:mouseLocation];
    
}

+ (CVReturn)display:(CGDirectDisplayID *)dspID atPoint:(CGPoint)point {
    /// Pass in a CGEvent to get pointer location from. Not sure if signification optimization
    
    /// Get display
    CGDirectDisplayID *newDisplaysUnderMousePointer = malloc(sizeof(CGDirectDisplayID));
    uint32_t matchingDisplayCount;
    uint32_t maxDisplays = 1;
    CGGetDisplaysWithPoint(point, maxDisplays, newDisplaysUnderMousePointer, &matchingDisplayCount);
    
    if (matchingDisplayCount == 1) {
        
        /// Get the the master display in case _displaysUnderMousePointer[0] is part of a mirror set
        CGDirectDisplayID d = CGDisplayPrimaryDisplay(newDisplaysUnderMousePointer[0]);
        /// Output
        *dspID = d;
        return kCVReturnSuccess;
        
    } else if (matchingDisplayCount == 0) {
        
        /// Failure output
        DDLogWarn(@"There are 0 diplays under the mouse pointer");
        dspID = NULL;
        return kCVReturnError;
        
    } else {
        assert(false);
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

static void iteratePropertyLikeMethods(id obj, void(^callback)(Method method, struct objc_method_description *description, id value, BOOL *stop)) {
    
    /// This can cause leaks. See https://stackoverflow.com/questions/7017281/performselector-may-cause-a-leak-because-its-selector-is-unknown
    ///     -> I think the iterateIvars function can also cause leaks in the same way.
    
    iterateMethodsOn(obj, ^(Method method, struct objc_method_description *description, BOOL *stop) {
        
        /// Check if last char is `:` to see if method has arguments
        SEL sel = description->name;
        const char *name = sel_getName(sel);
        unsigned long len = strlen(name);
        char lastChar = name[len-1];
        if (lastChar == ':') return;
        id value = [obj performSelector:sel];
        if (value == nil) return;
        callback(method, description, value, stop);
    });
}

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

+ (BOOL)runningPreRelease {
    
    BOOL runningPrerelease;
    
    /// This is a pretty crude way of checking whether this is a pre-release, but it should work for now
#if DEBUG 
    runningPrerelease = YES;
#else
    runningPrerelease = NO;
#endif
    
    return runningPrerelease;
}

#pragma mark - Check which executable is running
/// TODO: Maybe move this to `Locator.m`

+ (BOOL)runningMainApp {
    
    /// Return YES if called by main app
    ///     Note: Could also use compiler flags `IS_MAIN_APP` and `IS_HELPER` to speed this up.
    return [NSBundle.mainBundle.bundleIdentifier isEqual:kMFBundleIDApp];
}
+ (BOOL)runningHelper {
    
    /// Return YES if called by helper app
    return [NSBundle.mainBundle.bundleIdentifier isEqual:kMFBundleIDHelper];
}
+ (BOOL)runningAccomplice {
    
    /// Return YES if called by accomplice
    return [NSFileManager.defaultManager isExecutableFileAtPath:[NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:kMFAccompliceName]];
}

#pragma mark - Use command-line tools

/// This returns the output of the CLT, in contrast to the other `launchCLT` function further down
+ (NSString *)launchCLT:(NSURL *)executableURL withArguments:(NSArray<NSString *> *)arguments error:(NSError ** _Nullable)error {
    
    NSPipe * launchctlOutput = [NSPipe pipe];
    
    if (@available(macOS 10.13, *)) { // macOS version 10.13+
        
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
    
    if (@available(macOS 10.13, *)) {
        
        [NSTask launchedTaskWithExecutableURL:commandLineTool arguments:args error:nil terminationHandler:nil];
        
    } else { /// Fallback on earlier versions
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

/// The *cocoa*  global "display" coordinate system starts at the bottom left of the main screen, while the *quartz* coordinate system starts at the top left
/// We sometimes need to convert between them
/// I've tried to write conversion functions before (Find them in HelperUtility) but I don't think they worked. I'll give it one more try:

/// Convenience wrappers

+ (NSPoint)quartzToCocoaScreenSpace_Point:(CGPoint)quartzPoint {
    return [self quartzToCocoaScreenSpace:CGRectMake(quartzPoint.x, quartzPoint.y, 0, 0)].origin;
}

+ (CGPoint)cocoaToQuartzScreenSpace_Point:(NSPoint)cocoaPoint {
    return [self cocoaToQuartzScreenSpace:NSMakeRect(cocoaPoint.x, cocoaPoint.y, 0, 0)].origin;
}

+ (NSRect)quartzToCocoaScreenSpace:(CGRect)quartzFrame {
    return [self cocoaToQuartzScreenSpaceConversionWithOriginFrame:quartzFrame destinationIsCocoa:YES];
}
+ (CGRect)cocoaToQuartzScreenSpace:(NSRect)cocoaFrame {
    return [self cocoaToQuartzScreenSpaceConversionWithOriginFrame:cocoaFrame destinationIsCocoa:NO];
}

/// Base function

+ (CGRect)cocoaToQuartzScreenSpaceConversionWithOriginFrame:(CGRect)originFrame destinationIsCocoa:(BOOL)toCocoa {
    
    /// Src: https://stackoverflow.com/questions/19884363/in-objective-c-os-x-is-the-global-display-coordinate-space-used-by-quartz-d
    
    /// Get main screen
    NSScreen *zeroScreen = NSScreen.screens[0];
    CGFloat screenHeight = zeroScreen.frame.size.height;
    
    /// Get other
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

#pragma mark - Other

+ (id)deepMutableCopyOf:(id)object {
    /// NSPropertyListSerialization fails because we're using NSNumber as dictionary keys. CFPropertyListCreateDeepCopy doesn't work either.
    ///     So we're doing this manually...
        
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
            /// Nested dictionary found. Recursing.
            NSDictionary *recursionResult = [self dictionaryWithOverridesAppliedFrom:(NSDictionary *)srcVal to:(NSDictionary *)dstVal];
            dstMutable[key] = recursionResult;
        } else {
            // Leaf found
            dstMutable[key] = srcVal;
        }
    }
    return dstMutable;
}

+ (int8_t)signOf:(double)x { /// TODO: Remove this in favor of sign(double x)
    return sign(x);
}
int8_t sign(double x) {
    return (0 < x) - (x < 0);
}

// Start logging to console and to Xcode output
// Call this at the entry point of an app, so that DDLog statements work.
+ (void)setupBasicCocoaLumberjackLogging {
    
    if (@available(macOS 10.12, *)) {
        [DDLog addLogger:DDOSLogger.sharedInstance]; // Use os_log // This should log to console and terminal and be faster than the old methods
            // Need to enable Console.app > Action > Include Info Messages & Include Debug Messages to see these messages in Console. See https://stackoverflow.com/questions/65205310/ddoslogger-sharedinstance-logging-only-seems-to-log-error-level-logging-in-conso
            // Will have to update instructions on Mac Mouse Fix Feedback Assistant when this releases.
    } else {
        // Fallback on earlier versions
        [DDLog addLogger:DDASLLogger.sharedInstance]; // Log to Apple System Log (Console.app)
        [DDLog addLogger:DDTTYLogger.sharedInstance]; // Log to terminal / Xcode output
    }
    
    /// Set logging format
//    DDOSLogger.sharedInstance.logFormatter = DDLogFormatter.
    
    /// Setup logging  file
    /// Copied this from https://github.com/CocoaLumberjack/CocoaLumberjack/blob/master/Documentation/GettingStarted.md
    /// Haven't thought about whether the exact settings make sense.
#if DEBUG
    DDFileLogger *fileLogger = [[DDFileLogger alloc] init];
    fileLogger.rollingFrequency = 60 * 60 * 24; // 24 hour rolling
    fileLogger.logFileManager.maximumNumberOfLogFiles = 2;

    [DDLog addLogger:fileLogger];
    
    DDLogInfo(@"Logging to directory: %@", fileLogger.logFileManager.logsDirectory);
#endif
}

+ (NSString *)binaryRepresentation:(unsigned int)value {
    
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
