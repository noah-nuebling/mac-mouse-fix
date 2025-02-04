//
// --------------------------------------------------------------------------
// NSCoderErrors.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2025
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>

/// Constants
#define kMFNSCoderError_InternalInconsistency     123456789                                                 /** Not sure if Apple's coders ever throw an 'internal inconsistency' (aka 'bug-occurred') exception. But we're using this for our custom decoding code sometimes. */
#define kMFNSCoderError_Fallback                  NSCoderErrorMaximum                                       /** Fall back to maximum coder error if getting an error code from the exception fails during `exception -> error` mapping (Not totally sure this makes sense.) */
#define kMFNSCoderExceptionName_Fallback          @"<<< errorCode -> exceptionName mapping failed >>>"      /** Can happen during `error -> exception` mapping. */

/// Error/Exception creation
NSError *_Nonnull       MFNSCoderErrorMake(NSInteger code, NSString *_Nullable reason);
NSException *_Nonnull   MFNSCoderExceptionMake(NSInteger code, NSString *_Nullable reason, NSExceptionName _Nonnull name);
NSError *_Nonnull       MFNSCoderErrorMake_FromException(NSException *_Nonnull exception);
NSException *_Nonnull   MFNSCoderExceptionMake_FromError(NSError *_Nonnull error);
