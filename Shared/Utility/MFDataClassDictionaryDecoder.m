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
///
///     This is specifically made to work with MFDataClass,
///         with some extensions it might be usable with other classes that implement `NSCoding`?
///
/// Update: (Nov 2024) I've come to understand NSCoder a bit better since writing this. So some of the comments here might be out of date or the code might be non-optimal. (But it works)
///         See `MFCoding.m` for latest understanding of NSCoder.

#import "MFDataClassDictionaryDecoder.h"
#import "SharedUtility.h"

#import "objc/runtime.h"

@implementation MFDataClassDictionaryDecoder

- (NSSet<Class> *)allowedClasses { return _allowedClasses; }
- (BOOL)requiresSecureCoding { return _requiresSecureCoding; }
- (NSDecodingFailurePolicy)decodingFailurePolicy { return NSDecodingFailurePolicySetErrorAndReturn; } /// Why are we hardcoding this? The user of this decoder should be able to determine this.
- (unsigned int)systemVersion { return 0; } /// No idea what this is or how to use it, but the docs told me to override this IIRC
- (BOOL)allowsKeyedCoding { return YES; }
- (NSError *)error { return _error; }

- (void)failWithError:(NSError *)error {
    
    /// Not sure why I need to manually implement this. Seems to always throw an exception (instead of setting `self.error`) otherwise.
    ///     Update: I have a vague memory of reading that the "top-level" decoder methods perhaps catch the exceptions produced at lower levels and then set self.error appropriately if we're under the `NSDecodingFailurePolicySetErrorAndReturn` policy.,, But I might be hallucinating that. Actually my expriences with using `failWithError:` on NSKeyedUnarchiver go against this IIRC (seems to just return and not throw any errors/exceptions.)
    if (self.decodingFailurePolicy == NSDecodingFailurePolicySetErrorAndReturn) {
        if (!_error) { /// Error should only be set once according to some Apple docs I read. IIRC the idea is to only display the initial error that happens during decoding, not the subsequent errors that might occur as a result of the wrong state. Not sure it makes sense to implement/use that logic here.
            _error = error ?: [NSError errorWithDomain:@"MFPlaceholderErrorDomain" code:123456789 userInfo:@{ @"message": @"No error provided by developer" }];
        }
    } else {
        assert(self.decodingFailurePolicy == NSDecodingFailurePolicyRaiseException);
        @throw error;
    }
}

- (instancetype)initForReadingFromDict:(NSDictionary *)dict requiresSecureCoding:(BOOL)requiresSecureCoding {
    
    self = [super init];
    if (!self) return nil;
    
    _dict = dict;
    _requiresSecureCoding = requiresSecureCoding;
    
    return self;
}

- (BOOL)containsValueForKey:(NSString *)key {
    return _dict[key] != nil;
}

- (id)decodeObjectOfClasses:(NSSet<Class> *)classes forKey:(NSString *)key {
    /// Note: `decodeObjectOfClass:` will call this (I think - [Jan 2025])
    _allowedClasses = classes;
    id result = [self decodeObjectForKey:key];
    _allowedClasses = [NSSet set]; /// Reset allowed classes - Not sure this is necessary / makes sense
    return result;
}

- (id)decodeObjectForKey:(NSString *)key {

    /// NOTES:
    /// - Should we return an error here if the key is not found? (NSCoderValueNotFoundError)
    ///     -> No we don't need to because `MFDataClass - initWithCoder:` is already validating the keys separately using our `- containsValueForKey:` method.
    /// - Note that we can only decode *objects* not non-objects. This should work fine for MFDataClass (which this is made for), since MFDataClass uses KVC to autobox all its property values in objects - but for other NSSecureCoding classes this probably won't be enough.

    id result = _dict[key];
    
    /// Handle nil
    ///     Note how we never apply the allowedClasses typeChecks for nil values (Does this align with NSKeyedUnarchiver behavior?)
    if (result == nil) return nil;
    if (result == NSNull.null) return nil; /// NSNull in the dict represents nil in the encoded object. || Clients can use `containsValueForKey:` to disambiguate.
    
    if (self.requiresSecureCoding) {
        
        BOOL isOfAllowedType = NO;
        for (Class allowedClass in [self allowedClasses]) { /// We could replace with the cool and awesome anysatisfy() macro
            if ([result isKindOfClass:allowedClass]) {
                isOfAllowedType = YES;
                break;
            }
        }
    
        if (!isOfAllowedType) {
            [self failWithError:[NSError errorWithDomain:@"MFPlaceholderErrorDomain" code:123456789 userInfo:@{@"message": stringf(@"MFDictionaryCoder - type mismatch while decoding key %@. Allowed classes: %@ (their subclasses are also allowed). Found class: %@. Decoded value: %@", key, self.allowedClasses, [result class], result) }]];
            return nil;
        }
        if (![result conformsToProtocol:@protocol(NSSecureCoding)]) {
            [self failWithError:[NSError errorWithDomain:@"MFPlaceholderErrorDomain" code:123456789 userInfo:@{@"message": stringf(@"MFDictionaryCoder - decoded value for key '%@' does not conform to NSSecureCoding. Decoded value: %@", key, result) }]];
            return nil;
        }
    }
    
    return result;
}

- (NSDictionary *)underlyingDict {
    /// This is for debugging purposes. Generally, use `decodeObjectForKey:` to query the dict.
    return self->_dict;
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
