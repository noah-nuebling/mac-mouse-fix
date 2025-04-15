//
//  ObserveSelf.m
//  objc-test-july-13-2024
//
//  Created by Noah Nübling on 01.08.24.
//

#import "KVOMutationSupport.h"
#import "objc/runtime.h"

///
/// This code makes mutable objects send a KVO value-change-notification for the keyPath `self` when they are mutated.
///
/// Update: [Apr 2025]
///     I haven't tested this much, I'm not sure this is safe.
///     E.g. – we isa swizzle – will there be interference if multiple modules try to isa-swizzle the object? (IIRC KVO will also isa-swizzle if automaticallyNotifiesObserversForKey: returns YES.)

@implementation NSObject (MFKVOMutationSupport)

///
/// Interface
///

/// TODO: Create separate categories for each supported class instead of affecting all NSObject subclasses.

- (void)notifyOnMutation:(BOOL)doNotify {
    toggleMutationNotifications(self, doNotify);
}

///
/// Core C-implementation
///

void toggleMutationNotifications(NSObject *object, BOOL turnOn) {
    
    /// This is `isa-swizzling` I think.
    ///     Synchronizing to prevent any possible race conditions on `object_setClass`
    ///     Update: All calls from the public interface go through here so if we only sync this we should be fine.
    
    @synchronized (object) {
        
        if (turnOn) {
            Class notifierClass = getMutationNotifierClassForClass([object class]);
            if (notifierClass == nil) {
                assert(false);
            } else {
                object_setClass(object, notifierClass);
            }
        } else {
            Class baseClass = getOriginalClassForMutationNotifierClass([object class]);
            object_setClass(object, baseClass);
        }
    }
}

static Class getOriginalClassForMutationNotifierClass(Class mutationNotiferClass) {
    
    Boolean isActuallyNotifer = strstr(class_getName(mutationNotiferClass), "_MFMutationObservation") != NULL;
    if (isActuallyNotifer) {
        return [mutationNotiferClass superclass];
    } else {
        return mutationNotiferClass;
    }
}

static Class getMutationNotifierClassForClass(Class class) {
    
    /// Create cache
    static NSMutableDictionary *_cache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _cache = [NSMutableDictionary dictionary];
    });
    
    /// Try return cache
    Class cached = _cache[class];
    if (cached != nil) {
        return cached;
    }
    
    @synchronized (_cache) { /// We probably don't need to sync here since all calls to this go through `toggleMutationNotifications` which is synced.
        
        /// Double checked-locking pattern
        if (_cache[class] != nil) {
            return _cache[class];
        }
        
        /// Create new mutation notifier class
        
        /// List of mutable foundation types here:
        ///     https://developer.apple.com/library/archive/documentation/General/Conceptual/CocoaEncyclopedia/ObjectMutability/ObjectMutability.html
        ///
        /// We tried an NSProxy instead of isa-swizzling but it's wayyyy slower.
        
        NSDictionary *selectorToBlockFactoryMap = nil;
        
        /// Define macros
        ///     The way we swizzle with the BlockFactory pattern and macros follows the approach we used for the swizzling code in MMF.
        
            #define UNPACK(args...) \
                args
        
            #define APPEND_ARGS(args...) \
                , ## args  /// Takes arg list wrapped in `(some, parentheses)` and returns `, some, parentheses`, If the arglist is empty the `, ` is deleted. (Magic of ## operator)
                    

            #define MakeBlockFactory(__callArgs, __declArgs, __callback) \
                ^(SEL m_selector, void (*m_originalImplementation)(id, SEL APPEND_ARGS __declArgs)) { \
                    return ^(id m_observedObject APPEND_ARGS __declArgs) { \
                        __callback(__callArgs, __declArgs) \
                    }; \
                }
            #define kvoCallback(__callArgs, __declArgs) \
                [m_observedObject willChangeValueForKey:@"self"]; \
                m_originalImplementation(m_observedObject, m_selector APPEND_ARGS __callArgs); \
                [m_observedObject didChangeValueForKey:@"self"]; \

            #define errorCallback(__callArgs, __declArgs) \
                NSLog(@"Error: called unsupported mutation method %s, on mutation observer %@", sel_getName(m_selector), m_observedObject); \
                assert(false); \
        
        if (isSubclass(class, [NSMutableString class])) {
            ///
            /// Swizzle all public mutating functions of NSMutableString.
            ///     The docs say that "replaceCharactersInRange:withString:" is the 'primitive' mutation method through which all other mutation methods modify the string.
            ///     But this does not seem to be the case at least for some of the private class cluster classes like `__NSCFString`, so we swizzle all public mutators instead.
            ///
            selectorToBlockFactoryMap = @{
                @"appendFormat:": MakeBlockFactory((aString), (NSString *aString, ...), errorCallback), /// We can't do varargs
                @"appendString:":
                    MakeBlockFactory((aString), (NSString *aString), kvoCallback),
                @"applyTransform:reverse:range:updatedRange:":
                    MakeBlockFactory((transform, reverse, range, resultingRange), (NSStringTransform transform, BOOL reverse, NSRange range, NSRangePointer resultingRange), kvoCallback),
                @"deleteCharactersInRange:":
                    MakeBlockFactory((range), (NSRange range), kvoCallback),
                @"insertString:atIndex:":
                    MakeBlockFactory((aString, loc), (NSString *aString, NSUInteger loc), kvoCallback),
                @"replaceCharactersInRange:withString:":
                    MakeBlockFactory((range, aString), (NSRange range, NSString *aString), kvoCallback),
                @"replaceOccurrencesOfString:withString:options:range:":
                    MakeBlockFactory((target, replacement, options, searchRange), (NSString *target, NSString *replacement, NSStringCompareOptions options, NSRange searchRange), kvoCallback),
                @"setString:":
                    MakeBlockFactory((aString), (NSString *aString), kvoCallback),
            };
            
        } else if (isSubclass(class, [NSMutableAttributedString class])) {
            ///
            /// Override the 2 mutating NSMutableAttributedString primitive methods.
            ///     See https://developer.apple.com/documentation/foundation/nsmutableattributedstring?language=objc
            ///
            ///     Update this: This won't work - private class cluster stuff. Need to override all public mutating methods instead.
            
            selectorToBlockFactoryMap = @{
                @"replaceCharactersInRange:withString:": MakeBlockFactory((range, aString), (NSRange range, NSString *aString), kvoCallback),
                @"setAttributes:range:": MakeBlockFactory((attrs, range), (id attrs, NSRange range), kvoCallback),
            };
        } else {
            
            /// TODO: Implement support for other mutating foundations classes.
            ///     NOTE: NSMutableArray and NSMutableSet use other methods than `willChangeValueForKey:`
            
            assert(false);
        }
        
        /// Cleanup macros
        #undef MakeBlockFactory
        #undef APPEND_ARGS
        
        /// Create new subclass
        const char *subclassName = [[NSStringFromClass(class) stringByAppendingString:@"_MFMutationObservation"] cStringUsingEncoding:NSUTF8StringEncoding];
        Class mutationObserverClass = objc_allocateClassPair(class, subclassName, 0); /// There's also `objc_duplicateClass`which is apparently used by KVO, but subclassing seems just as good?
        
        /// Replace methods on the new subclass
        for (NSString *selectorString in selectorToBlockFactoryMap) {
            
            /// Get method
            Method method = class_getInstanceMethod(mutationObserverClass, NSSelectorFromString(selectorString));
            SEL selector = method_getName(method);
            IMP originalImplementation = method_getImplementation(method);
            const char *types = method_getTypeEncoding(method);
            
            /// Add method
            ///    This ensures we're not affecting the method of the superclass, which would affect all other subclasses that inherit the method.
            Boolean didAddMethod = class_addMethod(mutationObserverClass, selector, originalImplementation, types);
            if (didAddMethod) {
                method = class_getInstanceMethod(mutationObserverClass, selector);
            } else {
                assert(false); /// We should always be able to add the method since our freshly created subclass doesn't have any of its own methods yet and inherits everything.
            }
            
            /// Create new implementation from block in map
            id (^blockFactory)(SEL selector, IMP originalImplementation) = selectorToBlockFactoryMap[selectorString];
            id block = blockFactory(selector, originalImplementation);
            IMP newImplementation = imp_implementationWithBlock(block);
            
            /// Replace implementation.
            method_setImplementation(method, newImplementation);
        }
        
        /// Register new subclass class
        objc_registerClassPair(mutationObserverClass);
        
        /// Cache
        _cache[(id)class] = mutationObserverClass;
        
        /// Cache notfierClass as its own notifierClass
        ///     -> So that, in case someone tries to retrieve the mutationNotifierClass of a mutationNotifierClass, we will just return the the existing mutationNotifierClass instead of creating a new one.
        _cache[(id)mutationObserverClass] = mutationObserverClass;
        
        /// Return
        return mutationObserverClass;
    }
}

///
/// Utility
///

static Boolean isSubclass(Class subclass, Class superclass) {
    Class class = subclass;
    while (true) {
        if (class == superclass) {
            return true;
        }
        class = class_getSuperclass(class);
        if (class == NULL) {
            return false;
        }
    }
}

@end

