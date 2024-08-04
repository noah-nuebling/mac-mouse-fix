//
// --------------------------------------------------------------------------
// AnnotationUtility.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//
#import "AnnotationUtility.h"
#import "SharedUtility.h"
@import AppKit;

@import ObjectiveC.runtime;
#import "dlfcn.h"
#import "objc/runtime.h"
#import "mach-o/dyld.h"
#import "Logging.h"

///
/// Utility functions copied over from the xcode-localization-screenshot-fix repo
///
/// Discussion:
///     These are general, powerful, utility functions, and we should probably move them to other files and delete this file eventually.
///

@implementation AnnotationUtility

#pragma mark - Swizzling

///
/// Swizzling Discussion:
///
/// Why use the `InterceptorFactory` pattern?
///     When swizzling, after your swizzled method (we call it the `interceptor`) is called, you normally always want to call the original implementation of the method which was intercepted.
///     The usual pattern for intercepting a method with name `-[methodName]`, is to define a method `-[swizzled_methodName]`, and then swap the implementations of the two.
///     However, this pattern won't let you reliably call the original implementation of the interceptor in more complicated cases.
///
///     For example, in the implementation of `swizzleMethodOnClassAndSubclasses()` this lead to infinite loops when swizzling a method whose original implementation calls the superclass implementation when we're also replacing that superclass implementation with the same interceptor.  (We deleted the detailed notes on that, I think in commit fc3064033f974c454aebb479f20bb0cc3d0eebb6 of the xcode-localization-screenshot-fix repo)
///
///     The only solution I could think of is to store a reference to the original implementation inside the function definition. That's what the interceptor factory does.
///     Use the MakeInterceptorFactory() macro to easily create an interceptor factory.
///
/// We're sort of re-implementing https://github.com/rabovik/RSSwizzle here, but without thread-saftey and some other features. (But with slightly simpler syntax and powerful subclass-swizzling)
///

void swizzleMethod(Class class, SEL selector, InterceptorFactory interceptorFactory) {
    
    /// Replaces the method for `selector` on `class` with the interceptor retrieved from the `interceptorFactory`.
    /// - Use the `MakeInterceptorFactor()` macro to conveniently create an interceptor factory.
    /// - Note on arg `class`:
    ///     Pass in a metaclass to swap out class methods instead of instance methods.
    ///     You can get the metaclass of a class `baseClass` by calling `object_getClass(baseClass)`.
    
    /// Log
    ///     We're using NSLog instead of DDLogInfo, since we're usually swizzling from a [+ load] method where DDLog isn't available, yet. (Need to call [Logging setUpDDLog] first)
    NSLog(@"Info: Swizzling [%s %s]", class_getName(class), sel_getName(selector));
    
    /// Validate
    ///     Make sure `selector` is defined on class or one of its superclasses.
    ///     Otherwise swizzling doesn't make sense.
    assert([class instancesRespondToSelector:selector]); /// Note: This seems to work as expected on meta classes
    
    /// Get original
    ///     Note: Based on my testing, we don't need to use `class_getClassMethod` to make swizzling class methods work, if we just pass in a meta class as `class`, then `class_getInstanceMethod` will get the class methods, and everything works as expected.
    Method originalMethod = class_getInstanceMethod(class, selector);
    IMP originalImplementation = method_getImplementation(originalMethod);
    
    /// Make sure originalMethod is present directly on `class`
    ///     (Instead of being inherited from a superclass -> So we're not replacing the implementation of the method from the superclass, affecting all its other subclasses.)
    BOOL didAddOriginal = class_addMethod(class, selector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
    if (didAddOriginal) { /// Re-fetch
        originalMethod = class_getInstanceMethod(class, selector);
    }
    
    /// Get interceptor implementation
    ///  Explanation:
    ///  We need to use the 'factory' pattern because this is the only way to reliably have the interceptor code find its original implementation.
    InterceptorBlock interceptorBlock = interceptorFactory(class, selector, originalImplementation);
    IMP interceptorImplementation = imp_implementationWithBlock(interceptorBlock);
    
    /// Replace implementation
    IMP previousImplementation = method_setImplementation(originalMethod, interceptorImplementation);
    
    /// Validate
    assert(previousImplementation == originalImplementation);
}

void swizzleMethodOnClassAndSubclasses(Class baseClass, NSDictionary<MFClassSearchCriterion, id> *subclassSearchCriteria, SEL selector, InterceptorFactory interceptorFactory) {

    /// Log
    NSLog(@"Info: Swizzling [%s %s] including subclasses. subclassSearchCriteria: %@ (Class is in %s)", class_getName(baseClass), sel_getName(selector), subclassSearchCriteria, class_getImageName(baseClass));
    
    /// Validate args
    assert(baseClass != nil);
    assert(interceptorFactory != nil);
    
    /// Preprocess classSearchCriteria
    assert([subclassSearchCriteria isKindOfClass:[NSDictionary class]]);
    NSMutableDictionary *classSearchCriteria = subclassSearchCriteria.mutableCopy;
    assert(classSearchCriteria[MFClassSearchCriterionSuperclass] == nil);
    classSearchCriteria[MFClassSearchCriterionSuperclass] = baseClass;
    
    /// Find subclasses
    NSArray<Class> *subclasses = searchClasses(classSearchCriteria);
    
    /// Declare validation state
    BOOL someClassHasBeenSwizzled = NO;
    
    /// Swizzle subclasses
    for (Class subclass in subclasses) {
        
        /// Skip
        ///     We only need to swizzle one method, and then all its subclasses will also be swizzled - as long as they inherit the method and don't override it.
        if (![subclass instancesRespondToSelector:selector]
            || classInheritsMethod(subclass, selector)) continue;
        
        /// Swizzle
        swizzleMethod(subclass, selector, interceptorFactory);
        someClassHasBeenSwizzled = YES;
    }
    
    /// Swizzle on baseClass
    ///     We (almost) always want to at least swizzle on the baseClass. Even if the baseClass, doesn't define it's own implementation for `selector`, and instead inherits the implementation.
    ///     That way all the subclasses inherit the swizzled method from the baseClass.
    ///     Except, if `baseClass` doesn't respond to the `selector` at all, then the 'most super implementation' of the method is in one of the subclasses, and we can skip swizzling `baseClass`.
    
    if ([baseClass instancesRespondToSelector:selector]) {
        swizzleMethod(baseClass, selector, interceptorFactory);
        someClassHasBeenSwizzled = YES;
    }
    
    /// Validate
    if (!someClassHasBeenSwizzled) {
        DDLogWarn(@"Error: Neither %@ nor any of the subclasses we found for it (%@) have been swizzled. This is probably because none of the processed classes implement a method for selector %s. We used the search criteria: %@", baseClass, subclasses, sel_getName(selector), subclassSearchCriteria);
        assert(false);
    }
    
}


#pragma mark - Runtime

NSString *getExecutablePath(void) {
    
    /// Get the path of the current executable.
    
    static uint32_t pathBufferSize = MAXPATHLEN; /// Make this static to store between invocations. For optimization, so we don't hit the fallback case over and over. Not sure if relevant.
    char *pathBuffer = malloc(pathBufferSize); if (pathBuffer == NULL) return NULL; /// ChatGPT and SO tells me to NULL-check my malloc, and that not doing it is "unsafe" and "bad programming". I'm annoyed because that seems extremely unnecessary, but ok.
    int ret = _NSGetExecutablePath(pathBuffer, &pathBufferSize);
    
    if (ret == -1) { /// Fallback case: If the buffer size is not large enough, the buffer size is set to the right value and the function returns -1
        free(pathBuffer);
        pathBuffer = malloc(pathBufferSize); if (pathBuffer == NULL) return NULL;
        ret = _NSGetExecutablePath(pathBuffer, &pathBufferSize);
        if (ret == -1) {
            assert(false);
            return NULL;
        }
    }
    
    NSString *result = [NSString stringWithCString:pathBuffer encoding:NSUTF8StringEncoding];
    free(pathBuffer);
    
    return result;
}

NSString *getImagePath(void *address) {
    
    /// Get the image path of an address.
    /// For example when the address comes from the AppKit framework, the result will be
    ///     `@"/System/Library/Frameworks/AppKit.framework/AppKit"`
    /// Pass in the address of a function and compare the result to `getExecutablePath()` to see if the function is defined inside the current executable (and not by a framework or library.)
    /// Particularly useful with `getReturnAddress()` to see if the caller of a function was a framework or the current app.
    
    Dl_info info;
    int ret = dladdr(address, &info);
    assert(ret != 0); /// 0 is failure code of dladrr()
    
    const char *imagePath = info.dli_fname;
    NSString *result = [NSString stringWithCString:imagePath encoding:NSUTF8StringEncoding];
    assert(result != nil);
    
    return result;
}

NSString *getSymbol(void *address) {
    
    /// Use this with getReturnAddress() to get the name of the calling function
    
    Dl_info info;
    int ret = dladdr(address, &info);
    assert(ret != 0); /// 0 is failure code of dladrr()
    
    const char *symbolName = info.dli_sname;
    NSString *result = [NSString stringWithCString:symbolName encoding:NSUTF8StringEncoding];
    assert(result != nil);
    
    return result;
}


NSArray<Class> *searchClasses(NSDictionary<MFClassSearchCriterion, id> *criteria) {
    
    /// Searches classes in the objc runtime by different criteria.
    ///     I think you should always at least specify a framework, otherwise might be relatively slow.
    ///     This is largely a wrapper around `objc_enumerateClasses()`
    ///
    /// Notes:
    /// - I just did some testing with `namePrefix` searchCriterion set to our class `LoggingSwift` and it doesn't seem to work (Summer 2024, macOS Sequoia Beta)
    /// - Benchmark: Finding a subclass defined in the current executable took 1.2ms (Summer 2024, macOS Sequoia Beta)
    ///     -> I wrote this for hacking, but I think it should be ok to use in our production code.
    /// - The `@"framework"` search criterion can be a name of a system framework such as "AppKit" or an absolute path to an image such as the `executablePath` of the current process, which will only search classes that were declared in the current executable. If The `@"framework"` is empty, all framworks in the runtime will be searched which can be slow but useful for hacking and exploring and stuff. The underlying `objc_enumerateClasses` searches the caller's image when passing in NULL but this class can only search the callers image by passing the callers executablePath to `objc_enumerateClasses`. Not sure if that's bad for performance. Now that we use this in production code, it would probably be better to define a special constant like `__mfall__` that searches all frameworks and have the null-case be to only search the callers image, just like `objc_enumerateClasses`. But honestly the performance impact is probably negligible.
    
    /// Validate
    assert([criteria isKindOfClass:[NSDictionary class]]);
    
    /// Extract criteria
    Protocol *protocol = criteria[MFClassSearchCriterionProtocol];
    Class baseClass = criteria[MFClassSearchCriterionSuperclass];
    NSString *namePrefixNS = criteria[MFClassSearchCriterionClassNamePrefix];
    NSString *frameworkNameNS = criteria[MFClassSearchCriterionFrameworkName];
    
    /// Map emptyString to nil
    if (namePrefixNS != nil && namePrefixNS.length == 0) {
        namePrefixNS = nil;
    }
    if (frameworkNameNS != nil && frameworkNameNS.length == 0) {
        frameworkNameNS = nil;
    }
    
    /// Validate
    /// - at least one criterion
    assert(protocol != nil || baseClass != nil || namePrefixNS != nil || frameworkNameNS != nil);
    
    /// Validate
    /// - no extra/misspelled criteria
    #if DEBUG
        NSMutableDictionary *criteriaMutable = criteria.mutableCopy;
        criteriaMutable[MFClassSearchCriterionProtocol] = nil;
        criteriaMutable[MFClassSearchCriterionSuperclass] = nil;
        criteriaMutable[MFClassSearchCriterionClassNamePrefix] = nil;
        criteriaMutable[MFClassSearchCriterionFrameworkName] = nil;
        assert(criteriaMutable.count == 0);
    #endif
    
    /// Preprocess namePrefix
    ///     -> Convert it to c string
    const char *namePrefix = NULL;
    if (namePrefixNS) {
        namePrefix = [namePrefixNS cStringUsingEncoding:NSUTF8StringEncoding];
    }
    
    /// Preprocess frameworkName
    ///     -> Get framework paths
    
    unsigned int frameworkCount;
    const char **frameworkPaths = NULL;
    
    if (frameworkNameNS != nil) {
        const char *frameworkName = [frameworkNameNS cStringUsingEncoding:NSUTF8StringEncoding]; /// `char *` wil never be empty bc we map empty NSString to nil above.
        const char *frameworkPath = searchFrameworkPath(frameworkName);
        frameworkPaths = malloc(sizeof(char *)); /// We malloc here to keep memory situation symmetrical with the `objc_copyImageNames()` call.
        *frameworkPaths = frameworkPath;
        frameworkCount = 1;
    } else {
        /// If the caller hasn't specified a framework, get *all* the frameworks.
        ///     There are 46977 classes in all the frameworks, but it's still quite fast, especially with the macOS 13.0+ implementation.
        frameworkPaths = objc_copyImageNames(&frameworkCount);
    }
    
    /// Get framework handles from framework paths
    void *frameworkHandles[frameworkCount];
    for (int i = 0; i < frameworkCount; i++) {
        const char *frameworkPath = frameworkPaths[i];
        frameworkHandles[i] = dlopen(frameworkPath, RTLD_LAZY | RTLD_GLOBAL); /// Maybe we could/should use `RTLD_NOLOAD` here for better performance?
        if (frameworkHandles[i] == NULL) {
            NSLog(@"Error: dlopen failed to open framework at path %s with error %s", frameworkPath, dlerror());
            assert(false);
        }
        assert(frameworkHandles[i] != NULL);
    }
    
    /// Find classes
    NSMutableArray *result = [NSMutableArray array];
    
    for (int i = 0; i < frameworkCount; i++) {
            
        if (frameworkHandles[i] == NULL) continue;
        
        if (@available(macOS 13.0, *)) {
            objc_enumerateClasses(frameworkHandles[i], namePrefix, protocol, baseClass, ^(Class _Nonnull aClass, BOOL * _Nonnull stop) {
                [result addObject:aClass];
            });
        } else {
            unsigned int classCount;
            const char **classNames = objc_copyClassNamesForImage(frameworkPaths[i], &classCount);
            for (int i = 0; i < classCount; i++) {
                Class class = objc_getClass(classNames[i]);
                bool hasNamePrefix      = namePrefix == NULL ? true :   strncmp(namePrefix, classNames[i], strlen(namePrefix)) == 0;
                bool conformsToProtocol = protocol == nil ? true :      class_conformsToProtocol(class, protocol);
                bool isSubclass         = baseClass == nil ? true :     classIsSubclass(class, baseClass) && class != baseClass; /// Filter out baseClass since that's how `objc_copyClassNamesForImage()` works.
                if (hasNamePrefix && conformsToProtocol && isSubclass) {
                    [result addObject:class];
                }
            }
            free(classNames);
        }
    }
    
    /// Release stuff
    free(frameworkPaths);
    for (int i = 0; i < frameworkCount; i++) {
        dlclose(frameworkHandles[i]);
    }
    
    /// Return
    return result;
}

const char *searchFrameworkPath(const char *frameworkName) {
    
    /// Can't get dlopen to find any frameworks without hardcoding the path, so we're making our own framework searcher
    /// 
    /// Update: I just found this in the dlopen docs which explains the problem: (our app was codesigned with entitlements.)
    ///   "Note: If the main executable is a set[ug]id binary or codesigned with
    ///   entitlements, then all environment variables are ignored, and only a full
    ///   path can be used."
    
    /// If frameworkName looks like an absolute path, then return it verbatim
    if (frameworkName[0] == '/') { /// This crashes if we pass an empty name
        return frameworkName;
    }
    
    /// Preprocess framework name
    char *frameworkSubpath = NULL;
    asprintf(&frameworkSubpath, "%s.framework/%s", frameworkName, frameworkName);
    
    /// Define constants
    const char *frameworkSearchPaths[] = {
        "/System/Library/Frameworks",
        "/System/Library/PrivateFrameworks",
        "/Library/Frameworks",
    };
    
    /// Search for the framework
    const char *result = NULL;
    for (int i = 0; i < sizeof(frameworkSearchPaths)/sizeof(char *); i++) {
        
        const char *frameworkSearchPath = frameworkSearchPaths[i];
        
        char *frameworkPath;
        asprintf(&frameworkPath, "%s/%s", frameworkSearchPath, frameworkSubpath);
        
        void *handle = dlopen(frameworkPath, RTLD_LAZY | RTLD_GLOBAL); /// Should we use `RTLD_NOLOAD`? Not sure about the option flags.
        
        bool frameworkWasFound = handle != NULL;
        if (frameworkWasFound) {
            int closeRet = dlclose(handle);
            if (closeRet != 0) {
                char *error = dlerror();
                DDLogError(@"dlclose failed with error %s", error);
                assert(false);
            }
        }
        
        if (frameworkWasFound) {
            result = frameworkPath;
            break;
        }
    }
    
    /// Return frameworkPath
    if (result != NULL) {
        return result;
    }
    
    ///
    /// Fallback: objc runtime
    ///
    
    /// Not sure this is even slower than the main approach. (If not then this should be the main approach) Should be more robust than the main approach though.
    
    char *frameworkSubpath2 = NULL; /// Why are we using another subpath: When using dlopen `...AppKit.framework/AppKit` works, but in the objc imageNames `...AppKit.framework/Versions/C/AppKit` appears.
    asprintf(&frameworkSubpath2, "%s.framework", frameworkName);
    
    unsigned int imageCount;
    const char **imagePaths = objc_copyImageNames(&imageCount); /// The API is called imageNames, but it returns full framework paths from what I can tell.
    
    for (int i = 0; i < imageCount; i++) {
        const char *imagePath = imagePaths[i];
        bool frameworkSubpathIsInsideImagepath = strstr(imagePath, frameworkSubpath2) != NULL;
        if (frameworkSubpathIsInsideImagepath) {
            result = imagePath;
            break;
        }
    }
    
    free(imagePaths);
    
    if (result == NULL) {
        DDLogWarn(@"Error: Couldn't find framework with name %s", frameworkName);
        assert(false);
    }
    return result;
    
}


bool classInheritsMethod(Class class, SEL selector) {
    
    /// Returns YES if the class inherits the method for `selector` from its superclass, instead of defining its own implementation.
    /// Note: Also see `class_copyMethodList`
    
    /// Main check
    Method classMethod = class_getInstanceMethod(class, selector);
    Method superclassMethod = class_getInstanceMethod(class_getSuperclass(class), selector);
    bool classInherits = classMethod == superclassMethod;
    
    /// ?
    assert(classMethod != NULL); /// Not sure if this is good or necessary
    
    /// Return
    return classInherits;
}

bool classIsSubclass(Class potentialSub, Class potentialSuper) {
    
    /// `isSubclassOfClass:` sometimes crashes. I think sending a message to the class might have sideeffects, so we're building a pure c implementation.
    /// This also returns true, if the two classes are the same (just like `isSubclassOfClass:`)
    
    while (true) {
            
        if (potentialSub == potentialSuper) {
            return true;
        }
        potentialSub = class_getSuperclass(potentialSub);
        
        if (potentialSub == NULL) {
            break;
        }
    }
    
    return false;
}

#pragma mark - Recursions

#define MFRecursionCounterBaseKey @"MFRecursionCounterBaseKey"

void countRecursions(id recursionDepthKey, void (^workload)(NSInteger recursionDepth)) {
    NSInteger depth = recursionCounterBegin(recursionDepthKey);
    workload(depth);
    recursionCounterEnd(recursionDepthKey);
}

NSMutableDictionary *_recursionCounterDict(void) {
    /// Get/init base dict
    NSMutableDictionary *counterDict = NSThread.currentThread.threadDictionary[MFRecursionCounterBaseKey];
    if (counterDict == nil) {
        counterDict = [NSMutableDictionary dictionary];
        NSThread.currentThread.threadDictionary[MFRecursionCounterBaseKey] = counterDict;
    }
    return counterDict;
}

NSInteger recursionCounterBegin(id key) {
    NSMutableDictionary *counterDict = _recursionCounterDict();
    NSInteger recursionDepth = [counterDict[key] integerValue]; /// This resolves to 0 if `counterDict[key]` is nil
    counterDict[key] = @(recursionDepth + 1);
    return recursionDepth;
    
}

void recursionCounterEnd(id key) {
    NSMutableDictionary *counterDict = _recursionCounterDict();
    NSInteger recursionDepth = [counterDict[key] integerValue];
    assert(recursionDepth > 0);
    counterDict[key] = @(recursionDepth - 1);
}

void _recursionSwitch(id selfKey, SEL _cmdKey, void (^onFirstRecursion)(void), void (^onOtherRecursions)(void)) {
    
    assert(false);
    
    id key = stringf(@"%p|%s", selfKey, sel_getName(_cmdKey));
    
    countRecursions(key, ^(NSInteger recursionDepth) {
        if (recursionDepth == 0) {
            onFirstRecursion();
        } else {
            onOtherRecursions();
        }
    });
}

#pragma mark - Parse format strings

NSRegularExpression *formatSpecifierRegex(void) {
    
    /// Regex pattern that matches format specifiers such as %d in format strings.
    /// Notes:
    /// - \ and % are doubled to escape them in the string literal.
    ///     Update: Removed doubling on % as I don't think that's necessary.
    /// - Matches escaped percent `%%` inside the `escaped_percent` capture group.
    ///     The content of this group is **not** part of a format specifier, and needs to be filtered out by the client.
    /// - Based on this regex101 pattern: https://regex101.com/r/lu3nWp/
    ///     Not sure this was the best way to translate the pattern. We had to remove the `(?<groupnames>)` and add `(?#comments)` instead.
    
    NSString *pattern =
    @"%"
    "("
        "(?:((?#<argument_position>)[1-9]\\d*)\\$)?"
        "("
            /// Integer specifiers (d, i, o, u, x, X)
            "((?#<flags>)[-'+ #0]*)?"
            "((?#<width>)\\*|\\d*)?"
            "(?:\\.((?#<precision>)\\*|\\d+))?"
            "((?#<length>)(?:hh|h|l|ll|j|z|t|q))?"
            "((?#<type>)[diouxX])"
            "|"  /// Floating point specifiers (f, F, e, E, g, G, a, A)
            "((?#<flags>)[-'+ #0]*)?"
            "((?#<width>)\\*|\\d*)?"
            "(?:\\.((?#<precision>)\\*|\\d+))?"
            "((?#<length>)(?:l|L|q))?"
            "((?#<type>)[fFeEgGaA])"
            "|"  /// String specifiers (s, ls, S)
            "((?#<flags>)[-]?)?"
            "((?#<width>)\\*|\\d*)?"
            "(?:\\.((?#<precision>)\\*|\\d+))?"
            "((?#<type>)(?:s|ls|S))"
            "|"  /// Character specifiers (c, lc, C)
            "((?#<flags>)[-]?)?"
            "((?#<width>)\\*|\\d*)?"
            "((?#<type>)(?:c|lc|C))"
            "|"  /// Pointer specifier
            "((?#<flags>)[-]?)?"
            "((?#<width>)\\*|\\d*)?"
            "((?#<type>)[p])"
            "|"  /// objc object specifier
            "((?#<flags>)[-]?)?"
            "((?#<width>)\\*|\\d*)?"
            "((?#<type>)[@])"
            "|"  /// Written-byte counter specifier
            "((?#<type>)[n])"
        ")"
    ")"
    "|"  /// Escaped percent sign (%%)
    "((?#<escaped_percent>)%%)";

    
    NSRegularExpressionOptions options = 0;
    NSError *error;
    NSRegularExpression *regex = [[NSRegularExpression alloc] initWithPattern:pattern options:options error:&error];
    if (error != nil) {
        DDLogError(@"Failed to create formatSpeciferRegex. Error: %@", error);
        assert(false);
    }
    
    return regex;
}

NSRegularExpression *formatStringRecognizer(NSString *localizedString) {
    
    /// TODO: FIX BUG: This function will treat escaped percent (%%) like a format specifer and replace it with with `.*`which is wrong.
    
    /// Turn the localizedString into a matching pattern
    ///     By replacing format specifiers (e.g. `%d`) inside the localizedString with insertion point `.*?`.
    ///     This matching pattern should match any ui strings that are composed of the localized string.
    /// Note: The notes and variable names are all about localizedStrings, but this should work on any c-style format string.
    
    NSRegularExpression *specifierRegex = formatSpecifierRegex();
    NSString *localizedStringPattern = [NSRegularExpression escapedPatternForString:localizedString];
    NSString *insertionPoint = [NSRegularExpression escapedTemplateForString:@"(.*?)"]; /// Escaping this doesn't seem to do anything.
    NSMatchingOptions matchingOptions = NSMatchingWithoutAnchoringBounds; /// Make $ and ^ work as normal chars inside the `formatSpecifierRegex` (because the 1$ `argument_position` format syntax uses $)
    localizedStringPattern = [specifierRegex stringByReplacingMatchesInString:localizedStringPattern options:matchingOptions range:NSMakeRange(0, localizedString.length) withTemplate:insertionPoint];
    
    /// Make it so the pattern must match the entire string
    ///     and capture everything except the literal chars from the localizedString inside the insertionPoint groups.
    localizedStringPattern = [NSString stringWithFormat:@"^%@%@%@$", insertionPoint, localizedStringPattern, insertionPoint];
    
    /// Create regex
    ///     From new matching pattern
    NSRegularExpressionOptions regexOptions = NSRegularExpressionDotMatchesLineSeparators   /** Strings in insertion points might have linebreaks - still match those */
                                                | NSRegularExpressionCaseInsensitive        /** The localizedString might have been case-transformed - still match it */
                                                | NSRegularExpressionUseUnixLineSeparators; /** Turn off line separators from foreign platforms, since we're working with macOS localized strings. Not sure if necessary */
    NSError *error;
    NSRegularExpression *resultRegex = [NSRegularExpression regularExpressionWithPattern:localizedStringPattern options:regexOptions error:&error];
    if (error != nil) {
        DDLogError(@"Failed to create recognizer regex for localized string %@. Error: %@", localizedString, error);
        assert(false);
    }
    
    /// Validate
    ///     Check that the regex needs at least some literal content to match. Not sure what I'm doing.
    assert([resultRegex firstMatchInString:@"" options:0 range:NSMakeRange(0, @"".length)] == nil);
    assert([resultRegex firstMatchInString:@" " options:0 range:NSMakeRange(0, @" ".length)] == nil);
    
    /// Return
    return resultRegex;
}

#pragma mark - objc inspection

Class getClass(id objOrCls) {
    
    /// Get class for object
    Class cls;
    if (object_isClass(objOrCls)) {
        cls = objOrCls;
    } else {
        cls = object_getClass(objOrCls);
    }
    
    /// Return
    return cls;
}

NSArray<Class> *getSuperClasses(id obj) {
    
    /// Get class for object
    Class cls = getClass(obj);

    /// Iterate superclasses
    NSMutableArray *result = [NSMutableArray array];
    while (true) {
        cls = class_getSuperclass(cls);
        if (cls == nil) break;
        [result addObject:cls];
    }
    
    /// Return
    return result;
}

Class getMetaClass(id obj) { /// I read that `objc_getMetaClass()` doesn't work reliably and you should use `object_getClass()` instead. This is a wrapper a around that.
    Class cls = getClass(obj);
    Class metaClass = object_getClass(cls);
    return metaClass;
}
NSString *listSuperClasses(id obj) {
    
    NSMutableString *result = [NSMutableString string];
    
    [result appendFormat:@"SuperClasses for %@:\n", stringFromClass([obj class])];
    
    NSArray<Class> *superclasses = getSuperClasses(obj);
    for (Class cls in superclasses) {
        [result appendFormat:@"    %@\n", stringFromClass(cls)];
    }
    
    return result;
}
NSString *listMethods(id obj) {
    return _listMethods(obj, [NSMutableArray array]);
}

NSString *stringFromClass(id obj) {
    
    /// Use this for printing over NSStringFromClass() to differentiate meta-classes.
    
    Class class = getClass(obj);
    bool isMeta = class_isMetaClass(class);
    NSString *result = [NSString stringWithFormat:@"%@%@", isMeta ? @"meta_" : @"", NSStringFromClass(class)];
    
    return result;
}

NSString *_listMethods(id obj, NSMutableArray<Class> *subclassPath) {
    
    /// This method prints a list of all methods defined on a class
    ///     with decoded return types and argument types!
    ///     This is really handy for creating categories, swizzles, or inspecting private classes.
    
    /// Get class
    Class cls = getClass(obj);
    
    /// Declare result
    NSMutableString *result = [NSMutableString string];
    
    /// Add header
    if (subclassPath.count == 0) {
        [result appendFormat:@"\nMethods for '%@':\n\n", stringFromClass(cls)];
    } else {
        NSMutableString *subclassPathString = [NSMutableString string];
        int i = 0;
        for (Class subclass in [subclassPath reverseObjectEnumerator]) {
            if (i != 0) [subclassPathString appendString:@" > "];
            [subclassPathString appendString:stringFromClass(subclass)];
            i++;
        }
        [result appendFormat:@"\nMethods for %lu. superclass '%@' (> %@):\n\n", (unsigned long)subclassPath.count, stringFromClass(obj), subclassPathString];
    }
    
    if ((cls == [NSObject class] || cls == getMetaClass([NSObject class])) && subclassPath.count > 0) {
        /// Skip NSObject
        [result appendString:@"    <...>\n"];
    } else {
        /// Add method descriptions
        unsigned int methodCount = 0;
        Method *methods = class_copyMethodList(cls, &methodCount);
        for (unsigned int i = 0; i < methodCount; i++) {
            Method method = methods[i];
            NSString *methodHeader = methodDescription(method);
            [result appendFormat:@"    %@\n", methodHeader];
        }
        free(methods);
    }
    
    /// Add superclass methods (recursive)
    Class superclass = class_getSuperclass(cls);
    if (superclass != nil) {
        [subclassPath addObject:cls];
        NSString *recursiveResult = _listMethods(superclass, subclassPath);
        [result appendFormat:@"%@\n", recursiveResult];
    }
    
    /// Return
    return result;
}

NSString *blockDescription(id block) {
    
    /// Returns the decoded method signature of an objc block
    
    const char *typeEncoding = blockTypeEncoding(block);
    NSString *result = _methodDescription(@"(^)", typeEncoding);
    return result;
}

static const char *blockTypeEncoding(id blockObj) {
    
    /// Copied from: https://stackoverflow.com/a/10944983/10601702
    
    struct BlockDescriptor {
        unsigned long reserved;
        unsigned long size;
        void *rest[1];
    };

    struct Block {
        void *isa;
        int flags;
        int reserved;
        void *invoke;
        struct BlockDescriptor *descriptor;
    };
    
    struct Block *block = (__bridge void *)blockObj;
    struct BlockDescriptor *descriptor = block->descriptor;

    int copyDisposeFlag = 1 << 25;
    int signatureFlag = 1 << 30;

    assert(block->flags & signatureFlag);

    int index = 0;
    if(block->flags & copyDisposeFlag)
        index += 2;

    return descriptor->rest[index];
}

NSString *methodDescription(Method method) {
    
    SEL selector = method_getName(method);
    const char *typeEncoding = method_getTypeEncoding(method);
    NSString *result = _methodDescription(NSStringFromSelector(selector), typeEncoding);
    return result;
}

NSString *_methodDescription(NSString *methodName, const char *typeEncoding) {
    
    NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:typeEncoding];
    const char *returnType = [signature methodReturnType];
    long nOfArgs = [signature numberOfArguments];
    NSMutableArray *argTypes = [NSMutableArray array];
    for (int i = 2; i < nOfArgs; i++) { /// Start at 2 to skip the `self` and `_cmd` args
        const char *argType = [signature getArgumentTypeAtIndex:i];
        [argTypes addObject:typeNameFromEncoding(argType)];
    }
    
    NSString *fullMethodHeader = [NSString stringWithFormat:@"(%@)%@ (%@)", typeNameFromEncoding(returnType), methodName, [argTypes componentsJoinedByString:@", "]];
    
    return fullMethodHeader;
}

NSString *typeNameFromEncoding(const char *typeEncoding) { /// Credit ChatGPT & Claude
    
    NSMutableString *typeName = [NSMutableString string];
    NSUInteger index = 0;
    
    /// Handle type qualifiers
    while (typeEncoding[index] && strchr("rnNoORV^", typeEncoding[index])) {
        switch (typeEncoding[index]) {
            case 'r': [typeName appendString:@"const "]; break;
            case 'n': [typeName appendString:@"in "]; break;
            case 'N': [typeName appendString:@"inout "]; break;
            case 'o': [typeName appendString:@"out "]; break;
            case 'O': [typeName appendString:@"bycopy "]; break;
            case 'R': [typeName appendString:@"byref "]; break;
            case 'V': [typeName appendString:@"oneway "]; break;
            case '^': [typeName appendString:@"pointer "]; break;
        }
        index++;
    }
    
    /// Handle base type
    NSString *baseTypeName;
    switch (typeEncoding[index]) {
        case 'c': baseTypeName = @"char"; break;
        case 'i': baseTypeName = @"int"; break;
        case 's': baseTypeName = @"short"; break;
        case 'l': baseTypeName = @"long"; break;
        case 'q': baseTypeName = @"long long"; break;
        case 'C': baseTypeName = @"unsigned char"; break;
        case 'I': baseTypeName = @"unsigned int"; break;
        case 'S': baseTypeName = @"unsigned short"; break;
        case 'L': baseTypeName = @"unsigned long"; break;
        case 'Q': baseTypeName = @"unsigned long long"; break;
        case 'f': baseTypeName = @"float"; break;
        case 'd': baseTypeName = @"double"; break;
        case 'B': baseTypeName = @"bool"; break;
        case 'v': baseTypeName = @"void"; break;
        case '*': baseTypeName = @"char *"; break;
        case '@': baseTypeName = @"id"; break;
        case '#': baseTypeName = @"Class"; break;
        case ':': baseTypeName = @"SEL"; break;
        case '[': baseTypeName = @"array"; break;
        case '{': baseTypeName = @"struct"; break;
        case '(': baseTypeName = @"union"; break;
        case 'b': baseTypeName = @"bit field"; break;
        case '?': baseTypeName = @"unknown"; break;
        default:
            NSLog(@"Error: typeEncoding: %s is unknown", typeEncoding);
            assert(false);
    }
    index++;
    
    /// Handle objc blocks (encoded as @?)
    if (index <= (strlen(typeEncoding) - 1) && typeEncoding[index-1] == '@' && typeEncoding[index] == '?') {
        baseTypeName = @"^block";
        index++;
    }
    
    /// Build result
    [typeName appendString:baseTypeName];
    
    if (index <= (strlen(typeEncoding) - 1)) {
        /// Output any unhandled type information
        NSString *fullTypeEncoding = [NSString stringWithUTF8String:typeEncoding];
        return [NSString stringWithFormat:@"%@ [%@]", typeName, fullTypeEncoding];
    } else {
        return typeName;
    }
}


@end
