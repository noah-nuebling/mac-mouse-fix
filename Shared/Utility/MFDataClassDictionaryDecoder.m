//
// --------------------------------------------------------------------------
// MFDataClassDictionaryDecoder.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

///
/// This class wraps an NSDictionary in an NSCoder
///     -> effectively letting you pass the NSDictionary to the `initWithCoder:` method of an object.,
///     -> -> effectively letting you convert an NSDictionary into an object of a certain type.
///     This is desirable because it lets you reuse the validation logic that (should probably be) implemented inside `initWithCoder:` whether you're creating your instance from an `NSKeyedArchiver` archive or an `NSDictionary`, (or other data that you can easily convert to an NSDictionary such as a JSON string.)
///         (You can also convert an NSDictionary to an object using the KVC method `setValuesForKeysWithDictionary:`, but that doesn't implement any extra validation, so you might end up with an invalid or incompletely initialized object.)
///         Update: [Feb 2025] ^^^ much of this stuff is outdated
///
///     This is specifically made to work with MFDataClass,
///         with some extensions it might be usable with other classes that implement `NSCoding`?
///
/// Update: (Nov 2024) I've come to understand NSCoder a bit better since writing this. So some of the comments here might be out of date or the code might be non-optimal. (But it works)
///         See `MFCoding.m` for latest understanding of NSCoder.

#import "MFDataClassDictionaryDecoder.h"
#import "SharedUtility.h"
#import "EventLoggerForBradMacros.h"
#import "NSCoderErrors.h"
#import "MFDataClass.h"

#import "objc/runtime.h"

@implementation MFDataClassDictionaryDecoder {
    NSDictionary *_Nonnull _rootDict;
    NSMutableArray<NSDictionary *> *_Nonnull _dictStack;
    BOOL _requiresSecureCoding;
    NSMutableSet<Class> *_allowedClasses;
    NSError *_error;
}

- (NSSet<Class> *)allowedClasses { return _allowedClasses; }
- (BOOL)requiresSecureCoding { return _requiresSecureCoding; }
- (NSDecodingFailurePolicy)decodingFailurePolicy { return NSDecodingFailurePolicySetErrorAndReturn; } /// TODO: Why are we hardcoding this? The user of this decoder should be able to determine this.
- (unsigned int)systemVersion { return 0; } /// No idea what this is or how to use it, but the docs told me to override this IIRC
- (BOOL)allowsKeyedCoding { return YES; }
- (NSError *)error { return _error; }

#pragma mark - Convenience macro

#define failWithError(code_, messageAndFormatArgs...) ({                            \
    [self failWithError:MFNSCoderErrorMake((code_), stringf(messageAndFormatArgs))];    \
    return nil;                                                                     \
})

#pragma mark - Decoding

- (void)failWithError:(NSError *_Nonnull)error {
    
    /// Not sure why I need to manually implement this. If we don't, this seems to always throw an exception (instead of setting `self.error`)
    ///     Update: [Feb 2025] Based on the other (now deleted) comments here, I might've just been confused. See MFCoding.m for an explanation of how this NSCoder error stuff works.
    ///         TODO: -> Before developing this further, test whether the superclass impl actually does the same thing.
    
    
    /// Null-safety
    if (!error) { assert(false); return; }
    
    switch (self.decodingFailurePolicy) {
    bcase (NSDecodingFailurePolicySetErrorAndReturn): {
        /// NSError-based
        ///     Note: Error should only be set once according to Apple docs. IIRC the idea is to only display the initial error that happens during decoding, not the subsequent errors that might occur as a result of the wrong state. Not sure it makes sense to implement/use that logic here.
        if (!_error) _error = error;
    }
    bcase (NSDecodingFailurePolicyRaiseException): {
        /// NSException-based
        ///     Note: objc docs say that @throw should only throw NSException objects in a Cocoa application.
        NSException *exc = MFNSCoderExceptionMake_FromError(error);
        @throw exc;
    }
    bdefault: {
        assert(false);
    }}
}

- (instancetype)initForReadingFromDict:(NSDictionary *)dict requiresSecureCoding:(BOOL)requiresSecureCoding {
    
    self = [super init];
    if (!self) return nil;
    
    _allowedClasses = [NSMutableSet set];
    _rootDict = dict;
    _dictStack = [NSMutableArray arrayWithObject:dict];
    _requiresSecureCoding = requiresSecureCoding;
    
    return self;
}

- (BOOL)containsValueForKey:(NSString *)key {
    assert(_dictStack.lastObject != nil);
    return _dictStack.lastObject[key] != nil;
}

- (id)decodeObjectOfClasses:(NSSet<Class> *)classes forKey:(NSString *)key {
    /// Note: `decodeObjectOfClass:` will call this (I think - [Jan 2025])
    
    NSMutableSet *newClasses = classes.mutableCopy;
    [newClasses minusSet:_allowedClasses];
    
    [_allowedClasses unionSet:newClasses];      /// Push
    id result = [self decodeObjectForKey:key];  /// Decode
    [_allowedClasses minusSet:newClasses];      /// Pop
    
    return result;
}

- (id)decodeObjectForKey:(NSString *)key {

    /// NOTES:
    /// - Should we return an error here if the key is not found? (NSCoderValueNotFoundError)
    ///     -> No we don't need to because `MFDataClass - initWithCoder:` is already validating the keys separately using our `- containsValueForKey:` method.
    /// - Note that we can only decode *objects* not non-objects. This should work fine for MFDataClass (which this is made for), since MFDataClass uses KVC to autobox all its property values in objects - but for other NSSecureCoding classes this probably won't be enough.
    
    /// Validate
    assert(_dictStack.lastObject != nil);
    
    /// Extract result
    id result = _dictStack.lastObject[key];
    
    /// Handle nil
    ///     Note how we never apply the allowedClasses typeChecks for nil values (Does this align with NSKeyedUnarchiver behavior?)
    if (result == nil)          return nil;
    if (result == NSNull.null)  return nil; /// NSNull in the dict represents nil in the encoded object. || Clients can use `containsValueForKey:` to disambiguate.
    
    /// Get result class
    Class resultClass = nil;
    ({
        ifcastn(result, NSDictionary, resultDict) do {
            
            /// Try to get exact MFDataClass to instantiate from the dict archive
                
            ///
            /// TODO: Take care of these notes.
            ///     (These were written when this code was still inside [MFDataClass initWithCoder:])
            ///
            /// General info: MFDataClassDictionaryDecoder means we're decoding an MFDataClass hierarchy from a nested dictionary
            ///
            /// On letting the dict specify the class to instantiate: [Jan 2025]
            ///     If this fails, we could theoretically fall back to just creating an instance of self.class.
            ///     but that's bad in case our code expects us to instantiate a specific *subclass* of self.class. (That's the case for MFLicenseTypeInfo, where we never wanna instantiate the 0-prop base class, only its subclasses.)
            ///
            /// Meta discussion on dict archives
            ///     On architecture: [Feb 2025]
            ///         We could possibly move all the MFDataClassDictionaryDecoder-specific code into MFDataClassDictionaryDecoder. Then MFDataClassDictionaryDecoder might be able to decode any kind of class-hierarchy from a nested dictionary. (Not just MFDataClasses)
            ///         ... But doing it like this was easier and works for our purposes.
            ///         ... Also, the idea originally was that MFDataClassDictionaryDecoder does as little as possible and essentially just wraps an NSDictionary. Maybe it's a good idea to keep it that way.
            ///
            ///     Meta: c structs and arrays
            ///         Out of NSArray and MFDataClass we should be able to build any interesting arrangement of data. They would serve as an object-based alterative to arrays and structs from C.
            ///
            ///     On `NSArray<SomeMFDataClass *> *`
            ///         [Feb 2025] If one of self's properties is an NSArray that contains MFDataClass instances, we aren't able to properly encode/decode that here.
            ///             To implement `NSArray<SomeMFDataClass *> *` decoding with *automatic* secureCoding support, I think we'd have to update the MFDataClass macros, since the objc runtime doesn't have access to lightweight generics (in this case, we'd wanna access `<SomeMFDataClass *>`)
            ///             ... However, currently we don't need `NSArray<MFDataClass *> *` support, so we don't implement it, yet.
            ///             A (possibly) more practical alternative to trying to get the lightweight generic info into runtime using macros, would be to override initWithDictionary: in a category for the MFDataClass in question, and to then set the MFDictionaryDecoder's "allowedClasses" in there. This would be 'manual' secureCoding support, but that should still be ok.
            ///
            ///             Sidenote: Same is true for `NSDictionary<SomeMFDataClass *>` – We also can't decode that here, but I think we'd never wanna use NSDictionary over MFDataClass in our archivable datastructures.
            
            NSString *archivedClassName = resultDict[MFDataClass_DictArchiveKey_ClassName];
            if (self.requiresSecureCoding) {
                if (!archivedClassName)
                    break;              /// MFDataClass name missing from the dictionary, it must just be a normal dictionary, not an archive of an MFDataClass
                if (!isclass(archivedClassName, NSString))
                    failWithError(NSCoderReadCorruptError, @"MFDataClass name extracted from dictionary archive is not an NSString. Is %@. Archive: %@", archivedClassName.className, self.underlyingDict);
            }
            
            resultClass = NSClassFromString(archivedClassName);
            if (self.requiresSecureCoding)
                if (!resultClass)
                    failWithError(NSCoderReadCorruptError, @"No class object currently loaded for MFDataClass name '%@' which is specified in dictionary archive (%@)", archivedClassName, self.underlyingDict);
            
        } while(0);
        
        if (!resultClass) { /// Default case - if we're not overriding resultClass using dict archive
            resultClass = [result class];
        }
        
    });
    
    /// Validate resultClass
    if (self.requiresSecureCoding) {
        
        /// Check if result matches self.allowedClasses
        bool resultClassIsAllowed = false;
        for (Class c in self.allowedClasses)
            if (isclass(resultClass, c))
                { resultClassIsAllowed = true; break; }
        if (!resultClassIsAllowed)
            failWithError(NSCoderReadCorruptError, @"MFDictionaryCoder - type mismatch while decoding key %@. Allowed classes: %@ (their subclasses are also allowed). Found class: %@. Decoded value: %@", key, self.allowedClasses, [result class], result);
        
        /// Check if 'decoded' value supports secure coding.
        ///     I guess this validation makes some sense since we're probably not actually doing any "decoding" (which would fail with a normal decoder) and instead just extracting this value from the dict (?)
        if (![result conformsToProtocol:@protocol(NSSecureCoding)])
            failWithError(NSCoderReadCorruptError, @"MFDictionaryCoder - decoded value for key '%@' does not conform to NSSecureCoding. Decoded value: %@", key, result);
    }
    
    /// Recurse
    if ([result class] != resultClass) {
        if (isclass(result, NSDictionary)) {
            [self->_dictStack addObject:result];                /// Push
            result = [[resultClass alloc] initWithCoder:self];  /// Recurse and override result
            [self->_dictStack removeLastObject];                /// Pop
        }
        else {
            failWithError(kMFNSCoderError_InternalInconsistency, @"result is not an NSDictionary, although we overrode resultClass. Our code must be wrong [Feb 2025]. result is: (%@) resultClass is: (%@)", result, resultClass);
        }
    }
    
    /// Validate
    assert([result class] == resultClass);
    
    /// Return
    return result;
}

#pragma mark - Debugging

- (NSDictionary *)underlyingDict {
    /// This is for debugging purposes. Generally, use `decodeObjectForKey:` to query the dict.
    return self->_rootDict;
}

- (NSString *)description {

    assert(false); /// Unused
    
    NSMutableString *result = [NSMutableString string];
    
    [result appendFormat:@"<MFDataClassDictionaryDecoder> {"];
    
    unsigned int nIvars;
    Ivar *ivars = class_copyIvarList(self.class, &nIvars);
    MFDefer ^{ free(ivars); };
    
    for (int i = 0; i < nIvars; i++) {
        NSString *ivarName = @(ivar_getName(ivars[i]));
        id value = [self valueForKey:ivarName];
        [result appendFormat:@"\n    %@ = %@;", ivarName, value];
    }
    
    [result appendFormat:@"\n}"];

    return result;
}

@end


/// Crazy code: Parse raw property type strings (extracted straight from the source code, instead of the objc runtime) to automatically decode properties that contain unstructured nested datastructures which themselves contain MFDataClass instances.
///     (NSArrays and NSDictionaries which contain an MFDataClass.)
#if 0
    if (isclass(coder, MFDataClassDictionaryDecoder)) {
        void (^__block recurse)(id archiveNode, NSString *rawTypeInfo) =
        ^void                  (id archiveNode, NSString *rawTypeInfo) {
        
            /// Parse raw type info
            NSScanner *scanner = [NSScanner scannerWithString:rawTypeInfo];
            while (1) {
                
                NSString *topType;
                NSArray<NSString *> *childTypes;
                
                /// Find topType
                while (1) {
                    if (scanner.atEnd) break;
                    NSString *identifier = nil;
                    bool foundMatches = [scanner scanUpToCharactersFromSet:NSCharacterSet.cIdentifierCharacterSet_Start intoString:nil];
                         foundMatches = [scanner scanCharactersFromSet:NSCharacterSet.cIdentifierCharacterSet_Continue intoString:&identifier]; /// This assumes that `_Continue` is a   superset of `_Start`.
                    if (identifier && NSClassFromString(identifier)) { /// Find first identifier that is a valid class name. This makes us skip keywords like `const` or `__kindof` that can appear before the class name.
                        topType = identifier;
                        break;
                    }
                }
                
                /// Parse generic specializations
                NSMutableArray<NSString *> *specs = nil;
                if (!scanner.atEnd) {
                    specs = [NSMutableArray array];
                    [scanner scanUpToString:@"<" intoString:nil]; /// Skip everything between the topType and `<`
                    int bracketBalance = 0;
                    NSUInteger i, j;
                    i = j = scanner.scanLocation;
                    while (1) {
                        unichar c = [rawTypeInfo characterAtIndex:j];
                        if      (c == '<') bracketBalance++;
                        else if (c == '>') bracketBalance--;
                        else if (c == ',' && brackedBalance == 1) {
                            [specs addObject:[rawTypeInfo substringWithRange:NSMakeRange(i, j+1)]];
                            i = j;
                        }
                        if (bracketBalance <= 0) {
                            [specs addObject:[rawTypeInfo substringWithRange:NSMakeRange(i, j+1)]];
                            break;
                        }
                        j++;
                    }
                }
                
                /// Recurse
                if (specs) {
                    if (specs.count == 0) {
                        /// Do nothing
                    }
                    else if (specs.count == 1) {
                        if (isclass(archiveNode, NSArray)) {
                            for (id obj in archiveNode) recurse(obj, specs[0]);
                            if (coder.error) return;
                        } else {
                            assert(false);
                        }
                    }
                    else if (specs.count == 2) {
                        if (isclass(archiveNode, NSDictionary)) {
                            for (id obj in ((NSDictionary *)archiveNode).allKeys)   recurse(obj, specs[0]);
                            for (id obj in ((NSDictionary *)archiveNode).allValues) recurse(obj, specs[1]);
                            if (coder.error) return;
                        } else {
                            assert(false);
                        }
                    }
                    else {
                        assert(false);
                    }
                }
                
                /// Convert dict to MFDataClass
                if (isclass(topType, MFDataClassBase)) {
                    if (!isclass(archiveNode, NSDictionary)) {
                        assert(false);
                    }
                    else {
                        /// Init
                        NSError *err;
                        archiveNode = [((MFDataClassBase *)[NSClassFromString(topType) alloc]) initWithDictionary:archiveNode requireSecureCoding:coder.requiresSecureCoding error:&err];
                        if (err) {
                            [coder failWithError:err];
                            return;
                        }
                    }
                }
            }
        };
        recurse([((MFDataClassDictionaryDecoder *)coder) underlyingDict], [self.class rawNullabilityAndTypeOfProperty:key][1]);
        if (coder.error) return nil; /// `recurse()` can fail and set coder.error
    }

#endif
