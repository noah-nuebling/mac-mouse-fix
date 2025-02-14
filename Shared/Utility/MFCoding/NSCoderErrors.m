//
// --------------------------------------------------------------------------
// NSCoderErrors.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2025
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "NSCoderErrors.h"
#import "EventLoggerForBradMacros.h"
#import "SharedUtility.h"

#pragma mark - NSCoder error & exception creation

/// Error handling tools for our `[id<NSCoding> initWithCoder:]` and `[NSCoder decodeObjectForKey:]` implementations
/// -----------------------------------
///     Testing notes [Feb 2025]:
///         NSKeyedUnarchiver:
///             (Under SetErrorAndReturn failure policy) I saw an NSKeyedUnarchiver **error** with:
///                 - domain: NSCocoaErrorDomain
///                 - code: 4864 (NSCoderReadCorruptError)
///                 - debugDescription dict: Single key `NSDebugDescriptionErrorKey` with value "value for key xx was of unexpected class xx ..."
///
///             (Under RaiseException failure policy) I saw an NSKeyedUnarchiver **exception** with:
///                 - name:  NSInvalidUnarchiveOperationException
///                 - reason: "value for key xx was of unexpected class xx ..."
///                 - userInfo dict: Single key `@"__NSCoderInternalErrorCode"` (kMFNSCoderExceptionKey_InternalErrorCode) with value 4864 (NSCoderReadCorruptError)
///
///             -> Based on these observations we wrote this code which can  __create__ and __convert between__ NSErrors and NSExceptions – in the 'NSCoder' (or at least NSKeyedArchiver) format.
///
///             Note on NotFoundError:
///                 - In my limited testing, I could not produce error code 4865 (NSCoderValueNotFoundError) to see which exceptionName that corresponds to. I assume it's also `NSInvalidUnarchiveOperationException` and then the exception's `internalErrorCode` is used to disambiguate.
///
///         MFPlistDecoder
///             (Under RaiseException failure policy, using [failWithError:] inherited from NSCoder) I saw MFPlistDecoder **exception** with:
///                 - name: NSInvalidUnarchiveOperationException
///                 - reason: "The data couldn’t be read because it isn’t in the correct format."
///                 - userInfo dict: Single key `@"__NSCoderError"` (kMFNSCoderExceptionKey_Error) with value: <The NSError we passed to [failWithError:]>
///
///             -> Might be wrong but it looks like the default NSCoder `[failWithError:]` impl converts NSError <-> NSException differently from NSKeyedUnarchiver.
///
///     Relevant exceptionNames we might wanna use:
///        NSKeyedArchiver exceptions:      NSInvalidArchiveOperationException; NSInvalidUnarchiveOperationException;
///        NSArchiver exceptions:                NSInconsistentArchiveException;
///
///     What about NSKeyed*Archiver*?
///         - [Feb 2025] I observed that secure coding violations still use NSInvalid*Un*archiveOperationException – which seems wrong
///         - [Feb 2025] I observed that the only error-returning method +[NSKeyedArchiver archivedDataWithRootObject:requiringSecureCoding:error:] returns an error with an NSUnderlyingError key in its userInfo dict. The information in the 2 errors is redundant. So the exception<->-error conversion doesn't seem very good.
///
///     Interesting:
///         In the [NSCoder failWithError:] call tree assembly, I saw`[__categorizeException:intoError:]` –> This probably converts the exceptions into errors.

/// Private constants
#define kMFNSCoderExceptionKey_InternalErrorCode  @"__NSCoderInternalErrorCode" /// Saw this in NSKeyedUnarchiver exceptions.
#define kMFNSCoderExceptionKey_Error              @"__NSCoderError"             /// Saw this in MFPlistDecoder exceptions.
#define kMFNSCoderErrorKey_UnderlyingError        @"NSUnderlyingError"          /// Saw this in +[NSKeyedArchiver archivedDataWithRootObject:requiringSecureCoding:error:] error.

/// Create/convert errors/exceptions
NSError *_Nonnull MFNSCoderErrorMake(NSInteger code, NSString *_Nullable reason) {
    NSError *error = [NSError errorWithDomain:NSCocoaErrorDomain code:code userInfo:@{ NSDebugDescriptionErrorKey: reason ?: NSNull.null }];
    return error;
}
NSException *_Nonnull MFNSCoderExceptionMake(NSInteger code, NSString *_Nullable reason, NSExceptionName _Nonnull name) {
    NSException *result = [[NSException alloc] initWithName:name reason:reason userInfo:@{ kMFNSCoderExceptionKey_InternalErrorCode: @(code) }];
    return result;
}

NSError *_Nonnull MFNSCoderErrorMake_FromException(NSException *_Nonnull exception) {
    NSNumber *codeNS = exception.userInfo[kMFNSCoderExceptionKey_InternalErrorCode];
    assert(codeNS && isclass(codeNS, NSNumber));
    NSString *reason = exception.reason;
    NSInteger code = codeNS ? [codeNS integerValue] : kMFNSCoderError_Fallback;
    NSError *error = MFNSCoderErrorMake(code, reason);
    return error;
}
NSException *_Nonnull MFNSCoderExceptionMake_FromError(NSError *_Nonnull error) {
    
    assert([error.domain isEqual: NSCocoaErrorDomain]); /// Omitting the error.domain from the exception, because we're always using NSCocoaErrorDomain
    
    NSExceptionName excName; /// Map errorCode -> exceptionName
    ({
        switch (error.code) { /// Note: Maybe we could hardcode/fall back to `NSInvalidUnarchiveOperationException` here? Since we're unarchiving?
            bcase (NSCoderValueNotFoundError,                       /// v Merging the ValueNotFound error with the generic ReadCorrupt error since I can't find an exceptionName corresponding to ValueNotFound.
                   NSCoderReadCorruptError):                        excName = NSInvalidUnarchiveOperationException;
            bcase (NSCoderInvalidValueError):                       excName = NSInvalidArchiveOperationException;
            bcase (kMFNSCoderError_InternalInconsistency):          excName = NSInternalInconsistencyException;
            bcase (): {
                excName = kMFNSCoderExceptionName_Fallback;
                assert(false);
            }
        }
    });
    
    NSInteger code = error.code;
    NSString *reason = error.userInfo[NSDebugDescriptionErrorKey];
    NSException *exc = MFNSCoderExceptionMake(code, reason, excName);
    return exc;
}

#pragma mark - NSCoder subclass

/// This provides unified error handling that we can use in our custom encoders and decoders.
///
/// Discussion:
///     What we're doing here is overriding the -[NSCoder failWithError:] and related methods to work properly for *en*coders, not just *de*coders.
///         That also means, that NSDecodingFailurePolicy*SetErrorAndReturn* works for both encoders and decoders that inherit from this.
///         > The benefit is that we can unify the error handling for our custom encoders and decoders.
///
///         Why do we think that -[NSCoder failWithError:] and NSDecodingFailurePolicy*SetErrorAndReturn* is meant only for *de*coders ?
///             – The docs only mention decoding
///             - -[NSCoder failWithError:] always seems to produce NSInvalid*Unarchive*OperationException, never NSInvalid*Archive*OperationException
///             > For more, see MFCoding.m

@implementation NSCoder_WithNiceErrors

- (NSDecodingFailurePolicy) decodingFailurePolicy   { return _decodingFailurePolicy; }
- (NSError *_Nullable)      error                   { return _error; }

- (void) __setError: (NSError *)err {
    
    /// Observations [Feb 2025]
    ///     - The native `[NSCoder failWithError:]` impl calls this. If we don't override this, it throws an NSInternalInconsistencyException with reason "Attempting to set decode error on throwing NSCoder ..."
    ///     - The native `-[NSCoder decodeTopLevelObjectOfClasses:forKey:error:]` impl also calls this to **reset the error back to nil**, after it has extracted the error after it's done with decoding.
    ///     - Stupid?: It seems that `[NSCoder failWithError:]` converts the error to an NSException and then back to NSError before calling this. That's despite us using  `NSDecodingFailurePolicySetErrorAndReturn`, which I thought is meant to turn off any back-and-forth conversion to NSException (See MFCoding.m for explanation.)
    
    /// Is the superclass implementation only for decoders, not encoders?
    ///     I think so. `self->_error` exists to propagate errors under NSDecodingFailurePolicySetErrorAndReturn. But that policy is meant only for *de*coders as explained above.
    
    if (!err) _error = err; /// Always allow setting to nil
    else {
        /// Don't allow overriding an existing error.
        ///     Note: Error should only be set once according to Apple docs. IIRC the idea is to only display the initial error that happens during decoding, not the subsequent errors that might occur as a result of the wrong state. Not sure it makes sense to implement/use that logic here.
        if (_error)
            assert(false);
        else _error = err;
    }
    
}

- (void)failWithError:(NSError *_Nonnull)err {
    
    /// Replacement for `-[NSCoder failWithError:]` – which behaves appropriately for both  *en*coders and *de*coders.
    ///
    /// Usage:
    /// - Wrap this in a failWithError() macro instead of calling this directly – so you don't forget to return after calling this.
    /// - This is called both inside the coder implementation, as well as by any -[initWithCoder:] methods of objects we're decoding.
    
    if (!err) {
        assert(false);
        return;
    }
    
    switch (_decodingFailurePolicy) {
    
    bcase(NSDecodingFailurePolicyRaiseException): {
        NSException *exc = MFNSCoderExceptionMake_FromError(err);
        @throw exc;
    }
    bcase(NSDecodingFailurePolicySetErrorAndReturn): {
        [self __setError:err];
    }}
    
}

- (void)_failWithErrorCode: (NSInteger)code reason: (NSString *_Nullable)reason {
    
    /// Convenience wrapper around `[self failWithError:]`
    
    /// Usage:
    ///     Wrap this in a failWithError() macro instead of calling this directly – so you don't forget to return after calling this.
    
    NSError *err = MFNSCoderErrorMake(code, reason);
    [self failWithError:err];
}

@end
