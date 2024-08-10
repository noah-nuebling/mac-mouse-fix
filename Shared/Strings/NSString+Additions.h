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

NS_ASSUME_NONNULL_BEGIN

@interface NSString (Additions)

- (MF_SWIFT_UNBRIDGED(NSString *))substringWithRegex:(MF_SWIFT_UNBRIDGED(NSString *))regex NS_REFINED_FOR_SWIFT;
- (MF_SWIFT_UNBRIDGED(NSAttributedString *))attributed NS_REFINED_FOR_SWIFT;
- (MF_SWIFT_UNBRIDGED(NSString *))firstCapitalized NS_REFINED_FOR_SWIFT;
- (MF_SWIFT_UNBRIDGED(NSString *))stringByRemovingAllWhiteSpace NS_REFINED_FOR_SWIFT;
- (MF_SWIFT_UNBRIDGED(NSString *))stringByTrimmingWhiteSpace NS_REFINED_FOR_SWIFT;
- (MF_SWIFT_UNBRIDGED(NSString *))stringByAddingIndent:(NSInteger)indent NS_REFINED_FOR_SWIFT;
- (MF_SWIFT_UNBRIDGED(NSString *))stringByAddingIndent:(NSInteger)indent withCharacter:(MF_SWIFT_UNBRIDGED(NSString *))indentCharacter NS_REFINED_FOR_SWIFT;
- (MF_SWIFT_UNBRIDGED(NSString *))stringByPrependingCharacter:(MF_SWIFT_UNBRIDGED(NSString *))prependedCharacter count:(NSInteger)count NS_REFINED_FOR_SWIFT;

@end

NS_ASSUME_NONNULL_END
