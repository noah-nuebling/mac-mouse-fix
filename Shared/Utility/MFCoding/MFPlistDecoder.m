//
// --------------------------------------------------------------------------
// MFPlistDecoder.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "MFPlistDecoder.h"
#import "SharedUtility.h"
#import "EventLoggerForBradMacros.h"
#import "NSCoderErrors.h"
#import "MFPlistEncoder.h"
#import "SimpleUnboxing.h"

#import "objc/runtime.h"

#pragma mark - Failure macros
///     !! Keep in sync with MFPlistEncoder !!

#define failWithError(code_, messageAndFormatArgs...) ({                         \
    [self _failWithErrorCode: (code_) reason: stringf(messageAndFormatArgs)];    \
    return nil;                                                                  \
})

#define propagateError() ({         \
    if (self->_error)               \
        return nil;                 \
})

#define returnIfAlreadyFailed(returnVal) ({ /** I think I read in some Apple docs, that after the first failWithError(), the decoder should stop decoding any further values. That's what this is for. */ \
    if (self.error) {                                       \
        assert(false && "The decoder has already failed."); \
        return (returnVal);                                 \
    }                                                       \
})

#pragma mark - NSCoder impl

@implementation MFPlistDecoder {
    
    id _Nonnull                                 _rootPlist;
    NSMutableArray<NSDictionary *> *_Nonnull    _dictStack;
    
    BOOL                                        _requiresSecureCoding;
    NSMutableSet<Class>                         *_allowedClasses;
}

/// Getters
- (id _Nonnull)             rootPlist               { return _rootPlist; }     /// This is for debugging purposes. Generally, use `decodeObjectForKey:` to query the dict.

- (BOOL)                    requiresSecureCoding    { return _requiresSecureCoding; }
- (NSSet<Class> *)          allowedClasses          { return _allowedClasses; }

- (unsigned int)            systemVersion           { return 0; }            /// No idea what this is or how to use it, but the docs told me to override this IIRC
- (BOOL)                    allowsKeyedCoding       { return YES; }

#pragma mark - Decoding

- (instancetype) initForReadingFromPlist: (id)plist requiresSecureCoding: (BOOL)requiresSecureCoding failurePolicy: (NSDecodingFailurePolicy)failurePolicy {
    
    self = [super init];
    if (!self) return nil;
    
    _rootPlist = plist;
    _dictStack = [NSMutableArray array];
    
    _requiresSecureCoding = requiresSecureCoding;
    _decodingFailurePolicy = failurePolicy;
    
    _allowedClasses = [NSMutableSet set];
    _error = nil;
    
    return self;
}

- (BOOL) containsValueForKey: (NSString *)key {
    
    returnIfAlreadyFailed(NO);
    
    if (_dictStack.lastObject == nil) {
        /// This should never happen during normal decoding if our code is correct.
        ///     That's because we don't call `containsValueForKey:` ourselves, and when we delegate part of the decoding logic through `-[... initWithCoder:self]` – before we call that, we push a dict on the `_dictStack`
        assert(false); /// Not using failWithError() because this is just a sanity-check for our control-flow, not inherently problematic.
        return NO;
    }
    return _dictStack.lastObject[key] != nil;
}

- (id) decodeObjectOfClasses: (NSSet<Class> *)classes forKey: (NSString *)key {
    
    /// Note: The inherited `decodeObjectOfClass:` impl delegates to this
    
    returnIfAlreadyFailed(nil);
    
    NSMutableSet *newClasses = classes.mutableCopy;
    [newClasses minusSet: _allowedClasses];
    
    [_allowedClasses unionSet: newClasses];      /// Push
    id result = [self decodeObjectForKey: key];  /// Decode
    [_allowedClasses minusSet: newClasses];      /// Pop
    
    return result;
}

/// Note on "TopLevel" methods:
///     Based on [Feb 2025] testing:
///         We inherit the error-catching "TopLevel" methods such as `decodeTopLevelObjectOfClasses:` from NSCoder.
///         However, they probably doesn't catch all exceptions, and so using MFDecode() is better. (See MFCoding.m)
///

- (id) decodeObjectForKey: (NSString *)key {

    /// !! Keep in sync with `-[MFPlistEncoder encodeObject:forKey:]` !!

    /// Notes:
    /// - Question: Should we failWithError() here if key is not found? (NSCoderValueNotFoundError)
    ///     -> No a missing key is normal, and [initWithCoder:] should have the chance to recover, without us forcing the decode to fail.
    /// - Note that we only implement [decode*Object*ForKey:] not [decode*Int*ForKey:] and so on.
    ///     This should work fine for MFDataClass (which this is primarily made for), since MFDataClass uses KVC to autobox all its property values in objects - but for some other NSSecureCoding classes this might not be enough. (Except if the inherited NSCoder methods automatically box everything in an object and then delegate to [decodeObjectForKey:]? ... Not sure that's possible.)
    
    /// Guard alreadFailed
    returnIfAlreadyFailed(nil);
    
    /// Validate key
    if (!key || !isclass(key, NSString)) /// Are we going overboard with all these validations?
        failWithError(kMFNSCoderError_InternalInconsistency, @"key (%@) is not an NSString", key);
    
    /// Validate storageState
    ///     Before we extract something from the storage.
    bool
        keyIsRoot = [key isEqual: NSKeyedArchiveRootObjectKey], rootExists = (nil != _rootPlist), stackTailExists = (nil != _dictStack.lastObject);
    bool isValid = rootExists && (keyIsRoot == !stackTailExists);
    if (!isValid)
        failWithError(kMFNSCoderError_InternalInconsistency, @"Invalid storageState: [rootExists: %d, keyIsRoot: %d, stackTailExists: %d]. root: %@", rootExists, keyIsRoot, stackTailExists, _rootPlist);
    
    /// Extract encoded value for `key` from the archive.
    id valueFromArchive;
    if (keyIsRoot)  valueFromArchive = _rootPlist;
    else            valueFromArchive = _dictStack.lastObject[key];
    assert(valueFromArchive != nil && "Cannot be nil if our code is correct (and the storageState validation passed.)"); /// assert() instead of failWithError() cause this can't happen. We really overdid it with the InternalInconsistency errors.
    
    /// Validate root
    if ((0)) /// Note: This is kinda unnecessary, since we're already checking for plist-node validity at every [self _decodeObjectFromPlist:] call.
        if (keyIsRoot)
            if (!CFPropertyListIsValid((__bridge void *)valueFromArchive, kCFPropertyListXMLFormat_v1_0))
                failWithError(NSCoderReadCorruptError, @"Archive is not a valid plist object graph. Is %@", valueFromArchive);
    
    /// Decode value
    id decoded = [self _decodeObjectFromPlist: valueFromArchive]; /// Possibly recurse
    propagateError();
    
    /// Return
    return decoded;
}

- (id _Nullable) _decodeObjectFromPlist: (id _Nonnull)valueFromArchive {
    
    /// Internal helper method
    
    /// Validate plist
    ///     Note: This also guards against any nil and NSNull which might have been extracted from the plist archive (Which should never ever happen to begin with.)
    if (!MFPlistIsValidNode(valueFromArchive))
        failWithError(NSCoderReadCorruptError, @"The plist archive is corrupt. Plist node to be decoded (%@) is not a valid plist node.", valueFromArchive);
    
    /// Handle `kMFPlistCoder_Nil`
    ///
    /// Explanation: `kMFPlistCoder_Nil` in the archive represents nil in the encoded object.
    ///     - Clients can use `containsValueForKey:` to disambiguate between values that are missing from the archive, and values that are encoded as nil.
    /// Notes:
    ///     - We never apply the allowedClasses typeChecks for nil values (Does this align with NSKeyedUnarchiver behavior?)
    ///     - NSNull (represents nil in NSArray/NSDictionary) is encoded in our archive as a regular non-plist object, so we don't need special handling for it.
    
    if ([valueFromArchive isEqual: kMFPlistCoder_Nil]) return nil;
    
    /// Get result class
    Class resultClass = [valueFromArchive class];
    bool decodeUsing_InitWithCoder = false;
    ({
        ifcastn(valueFromArchive, NSDictionary, dictFromArchive) do {
            
            /// If the dict is encoding a non-plist class's instance, get that class.
            
            NSString *archivedClassName = dictFromArchive[kMFPlistCoder_ClassName];
            
            if (!archivedClassName) /// class name is missing from the dictionary, it must just be a normal dictionary, not an archive of a non-plist type
                break;
            
            if (self.requiresSecureCoding)
                if (!isclass(archivedClassName, NSString))
                    failWithError(NSCoderReadCorruptError, @"class name extracted from dictionary archive is not an NSString. Is %@. Archive: %@", archivedClassName.className, self.rootPlist);
            
            Class cls = NSClassFromString(archivedClassName);
            
            if (self.requiresSecureCoding)
                if (!cls)
                    failWithError(NSCoderReadCorruptError, @"No class object currently loaded for class name '%@' which is specified in the archive (%@)", archivedClassName, self.rootPlist);
            
            if (!cls)
                break;
            
            /// All checks passed
            resultClass = cls;
            decodeUsing_InitWithCoder = true;
            
        } while(0);
    });
    
    if (!decodeUsing_InitWithCoder) {
        
        /// Make resultClass *mutable* for raw plist nodes
        ///     Because we always put the mutable subclass into the decoded object-graph
        ///
        ///     Also, concretely, the allowedClasses check below would fail if we don't do this.
        ///     Explanation in `MFPlistIsValidNode()` as of [Feb 2025]
        
        if      (isclass(resultClass, NSArray))          resultClass = [NSMutableArray class];
        else if (isclass(resultClass, NSDictionary))     resultClass = [NSMutableDictionary class];
        else if (isclass(resultClass, NSData))           resultClass = [NSMutableData class];
        else if (isclass(resultClass, NSString))         resultClass = [NSMutableString class];
        /// The 2 other plist classes (NSNumber and NSDate) don't have mutable subclasses.
    };
    
    /// Validate  resultClass' protocol conformance
    ///     Note: Only need to do this if `decodeUsing_InitWithCoder` since otherwise, we already know we're dealing with plist types, which support NSSecureCoding.
    if (decodeUsing_InitWithCoder) {
    
        if (self->_requiresSecureCoding) {
            if (!isprotocol(resultClass, NSSecureCoding))
                failWithError(NSCoderReadCorruptError, @"MFPlistDecoder - Class found in archive (%@) does not conform to NSSecureCoding.", resultClass);
        }
        else {
            if (!isNSCoding(resultClass))
                failWithError(NSCoderReadCorruptError, @"MFPlistDecoder - Class found in archive (%@) does not respond to [initWithCoder:]", resultClass);
        }
    }
    
    /// Validate resultClass against allowedClasses
    ///     Also See the decodingFailurePolicy docs
    ///         (https://developer.apple.com/documentation/foundation/nscoder/1642984-decodingfailurepolicy?language=objc)
    ///         -> lists the reasons for why a decode can fail
    ///
    ///  Note: [Feb 2025] We might be more strict that NSKeyedUnarchiver here. When I moved MFLicenseConfig decoding to this, I had to add NSString to the allowed classes.
    if (self->_requiresSecureCoding) {
        
        bool resultClassIsAllowed = false;
        for (Class c in self.allowedClasses)
            if (isclass(resultClass, c))
                { resultClassIsAllowed = true; break; }
        if (!resultClassIsAllowed)
            failWithError(NSCoderReadCorruptError,
                @"MFPlistDecoder - type mismatch.\nAllowed classes:%@\n(their subclasses are also allowed).\nFound class in archive: '%@'\nWhile decoding plist node:\n%@"
                "\nSolution suggestions: For `MFDataClass`es, try adding the found class to the MFDataClass declaration as a lightweight generic (<%@ *>). Otherwise, add it to the allowedClasses before decoding.",
                self.allowedClasses, resultClass, valueFromArchive, resultClass);
    }
    
    /// Decode valueFromArchive
    id result = nil;
    ({
        if (decodeUsing_InitWithCoder) {
            
            /// Decode arbitrary object
            ///     The object will control the decoding logic in its [initWithCoder:] method. Only once it calls methods on the coder (which is this instance) is the control given back to us.
            
            /// Validate: archive is a dict
            ///     This is guaranteed by the code just a few lines above. These validations are getting out of hand.
            if (!isclass(valueFromArchive, NSDictionary))
                failWithError(kMFNSCoderError_InternalInconsistency, @"valueFromArchive is not an NSDictionary, although we're trying to decode using initWithCoder. Our code must be wrong [Feb 2025]. valueFromArchive is: (%@) resultClass is: (%@)", valueFromArchive, resultClass);
            
            /// Recurse
            [self->_dictStack addObject: valueFromArchive];                 /// Push
            result = [[resultClass alloc] initWithCoder: self];             /// Create new resultClass instance and have it init itself from `valueFromArchive`
            [self->_dictStack removeLastObject];                            /// Pop
            
            
            /// Decoding substitutions
            /// Note:
            ///     - NSKeyedUnarchiver has a coder-controlled decoding substituion mechanism. (e.g. -[NSKeyedUnarchiver classForClassName:]). Should we use that?
            ///
            /// > Also see "Encoding substitutions" in MFPlistEncoder
            result = [result awakeAfterUsingCoder: self];
            
            /// Propagate error
            propagateError();
            
            /// Validate: [initWithCoder:] result != nil
            ///     These validations are getting out of hand.
            if (!result) failWithError(kMFNSCoderError_InternalInconsistency, @"-[initWithCoder:] resulted in nil for encoded value (%@) with expected class (%@). But -[initWithCoder:] didn't set an error.", valueFromArchive, resultClass);
        }
        else {
        
            /// Decode raw plist node
            ///
            /// On mutable handling:
            ///     When decoding raw plist nodes, we always instantiate the mutable subclasses (NSMutableArray and NSMutableString, ...).
            ///     Explanation in `MFPlistIsValidNode()` as of [Feb 2025]
            
            ifcastn(valueFromArchive, NSArray, arr) {
                /// Plist container - NSArray
                
                id __unsafe_unretained objects[arr.count];
                [arr getObjects: objects];
                
                id resultObjects[arrcount(objects)];
                
                for (NSUInteger i = 0; i < arrcount(objects); i++) {
                    id d = [self _decodeObjectFromPlist: objects[i]];   /// Recurse
                    propagateError();
                    if (!d) failWithError(NSCoderReadCorruptError, @"Decoded nil for encoded NSArray element (%@). But NSArray can't store nil.", objects[i]);
                    resultObjects[i] = d;
                }
                
                result = [[NSMutableArray alloc] initWithObjects: resultObjects count: arrcount(resultObjects)];
            }
            else ifcastn(valueFromArchive, NSDictionary, dict) {
                /// Plist container - NSDictionary
                
                id __unsafe_unretained keys[dict.count];
                id __unsafe_unretained objects[arrcount(keys)];
                [dict getObjects: objects andKeys: keys];
                
                id resultObjects[arrcount(objects)];
                
                for (NSUInteger i = 0; i < arrcount(objects); i++) {
                    id d = [self _decodeObjectFromPlist: objects[i]];   /// Recurse
                    propagateError();
                    if (!d) failWithError(NSCoderReadCorruptError, @"Decoded nil for encoded NSDictionary value (%@). But NSDictionary can't store nil.", objects[i]);
                    resultObjects[i] = d;
                }
                
                result = [[NSMutableDictionary alloc] initWithObjects: resultObjects forKeys: keys count: arrcount(keys)]; /// Note how we're making an NS*Mutable*Dictionary
            }
            else {
                /// Plist is leaf
                ///     > make mutable copy (If possible)
                ///
                /// Also see:
                ///     Explanation of mutable-subclass handling in `MFPlistIsValidNode()` as of [Feb 2025]
                ///
                /// Why make a -[mutableCopy] if valueFromArchive is already mutable?
                ///     (instead of simply returning a reference without copying?)
                ///     > Because it would prevent issues, in case we decode an object, and then mutate its mutable NSData or NSString members. That would also mutate the archive if we don't make a copy. Not sure we'd ever do that but it might lead to subtle bugs.
                
                if (isclass(valueFromArchive, NSData)   ||
                    isclass(valueFromArchive, NSString) ) /// NSData and NSString are the only leaf plist types with mutable subclasses. NSDate and NSNumber don't have mutable subclasses.
                {
                    result = [valueFromArchive mutableCopy];
                }
                else {
                    assert(isclass(valueFromArchive, NSDate)    ||
                           isclass(valueFromArchive, NSNumber)  );
                    
                    result = [valueFromArchive copy]; /// On an immutable value, calling -[copy] shouldn't do anything. It should just return the receiver. But NSNumber and NSDate do implement NSCopying, so not sure if copying does something important after all.
                }
            }
        }
    });
    
    /// Validate [result class]
    if (runningPreRelease()) /// Not running this in release builds since I'm not sure it makes sense, and I don't want the decode to fail over incorrect and unnecessary validation.
        if (self->_requiresSecureCoding)
            if (!isclass(result, resultClass))
                failWithError(kMFNSCoderError_InternalInconsistency, @"decoding result %@ with class %@ is not of expected class: %@. plist node found in archive: %@", result, [result class], resultClass, valueFromArchive); /// Note that [result class] could be a subclass of resultClass in case [[resultClass alloc] initWithCoder:] returned a subclass of resultClass. I think that can happen for class-clusters.
    
    /// Return
    return result;
}

#pragma mark - Debugging

- (NSString *)description {
    
    NSMutableString *result = [NSMutableString string];
    
    [result appendFormat:@"<MFPlistDecoder> {"];
    
    unsigned int nIvars;
    Ivar *ivars = class_copyIvarList(self.class, &nIvars);
    MFDefer ^{ free(ivars); };
    
    for (int i = 0; i < nIvars; i++) {
        NSString *ivarName = @(ivar_getName(ivars[i]));
        id value = [self valueForKey:ivarName];
        NSString *valueDesc = [value description];
        valueDesc = [valueDesc stringByReplacingOccurrencesOfString:@"(\n)(.)"   /// Indent every line by 4 spaces except the first one.
                                                         withString:@"$1    $2"
                                                            options:NSRegularExpressionSearch
                                                              range:NSMakeRange(0, valueDesc.length)];
        
        [result appendFormat:@"\n    %@ = %@;", ivarName, valueDesc];
    }
    
    [result appendFormat:@"\n}"];

    return result;
}

@end
