//
// --------------------------------------------------------------------------
// NSAttributedString+Additions.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSAttributedString (Additions)

- (NSAttributedString *)attributedStringByFillingOutDefaultAttributes;

- (NSAttributedString *)attributedStringByAddingBaseAttributes:(NSDictionary *)baseAttributes;
- (NSAttributedString *)attributedStringByAddingLinkWithURL:(NSURL *)linkURL forSubstring:(NSString *)substring;
- (NSAttributedString *)attributedStringByAddingBoldForSubstring:(NSString *)subStr;
- (NSAttributedString *)attributedStringByAddingItalicForSubstring:(NSString *)subStr;
- (NSAttributedString *)attributedStringByAligningSubstring:(NSString *)subStr alignment:(NSTextAlignment)alignment;
- (NSAttributedString *)attributedStringByAddingThinForSubstring:(NSString *)subStr;
- (NSAttributedString *)attributedStringBySettingSecondaryButtonTextColorForSubstring:(NSString *)subStr;
+ (NSAttributedString *)hyperlinkFromString:(NSString *)inString withURL:(NSURL *)aURL;

- (NSSize)sizeAtMaxWidth:(CGFloat)maxWidth;
- (CGFloat)heightAtWidth:(CGFloat)width;
//- (CGFloat)preferredWidth;

@end

NS_ASSUME_NONNULL_END
