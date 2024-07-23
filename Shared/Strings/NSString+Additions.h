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

- (__DISABLE_SWIFT_BRIDGING(NSString *))substringWithRegex:(__DISABLE_SWIFT_BRIDGING(NSString *))regex NS_REFINED_FOR_SWIFT;
- (__DISABLE_SWIFT_BRIDGING(NSAttributedString *))attributed NS_REFINED_FOR_SWIFT;
- (__DISABLE_SWIFT_BRIDGING(NSString *))firstCapitalized NS_REFINED_FOR_SWIFT;
- (__DISABLE_SWIFT_BRIDGING(NSString *))stringByTrimmingWhiteSpace NS_REFINED_FOR_SWIFT;
- (__DISABLE_SWIFT_BRIDGING(NSString *))stringByAddingIndent:(NSInteger)indent NS_REFINED_FOR_SWIFT;
- (__DISABLE_SWIFT_BRIDGING(NSString *))stringByPrependingWhitespace:(NSInteger)spaces NS_REFINED_FOR_SWIFT;

@end

NS_ASSUME_NONNULL_END
