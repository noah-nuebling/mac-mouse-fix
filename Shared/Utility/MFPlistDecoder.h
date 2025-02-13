//
// --------------------------------------------------------------------------
// MFPlistDecoder.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import "NSCoderErrors.h"

/// Decoder

@interface MFPlistDecoder : NSCoder_WithNiceErrors

- (instancetype) initForReadingFromPlist: (id)plist requiresSecureCoding: (BOOL)requiresSecureCoding failurePolicy: (NSDecodingFailurePolicy)failurePolicy;
- (id) rootPlist;                               /// Root node of the plist we're decoding from. Used for debugging.

@end
