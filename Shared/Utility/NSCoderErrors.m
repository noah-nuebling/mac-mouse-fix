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
///         (Under SetErrorAndReturn failure policy) I saw an NSKeyedUnarchiver **error** with:
///             - domain: NSCocoaErrorDomain
///             - code: 4864 (NSCoderReadCorruptError)
///             - debugDescription dict: Single key `NSDebugDescriptionErrorKey` with value "value for key xx was of unexpected class xx ..."
///
///         (Under RaiseException failure policy) I saw an NSKeyedUnarchiver **exception** with:
///             - name:  NSInvalidUnarchiveOperationException
///             - reason: "value for key xx was of unexpected class xx ..."
///             - userInfo dict: Single key `@"__NSCoderInternalErrorCode"` (kMFNSCoderExceptionKey_InternalErrorCode) with value 4864 (NSCoderReadCorruptError)
///
///         -> Based on these observations we wrote this code which can  __create__ and __convert between__ NSErrors and NSExceptions – in the 'NSCoder' (or at least NSKeyedArchiver) format.
///
///         Note on NotFoundError:
///             - In my limited testing, I could not produce error code 4865 (NSCoderValueNotFoundError) to see which exceptionName that corresponds to. I assume it's also `NSInvalidUnarchiveOperationException` and then the exception's `internalErrorCode` is used to disambiguate.
///
///     Relevant exceptionNames we might wanna use:
///        NSKeyedArchiver exceptions:      NSInvalidArchiveOperationException; NSInvalidUnarchiveOperationException;
///        NSArchiver exceptions:                NSInconsistentArchiveException;

/// Private constants
#define kMFNSCoderExceptionKey_InternalErrorCode  @"__NSCoderInternalErrorCode"

/// Create/convert errors/exceptions
NSError *_Nonnull MFNSCoderErrorMake(NSInteger code, NSString *_Nullable reason) {
    return [NSError errorWithDomain:NSCocoaErrorDomain code:code userInfo:@{ NSDebugDescriptionErrorKey: reason ?: NSNull.null }];
}
NSException *_Nonnull MFNSCoderExceptionMake(NSInteger code, NSString *_Nullable reason, NSExceptionName _Nonnull name) {
    return [[NSException alloc] initWithName:name reason:reason userInfo:@{ kMFNSCoderExceptionKey_InternalErrorCode: @(code) }];
}

NSError *_Nonnull MFNSCoderErrorMake_FromException(NSException *_Nonnull exception) {
    NSNumber *codeNS = exception.userInfo[kMFNSCoderExceptionKey_InternalErrorCode];
    assert(codeNS && isclass(codeNS, NSNumber));
    NSString *reason = exception.reason;
    NSInteger code = codeNS ? [codeNS integerValue] : kMFNSCoderError_Fallback;
    NSError *error = MFNSCoderErrorMake(code , reason);
    return error;
}
NSException *_Nonnull MFNSCoderExceptionMake_FromError(NSError *_Nonnull error) {
    
    assert([error.domain isEqual:NSCocoaErrorDomain]); /// Omitting the error.domain from the exception, because we're always using NSCocoaErrorDomain
    
    NSExceptionName excName; /// Map errorCode -> exceptionName
    ({
        switch (error.code) { /// Note: Maybe we could hardcode/fall back to `NSInvalidUnarchiveOperationException` here? Since we're unarchiving?
            bcase (NSCoderValueNotFoundError,                       /// v Merging the ValueNotFound error with the generic ReadCorrupt error since I can't find an exceptionName corresponding to ValueNotFound.
                   NSCoderReadCorruptError):                        excName = NSInvalidUnarchiveOperationException;
            bcase (NSCoderInvalidValueError):                       excName = NSInvalidArchiveOperationException;
            bcase (kMFNSCoderError_InternalInconsistency):          excName = NSInternalInconsistencyException; 
            bdefault: {
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
