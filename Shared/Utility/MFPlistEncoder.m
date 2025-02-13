//
// --------------------------------------------------------------------------
//MFPlistEncoder.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2025
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "MFPlistEncoder.h"
#import "MFPlistDecoder.h"

#import "SharedUtility.h"
#import "EventLoggerForBradMacros.h"
#import "NSCharacterSet+Additions.h"
#import "NSCoderErrors.h"
#import "MFDataClass.h"

#pragma mark - Failure macros
///     !! Keep in sync with MFPlistDecoder !!

#define failWithError(code_, messageAndFormatArgs...) ({                            \
    [self _failWithErrorCode: (code_) reason: stringf(messageAndFormatArgs)];    \
    return FAIL_WITH_ERROR_RETURN;                                                                     \
})

#define propagateError() ({             \
    if (self->_error)                   \
        return FAIL_WITH_ERROR_RETURN;  \
})

#define returnIfAlreadyFailed() ({ /**  Copied from MFPlistDecoder */ \
    if (self.error) {                                       \
        assert(false && "The encoder has already failed."); \
        return FAIL_WITH_ERROR_RETURN;                      \
    }                                                       \
})

#pragma mark - NSCoder impl

@implementation MFPlistEncoder {
    id _Nullable                                    _rootPlist;  /// Root of the plist archive that we're building.
    NSMutableArray<NSMutableDictionary *> *_Nonnull _dictStack; /// Stack of NSDictionaries. The last one is where `encodeObject:forKey:` will write the encoded object to.

    BOOL                                            _requireSecureCoding;
}

/// Getters
- (id _Nullable)            encodedPlist            { return _rootPlist; } /// This holds the result after encoding has finished.

- (BOOL)                    requiresSecureCoding    { return _requireSecureCoding; }

- (unsigned int)            systemVersion           { return 0; }           /// No idea what this is, copied it from MFPlistDecoder
- (BOOL)                    allowsKeyedCoding       { return YES; }

#pragma mark Encoding

- (instancetype _Nullable) initRequiringSecureCoding: (BOOL)requiresSecureCoding failurePolicy: (NSDecodingFailurePolicy)failurePolicy {
    
    self = [super init];
    if (!self) return nil;
    
    _rootPlist = nil;
    _dictStack = [NSMutableArray array];
    
    _requireSecureCoding = requiresSecureCoding;
    _decodingFailurePolicy = failurePolicy;
    
    _error = nil;
    
    return self;
}

- (void) encodeObject: (id)obj forKey: (NSString *)key {
    
    /// !! Keep in sync with `-[MFPlistDecoder decodeObjectForKey:]` !!
    
    /// Note: Do we need to implement any other encodeXXX:forKey: methods?
    
    /// Define failure return
    #undef  FAIL_WITH_ERROR_RETURN
    #define FAIL_WITH_ERROR_RETURN
    
    /// Guard already failed
    returnIfAlreadyFailed();
    
    /// Validate key
    if (!key || !isclass(key, NSString))
        failWithError(kMFNSCoderError_InternalInconsistency, @"key (%@) is not an NSString", key);

    /// Encode value
    id encodedObj = [self _encodeObjectToPlist: obj]; /// Possibly recurse
    propagateError();
    
    /// Validate storage state
    ///     Before we store something
    bool
        keyIsRoot = [key isEqual: NSKeyedArchiveRootObjectKey], rootExists = (_rootPlist != nil), stackTailExists = (_dictStack.lastObject != nil);
    bool isValid = ifthen(keyIsRoot, (!rootExists && !stackTailExists)) &&
                   ifthen(!keyIsRoot, (!rootExists && stackTailExists));   /// !rootExists because we only set `_rootPlist` down below.
    if (!isValid)
        failWithError(kMFNSCoderError_InternalInconsistency, @"Invalid state. [keyIsRoot:%d, rootPlistExists:%d, stackTailExists:%d]. _rootPlist: (%@), encodedObj: (%@)", keyIsRoot, rootExists, stackTailExists, _rootPlist, encodedObj);
    
    /// Validate plist result
    if (keyIsRoot)
        if (runningPreRelease())
            if (!CFPropertyListIsValid((__bridge void *)encodedObj, kCFPropertyListXMLFormat_v1_0))
                failWithError(kMFNSCoderError_InternalInconsistency, @"The generated archive (%@) is not a valid property list.", encodedObj);
    
    /// Store encoded value in the archive under `key`
    if (keyIsRoot)  _rootPlist = encodedObj;
    else            _dictStack.lastObject[key] = encodedObj;
}

- (id _Nullable) _encodeObjectToPlist: (id _Nullable)obj {
    
    /// Internal helper method
    
    /// Modify failWithError() macro
    #undef  FAIL_WITH_ERROR_RETURN
    #define FAIL_WITH_ERROR_RETURN nil
    
    /// Track circular references
    NSMutableArray *visitedObjects = threadobject([[NSMutableArray alloc] init]);
    bool didAddToVisitedObjects = false;
    if (obj) {
        if ([visitedObjects containsObject: obj])
            failWithError(NSCoderInvalidValueError, @"Found circular reference in object graph. This encoder cannot handle that (yet ? ... don't give me ideas.).");
        [visitedObjects addObject: obj];
        didAddToVisitedObjects = true;
    }
    MFDefer ^{ if (didAddToVisitedObjects) [visitedObjects removeLastObject]; };
    
    /// Encode nil
    ///     ... as `kkMFPlist_Nil` which is a special string – and therefore a plist type.
    /// Notes:
    /// - We don't need special handling for NSNull (represents nil in NSArray/NSDictionary) because it's not a plist type and therefore gets encoded just like any non-plist object.
    /// - If we return actual nil here, that indicates failure, and should only be done through `failWithError()` [Feb 2025]
    if (!obj)
        return kkMFPlist_Nil;
    
    /// Encoding substitutions
    ///     Ask the object if it wants to replace itself or its class before encoding
    ///     Notes:
    ///         - NSKeyedArchiver has a coder-controlled encoding substituion mechanism. (e.g. -[NSKeyedArchiver classNameForClass:].) Should we use that?
    ///         - We're using the "...ForCoder" methods. Should we use the "...ForKeyedArchiver" methods instead?
    ///             (E.g. -[obj classForKeyedArchiver:] -[obj replacementObjectForKeyedArchiver:])?
    ///         - Docs mention that NSCoder calls these. So do we have to call them directly?
    ///         - Apple reference on coding substitutions: https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Archiving/Articles/codingobjects.html#//apple_ref/doc/uid/20000948-97072-BAJJBCHI
    
    ///     > Also see "Decoding substitutions" in MFPlistDecoder
    
    id replacement = [obj replacementObjectForCoder: self];
    if (replacement) obj = replacement;
    Class classForCoder = [obj classForCoder];
    
    /// Check if plist
    bool isPlistNode = MFPlistIsValidNode(obj);
    
    /// Validate obj's protocol conformance
    ///     Note: Only need to do this here since, in all other codepaths, we're dealing with plist types, and we know they support NSSecureCoding.
    if (!isPlistNode) {
        if (self->_requireSecureCoding) {
            if (!isprotocol(obj, NSSecureCoding))
                failWithError(NSCoderInvalidValueError, @"_requireSecureCoding is turned on, but object to encode (%@) doesn't conform to NSSecureCoding.", obj);
        }
        else {
            if (!isNSCoding(obj))
                failWithError(NSCoderInvalidValueError, @"object to encode (%@) doesn't conform to NSCoding.", obj);
        }
    }
    
    /// Encode obj
    __block id result = nil;
    ({
        
        if (!isPlistNode) { /// Check if obj is a valid plist node
        
            /// Not a valid plist node -> encode obj into a NSDictionary (with string keys) using whatever keys that obj chooses in its [encodeWithCoder:] method.
            ///     E.g. NSDictionary would choose the keys `@"NS.keys"` and `@"NS.objects"` to store two arrays for its keys and values.
            
            /// Create container
            result = [NSMutableDictionary dictionary];
            
            /// Recurse
            [self->_dictStack addObject: result];   /// Push result
            [obj encodeWithCoder: self];            /// Have obj encode itself into the `result` dict.
            [self->_dictStack removeLastObject];    /// Pop result
            
            /// Propagate error.
            propagateError();
            
            /// Store obj's class in the archive
            result[MFDataClass_DictArchiveKey_ClassName] = [classForCoder className];
            
        }
        else {
            
            /// Encode plist type
            
            /// On mutability: We always encode into mutable containers! Don't think this causes problems.
            ///
            /// For plist containers (NSArray and NSDictionary)
            ///     ... we copy the container structure into our archive and recurse into the container.
            ///
            /// Context/Explanation:
            ///     When you call -[NSArray encodeWithCoder:], it passes`NS.object.<index>` keys to [NSCoder encodeObject:forKey:]
            ///     When you call -[NSDictionary encodeWithCoder:], it passes `NS.keys` and `NS.objects` keys to [NSCoder encodeObject:forKey:].
            ///     -> We don't wanna use these keys. Instead we just wanna keep the natural NSArrays and NSDictionaries structure in our archive, since they're already plist types. -> That way the resulting archive should be more human-readable.
                
            ifcastn(obj, NSArray, arr) {
                /// Plist container - NSArray
                result = [NSMutableArray array];
                for (id elm in arr) {
                    id e = [self _encodeObjectToPlist:elm];
                    propagateError();
                    if (!e) failWithError(kMFNSCoderError_InternalInconsistency, @"nil slipped through propagateError(). (nil only signals errors. Actual nil values in the object hierarchy should be encoded with kkMFPlist_Nil.)");
                    [result addObject: e];
                }
                
            } else ifcastn(obj, NSDictionary, dict) {
                /// Plist container - NSDictionary
                result = [NSMutableDictionary dictionary];
                for (NSString *k in dict) {                       /// Note: We know that all dict keys are string due to the isPlist checks above.
                    id e = [self _encodeObjectToPlist:dict[k]];   /// Recurse || Use the same keys in the archive dict as the original dictionary -> We keep the same structure!
                    propagateError();
                    if (!e) failWithError(kMFNSCoderError_InternalInconsistency, @"nil slipped through propagateError().");
                    result[k] = e;
                }
            } else {
                /// Plist is not a container – simply return it directly
                result = obj;
            }

        }
    });
    
    /// Validate: result is plist
    ///     This will also catch nil or NSNull
    ///     > Therefore: We never return nil from this method except when calling failWithError() [Feb 2025]
    if (!MFPlistIsValidNode(result))
        failWithError(kMFNSCoderError_InternalInconsistency, @"The encoding result (%@) is not a valid plist node.", result);
    
    /// Return result
    return result;
}

bool MFPlistIsValidNode(id _Nullable obj) {
    
    /// Helper function
    
    /// Returns true if obj is an instance of one of the 7 plist types.
    ///     And – in case obj is a dict – if all dict keys are strings.
    ///     If this is true, then obj could be a valid 'node' in a property list
    ///         (its contents might still not be plist-compatible, though, use CFPropertyListIsValid() to validate the whole object graph.)
    ///
    /// Notes:
    /// - The plist types are documented here: https://developer.apple.com/documentation/corefoundation/cfpropertylistref?language=objc
    /// - CFBoolean and CFNumber are both bridged to NSNumber.
    
    /// Null-safety
    if (!obj) return false;
    
    /// Get plist typeIDs
    static CFTypeID *tids;
    static dispatch_once_t onceToken; dispatch_once(&onceToken, ^{
        CFTypeID temp[] = {
            CFDataGetTypeID(),
            CFStringGetTypeID(),
            CFArrayGetTypeID(),
            CFDictionaryGetTypeID(),
            CFDateGetTypeID(),
            CFBooleanGetTypeID(),
            CFNumberGetTypeID(),
            0                                   /// Zero-terminated
        };
        tids = malloc(sizeof(temp));  /// Strategic memory leak
        memcpy(tids, temp, sizeof(temp));
    });
    
    /// Get obj typeID
    ///     Observations: [Feb 2025]: CFGetTypeID() crashes when passed nil. When you pass it a non-bridged class like NSObject or NSButton, it always seems to return 1, so that seems safe.
    CFTypeID obj_tid = CFGetTypeID((__bridge void *)obj);
    
    /// Compare
    bool isplist;
    for (int i = 0 ;; i++) {
        if (tids[i] == 0)       { isplist = false; break; } /// Zero terminated
        if (tids[i] == obj_tid) { isplist = true;  break; }
    }
    
    /// Check if all dict keys are strings
    ///     In a plist, all dict keys must be strings. See CFPropertyListIsValid() docs.
    if (isplist)
        ifcastn(obj, NSDictionary, dict)
            for (id key in [dict allKeys])
                if (!isclass(key, NSString))
                    { isplist = false; goto endof_keychecks; } /// Note: Some of our macros, like `ifcastn()` use for loops internally, so goto is safer than break.
    endof_keychecks:
    
    /// Return
    return isplist;
}


#if 0
bool MFNSStringIsAllDigits(const NSString *str) {
    NSCharacterSet *badChars = NSCharacterSet.asciiDigitCharacterSet.invertedSet;
    return [str rangeOfCharacterFromSet: badChars].location == NSNotFound;
}
#endif

@end
