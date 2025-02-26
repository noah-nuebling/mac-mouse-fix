//
// --------------------------------------------------------------------------
// MFPlistEncoder.m
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
#import "SimpleUnboxing.h"

#pragma mark - Failure macros
///     !! Keep in sync with MFPlistDecoder !!

#define failWithError(code_, messageAndFormatArgs...) ({                            \
    [self _failWithErrorCode: (code_) reason: stringf(messageAndFormatArgs)];       \
    return ERROR_RETURN_VALUE;                                                      \
})

#define propagateError() ({             \
    if (self->_error)                   \
        return ERROR_RETURN_VALUE;      \
})

#define returnIfAlreadyFailed() ({                              /**  Copied from MFPlistDecoder */ \
    if (self.error) {                                           \
        assert(false && "The encoder has already failed.");     \
        return ERROR_RETURN_VALUE;                              \
    }                                                           \
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
    #undef  ERROR_RETURN_VALUE
    #define ERROR_RETURN_VALUE
    
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
                   ifthen(!keyIsRoot, (!rootExists && stackTailExists));   /// !rootExists because we only set `_rootPlist` down below if keyIsRoot
    if (!isValid)
        failWithError(kMFNSCoderError_InternalInconsistency, @"Invalid state. [keyIsRoot:%d, rootPlistExists:%d, stackTailExists:%d]. _rootPlist: (%@), encodedObj: (%@)", keyIsRoot, rootExists, stackTailExists, _rootPlist, encodedObj);
    
    /// Validate plist result
    if (keyIsRoot)
        if (runningPreRelease())
            if (!CFPropertyListIsValid((__bridge void *)encodedObj, kCFPropertyListXMLFormat_v1_0)) /// Not sure what the XML format arg does.
                failWithError(kMFNSCoderError_InternalInconsistency, @"The generated archive (%@) is not a valid property list.", encodedObj);
    
    /// Store encoded value in the archive under `key`
    if (keyIsRoot)  _rootPlist = encodedObj;
    else            _dictStack.lastObject[key] = encodedObj;
}

- (id _Nullable) _encodeObjectToPlist: (id _Nullable)obj {
    
    /// Internal helper method
    
    /// Define failure return
    #undef  ERROR_RETURN_VALUE
    #define ERROR_RETURN_VALUE nil
    
    /// Track circular references
    NSMutableArray *visitedObjects = threadobject([[NSMutableArray alloc] init]);
    bool didAddToVisitedObjects = false;
    if (obj) {
        NSNumber *obj_key = @((intptr_t)obj); /// Converting obj reference to NSNumber for performance. Not sure if it helps.
        if ([visitedObjects containsObject: obj_key])
            failWithError(NSCoderInvalidValueError, @"Found circular reference in object graph. This encoder cannot handle that (yet ? ... don't give me ideas.)."); /// Update: Tried in MFDeepCopyCoder but it seems pretty much impossible to get decoding circular references right.
        [visitedObjects addObject: obj_key];
        didAddToVisitedObjects = true;
    }
    MFDefer ^{ if (didAddToVisitedObjects) [visitedObjects removeLastObject]; };
    
    /// Encode nil
    ///     ... as `kMFPlistCoder_Nil` which is a special string – and therefore a plist type.
    /// Notes:
    /// - We don't need special handling for NSNull (represents nil in NSArray/NSDictionary) because it's not a plist type and therefore gets encoded just like any non-plist object.
    /// - If we return actual nil here, that indicates failure, and should only be done through `failWithError()` [Feb 2025]
    if (!obj)
        return kMFPlistCoder_Nil;
    
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
        
        if (!isPlistNode) {
        
            /// Not a valid plist node -> encode obj into a NSDictionary (with string keys) using whatever keys that obj chooses in its -[encodeWithCoder:] method.
            ///     E.g. if obj is an NSDictionary, it would choose the keys "NS.keys" and "NS.objects" to store two arrays for its keys and values.
            
            /// Create result dict
            result = [NSMutableDictionary dictionary];
            
            /// Recurse
            [self->_dictStack addObject: result];   /// Push result
            [obj encodeWithCoder: self];            /// Have obj encode itself into the `result` dict.
            [self->_dictStack removeLastObject];    /// Pop result
            
            /// Propagate error.
            propagateError();
            
            /// Store obj's class in the archive
            result[kMFPlistCoder_ClassName] = [classForCoder className];
        }
        else {
            
            /// Encode plist type
            ///
            /// For plist containers (NSArray and NSDictionary) we copy the container structure into our archive and recurse into the container.
            ///
            /// Context/Explanation:
            ///     When you call -[NSArray encodeWithCoder:], it passes "NS.object.<index>" keys to -[NSCoder encodeObject: forKey:]
            ///     When you call -[NSDictionary encodeWithCoder:], it passes "NS.keys" and "NS.objects" keys to -[NSCoder encodeObject: forKey:]
            ///     -> We don't wanna use these keys. Instead we just wanna keep the natural NSArrays and NSDictionaries structure in our archive, since they're already plist types. -> That way the resulting archive should be more human-readable.
                
            ifcastn(obj, NSArray, arr) {
                /// Plist container - NSArray
                
                id __unsafe_unretained objects[arr.count];
                [arr getObjects: objects];
                
                id resultObjects[arrcount(objects)];
                
                for (NSUInteger i = 0; i < arrcount(objects); i++) {
                    id e = [self _encodeObjectToPlist: objects[i]];
                    propagateError();
                    if (!e) failWithError(kMFNSCoderError_InternalInconsistency, @"nil slipped through propagateError(). (nil only signals errors. Actual nil values in the object hierarchy should be encoded with kMFPlistCoder_Nil.)");
                    resultObjects[i] = e;
                }
                
                result = [[NSArray alloc] initWithObjects: resultObjects count: arrcount(resultObjects)];
                
            } else ifcastn(obj, NSDictionary, dict) {
                /// Plist container - NSDictionary

                id __unsafe_unretained keys[dict.count];    /// Due to the MFPlistIsValidNode() checks above, we know the dict keys are strings and don't need further encoding.
                id __unsafe_unretained objects[arrcount(keys)];
                [dict getObjects: objects andKeys: keys];    /// Unboxing the dictionary onto the stack, for efficiency mostly. Not sure if necessary.
                
                id resultObjects[arrcount(objects)];
                
                for (NSUInteger i = 0; i < arrcount(objects); i++) {
                    id e = [self _encodeObjectToPlist: objects[i]];   /// Recurse
                    propagateError();
                    if (!e) failWithError(kMFNSCoderError_InternalInconsistency, @"nil slipped through propagateError().");
                    resultObjects[i] = e;
                }
                
                result = [[NSDictionary alloc] initWithObjects: resultObjects forKeys: keys count: arrcount(keys)]; /// Use the same keys in the archive dict as the original dictionary -> We keep the same structure!
                
            } else {
            
                /// Plist is a leaf (instead of a container) – simply make a copy for the archive.
                ///     Discussion: [Feb 2025] For our usual usecase of applying MFPlistEncoder and then storing straight into config.plist, making a copy here might not be necessary.
                ///         However, the copy might prevent subtle bugs, and should be very cheap, since immutable objects usually just return themselves when sent -copy
                result = [obj copy];
            }

        }
    });
    
    /// Validate: result is plist
    ///     This will also catch nil or NSNull
    ///     > Therefore: We never return nil from this method except when calling failWithError() [Feb 2025]
    if (runningPreRelease()) /// Turn this (possible sorta expensive) validation off in release builds.
        if (!MFPlistIsValidNode(result))
            failWithError(kMFNSCoderError_InternalInconsistency, @"The encoding result (%@) is not a valid plist node.", result);
    
    /// Return result
    return result;
}

bool MFPlistIsValidNode(id _Nullable obj) {
    
    /// Helper function
    
    /// Returns true the following are true
    ///     1. obj is an instance of one of the 7 plist types.
    ///     2. obj is not an instance of a public subclass of a plist type (Except for the standard, known mutable ones, e.g. NSMutableString, NSMutableArray, ...)
    ///         (Detailed explanation below – above the implementation)
    ///     3. all dict keys are NSStrings (in case obj is a dict)
    ///     4. no dict keys are instances of a public subclass of NSString
    ///         (Explanation below – above the implementation)
    ///     > If this is all true, then obj could be a valid 'node' in a property list, which can be encoded and decoded via NSPropertyListSerialization without losing any semantic information. (By 'semantic' info, we mean info that the user of the object 'should' care about. So not implementation details such as which private class-cluster subclass obj is an instance of.)
    ///
    /// Caveats:
    ///     If obj is a container (NSArray or NSDictionary), then the contents of obj are *not* validated by this function. (Use CFPropertyListIsValid() to validate the whole object graph.)
    ///
    /// Testing notes:
    ///     Tested [Feb 2025]: CFPropertyListIsValid() wont exclude custom subclasses like we do, except if the subclasses override `-[_cfTypeID]`
    ///
    /// This implementation is very verbose:
    ///     - [Feb 2025] We could delete all the CFGetTypeID() logic and replace it with just the -[classForCoder] logic. Although it might be slightly slower.
    ///
    /// Notes:
    /// - The 7 plist types are documented here: https://developer.apple.com/documentation/corefoundation/cfpropertylistref?language=objc
    /// - CFBoolean and CFNumber are both bridged to NSNumber.
    
    /// Null-safety
    if (!obj) return false;
    
    /// Create typeID keys
    enum TIDKey {
        kTIDKey_Data        = 0,
        kTIDKey_String,
        kTIDKey_Array,
        kTIDKey_Dictionary,
        kTIDKey_Date,
        kTIDKey_Number,
        kTIDKey_Boolean,
        kTIDKey_N,
    };
    
    /// Get plist typeIDs
    static CFTypeID *tids;
    static dispatch_once_t onceToken; dispatch_once(&onceToken, ^{
        CFTypeID temp[] = {
            [kTIDKey_Data]       = CFDataGetTypeID(),
            [kTIDKey_String]     = CFStringGetTypeID(),
            [kTIDKey_Array]      = CFArrayGetTypeID(),
            [kTIDKey_Dictionary] = CFDictionaryGetTypeID(),
            [kTIDKey_Date]       = CFDateGetTypeID(),
            [kTIDKey_Number]     = CFNumberGetTypeID(),
            [kTIDKey_Boolean]    = CFBooleanGetTypeID(),
        };
        tids = malloc(sizeof(temp));  /// Strategic memory leak
        memcpy(tids, temp, sizeof(temp));
    });
    
    /// Get obj typeID
    ///     Observations: [Feb 2025]: CFGetTypeID() crashes when passed nil. When you pass it a non-bridged class like NSObject or NSButton, it always seems to return 1, so that seems safe.
    CFTypeID obj_tid = CFGetTypeID((__bridge void *)obj);
    
    /// Compare typeIDs
    ///     to see if obj is of a plist type
    bool isplist = false;
    for (enum TIDKey k = 0 ; k < kTIDKey_N; k++)
        if (tids[k] == obj_tid)
            { isplist = true; goto endof_tidchecks; }
    endof_tidchecks:
    
    /// Check if all dict keys are strings
    ///     In a plist, all dict keys must be strings. See CFPropertyListIsValid() docs.
    ///     We only allow NSString and its private cluster-class subclasses (via -[classForCoder]).
    ///         > Other public subclasses aren't allowed due to semantic information loss (This concept is explained where we check whether *obj*'s class is a custom public subclass)
    ///         > NSMutableString is impossible to find as a dict key, since dict keys are sent -[copy] by the dict before being stored. (Which transforms NSMutableString into NSString)
    ///             Update/Observation [Feb 2025]: I DID see an NSMutableString key when encoding the dict node `@{ kMFPlistCoder_ClassName = MFLicenseTypeInfoGumroadV1; }`. Not sure why that happens. But we needed to also allow NSMutableString to make the encoding code work. I guess the keys are still 'semantically' immutable though even if they are NSMutableString instances (?)

    if (isplist)
        if (obj_tid == tids[kTIDKey_Dictionary])
            for (id key in (NSDictionary *)obj) {
                Class cls = [key classForCoder];
                if (cls != NSString.class && cls != NSMutableString.class)
                    { isplist = false; goto endof_keychecks; }
            }
    endof_keychecks:
    
    /// Do subclass checks
    ///     Explanation
    ///         We don't consider public subclasses of plist types 'valid' plist nodes. Because they cannot be encoded and decoded via NSPropertyListSerialization without losing semantic information (At least the class is lost.)
    ///         Exceptions:
    ///             1. The known mutable subclasses, (NSMutableString, etc.) are considered 'valid' nodes.
    ///                 Therefore, upon decoding, we don't know, whether the encoded object was originally of the base class or the mutable subclass. But we handle this by always instantiating the mutable subclass upon decoding, which should still work fine. (But make performance a bit worse)
    ///             2. For private class-cluster subclasses, the specific class is an implementation detail. We treat them as their public superclass (Via -[classForCoder]). Therefore, they are also considered 'valid' nodes.
    ///
    ///     Are these checks necessary?
    ///         Only if we have a custom subclass of a plist type in the program. We don't have that in MMF as of [Feb 2025]. I'm not sure we ever will. I don't see a good reason to subclass, and the plist types being class-clusters makes subclassing complicated, too, I think.
    ///
    ///     Sidenote:
    ///         When decoding an archive, NSPropertyListSerialization can produce the base-classes or the standard mutable subclasses (via the option NSPropertyListMutableContainersAndLeaves) . Since the standard mutable subclasses are given a special role there, it makes sense for us to do that here, too. (I think?)
    ///
    ///     Testing notes:
    ///         Based on my tests (I made a subclass of NSString – in [Feb 2025]), custom subclasses seem to return the same CFTypeID() as their parent, except if they deliberately override the `-[_cfTypeID]` method.
    ///         > Therefore these checks here seem necessary to avoid information loss while encoding public subclasses.
    ///
    ///     Could we avoid unnecessarily instantiating mutable subclasses (which are probably slower) during decoding? Ideas:
    ///         - We could have the user of the coder pass in the class they expect back, but for that we'd have to deviate from the standard NSCoder interface, and -[initWithCoder:] implementations would have to go out of their way to use the new interface.
    ///             Except if we use the decoder's -[allowedClasses] – but that might contain more than one class, and is normally only present during *secure* decoding. So this might allow for some optimization, but feels not worth it.
    ///         - We could encode the mutable subclasses using the -[encodeWithCoder:] method that we use for non-plist types. Then there would be no ambiguity.
    ///             However the -[encodeWithCoder:] method is much less human-readable, and it seems that methods that return the base-class (e.g. NSArray) as per their interface, often actually return the mutable subclass (e.g. NSMutableArray). So this seems to make the 'human-readability' of the archives sort of brittle.
    ///         -> Conclusion:
    ///             Can't think of good alternatives. Also, the only downside to making everything mutable is that it might decrease performance. But unless we have performance issues, I don't think it's worth optimizing, since this serialization code only runs once-in-a-while.
    ///
    ///     Big picture investigation: Would the archive ever contain mutable leaves?    (This is not relevant to what the code here should look like as of [Feb 2025] – it's just interesting)
    ///         We are calling -[copy] on leaves while encoding them inside MFPlist*En*coder, thereby making them immutable. [Feb 2025]
    ///         NSPropertyListSerialization returns immutable objects by default. (NSString instead of NSMutableString)
    ///             But currently [Feb 2025] we're using "NSPropertyListMutableContainersAndLeaves" to decode config.plist. (Actually not sure if that's necessary.) so we're currently receiving mutable subclasses from the config.
    
    if (isplist) {
    
        Class obj_cls = [obj classForCoder]; /// -[classForCoder] should give us the public superclass in case obj is a private-cluster subclass. Not sure there's a more 'semantic' way.
        
        #define succ()  ({ isplist = true;  goto endof_subclasschecks; })
        #define fail()  ({ isplist = false; goto endof_subclasschecks; })
        
        #define typecheck1(_tidkey, _classname1)    \
            if (obj_tid == tids[_tidkey])           \
            {                                       \
                if (obj_cls == _classname1.class)   \
                    succ();                         \
                else                                \
                    fail();                         \
            }
        
        #define typecheck2(_tidkey, _classname1, _classname2)       \
            if (obj_tid == tids[_tidkey])                           \
            {                                                       \
                if (obj_cls == _classname1.class || obj_cls == _classname2.class)   /** Note how we're using pointer-equivalence instead of -[isSubclassOfClass:] */\
                    succ();                                         \
                else                                                \
                    fail();                                         \
            }
    
        typecheck2(kTIDKey_Data,        NSData,         NSMutableData)
        typecheck2(kTIDKey_String,      NSString,       NSMutableString)
        typecheck2(kTIDKey_Array,       NSArray,        NSMutableArray)
        typecheck2(kTIDKey_Dictionary,  NSDictionary,   NSMutableDictionary)
        typecheck1(kTIDKey_Date,        NSDate)
        typecheck1(kTIDKey_Number,      NSNumber)
        typecheck1(kTIDKey_Boolean,     NSNumber)
        else
            assert(false && "This should never happen if our code is correct.");
        
        endof_subclasschecks:
        
        assert(isplist == true &&
            "This assert-failure is not an error. It exists out of curiosity."
            "\nThis would happen if obj is a custom subclass of a plist type. We could still encode obj in this case, by simply not considering it a 'valid plist node' and calling -encodeWithCoder: on it like we do for non-plist types."
            "\nThis assert exists because I wonder if custom subclasses of plist types are ever even used – then this would alert us. Custom subclasses seem very niche. Not even CFPropertyListIsValid() can handle them.");
        
        #undef succ
        #undef fail
        #undef typecheck1
        #undef typecheck2
    };
    
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
