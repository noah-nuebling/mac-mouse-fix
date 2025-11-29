//
// --------------------------------------------------------------------------
// NSString+Additions.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import "DisableSwiftBridging.h"

@interface NSString (Additions)

/// Note: [May 2025] Shouldn't the nullability annotations be outside the `MF_SWIFT_UNBRIDGED` macro?
- (MF_SWIFT_UNBRIDGED(NSString              *_Nullable)) substringWithRegex: (MF_SWIFT_UNBRIDGED(NSString *_Nonnull))regex                                                                                                      NS_REFINED_FOR_SWIFT;
- (MF_SWIFT_UNBRIDGED(NSAttributedString    *_Nonnull))  attributed                                                                                                                                                             NS_REFINED_FOR_SWIFT;
- (MF_SWIFT_UNBRIDGED(NSString              *_Nonnull))  firstCapitalized                                                                                                                                                       NS_REFINED_FOR_SWIFT;
- (MF_SWIFT_UNBRIDGED(NSString              *_Nonnull))  stringByRemovingAllWhiteSpace                                                                                                                                          NS_REFINED_FOR_SWIFT;
- (MF_SWIFT_UNBRIDGED(NSString              *_Nonnull))  stringByTrimmingWhiteSpace                                                                                                                                             NS_REFINED_FOR_SWIFT;
- (MF_SWIFT_UNBRIDGED(NSString              *_Nonnull))  stringByAddingIndent: (NSInteger)indent                                                                                                                                NS_REFINED_FOR_SWIFT;
- (MF_SWIFT_UNBRIDGED(NSString              *_Nonnull))  stringByAddingIndent: (NSInteger)indent                                                    withCharacter: (MF_SWIFT_UNBRIDGED(NSString *_Nonnull))indentCharacter      NS_REFINED_FOR_SWIFT;
- (MF_SWIFT_UNBRIDGED(NSString              *_Nonnull))  stringByPrependingCharacter: (MF_SWIFT_UNBRIDGED(NSString *_Nonnull))prependedCharacter    count: (NSInteger)count                                                     NS_REFINED_FOR_SWIFT;

@end
