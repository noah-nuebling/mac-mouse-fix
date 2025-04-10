//
// --------------------------------------------------------------------------
// NSCharacterSet+Additions.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2025
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>

@interface NSCharacterSet (Additions)

/// Why use copy setter semantics?
///     The native NSCharacterSet class properties use copy, but since they are all readonly, the copy attribute doesn't do anything. (Because copy specifies the *setter* semantics but readonly props only have a getter.)

@property(readonly, class, copy, nonatomic, nonnull) NSCharacterSet *lowercaseASCIILetterCharacterSet;
@property(readonly, class, copy, nonatomic, nonnull) NSCharacterSet *uppercaseASCIILetterCharacterSet;
@property(readonly, class, copy, nonatomic, nonnull) NSCharacterSet *asciiDigitCharacterSet;
@property(readonly, class, copy, nonatomic, nonnull) NSCharacterSet *asciiLetterCharacterSet;

@property(readonly, class, copy, nonatomic, nonnull) NSCharacterSet *cIdentifierCharacterSet_Start;
@property(readonly, class, copy, nonatomic, nonnull) NSCharacterSet *cIdentifierCharacterSet_Continue;

@end
