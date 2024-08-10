//
// --------------------------------------------------------------------------
// NSAttributedString+Additions.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSAttributedString (Additions)

/// For usage guide, see Apple Typography Human Interface Guidelines: https://developer.apple.com/design/human-interface-guidelines/typography

void assignAttributedStringKeepingBase(NSAttributedString *_Nonnull *_Nonnull assignee, NSAttributedString *newValue);

- (NSAttributedString *)attributedStringByCapitalizingFirst;
- (NSAttributedString *)attributedStringByRemovingAllWhitespace;
- (NSAttributedString *)attributedStringByTrimmingWhitespace;

- (NSAttributedString *)attributedStringByAppending:(NSAttributedString *)string;
+ (NSAttributedString *)attributedStringWithAttributedFormat:(NSAttributedString *)format args:(NSArray<NSAttributedString *> *)args;
+ (NSAttributedString * _Nullable)attributedStringWithCoolMarkdown:(NSString *)md;
+ (NSAttributedString * _Nullable)attributedStringWithCoolMarkdown:(NSString *)md fillOutBase:(BOOL)fillOutBase;
+ (NSAttributedString * _Nullable)attributedStringWithAttributedMarkdown:(NSAttributedString *)md;

- (NSAttributedString *)attributedStringByAddingBaseLineOffset:(CGFloat)offset forRange:(const NSRangePointer _Nullable)range;

- (NSString *)stringWithAttachmentDescriptions;

- (NSAttributedString *)attributedStringByAddingFontTraits:(NSDictionary<NSFontDescriptorTraitKey, id> *)traits forRange:(const NSRangePointer _Nullable)inRange;
- (NSAttributedString *)attributedStringByAddingWeight:(NSFontWeight)weight forRange:(const NSRangePointer _Nullable)range;

- (NSAttributedString *)attributedStringByAddingSymbolicFontTraits:(NSFontDescriptorSymbolicTraits)traits forSubstring:(NSString *)subStr;
- (NSAttributedString *)attributedStringByAddingSymbolicFontTraits:(NSFontDescriptorSymbolicTraits)traits forRange:(const NSRangePointer _Nullable)inRange;

- (NSAttributedString *)attributedStringByFillingOutBase;
- (NSAttributedString *)attributedStringByFillingOutBaseAsHint;

- (NSAttributedString *)attributedStringByAddingStringAttributesAsBase:(NSDictionary<NSAttributedStringKey, id> *)baseAttributes;
+ (NSAttributedString *)hyperlinkFromString:(NSString *)inString withURL:(NSURL *)url;
- (NSAttributedString *)attributedStringByAddingHyperlink:(NSURL *)url forSubstring:(NSString *)substring;
- (NSAttributedString *)attributedStringByAddingHyperlink:(NSURL *_Nonnull)aURL forRange:(const NSRangePointer _Nullable)range;
- (NSAttributedString *)attributedStringByAddingFont:(NSFont *)font forRange:(const NSRangePointer _Nullable)range;

- (NSAttributedString *)attributedStringByAddingBoldForSubstring:(NSString *)subStr;
- (NSAttributedString *)attributedStringByAddingBoldForRange:(const NSRangePointer _Nullable)range;
- (NSAttributedString *)attributedStringByAddingItalicForRange:(const NSRangePointer _Nullable)range;
- (NSAttributedString *)attributedStringByAddingItalicForSubstring:(NSString *)subStr;
- (NSAttributedString *)attributedStringByAddingAlignment:(NSTextAlignment)alignment forRange:(const NSRangePointer _Nullable)rangeIn;
- (NSAttributedString *)attributedStringByAddingParagraphSpacing:(CGFloat)spacing forRange:(const NSRangePointer _Nullable)range;
- (NSAttributedString *)attributedStringBySettingWeight:(NSInteger)weight;
- (NSAttributedString *)attributedStringBySettingThinForSubstring:(NSString *)subStr;
- (NSAttributedString *)attributedStringByAddingSemiBoldForSubstring:(NSString *)subStr;
- (NSAttributedString *)attributedStringBySettingFontSize:(CGFloat)size;
- (NSAttributedString *)attributedStringByAddingColor:(NSColor *)color forSubstring:(NSString *)subStr;
- (NSAttributedString *)attributedStringByAddingColor:(NSColor *)color forRange:(const NSRangePointer _Nullable)range;

- (NSAttributedString *)attributedStringBySettingSemiBoldColorForSubstring:(NSString *)subStr;
- (NSAttributedString *)attributedStringByAddingHintStyle;

- (NSSize)sizeAtMaxWidth:(CGFloat)maxWidth;
- (CGFloat)heightAtWidth:(CGFloat)width;
//- (CGFloat)preferredWidth;

@end

NS_ASSUME_NONNULL_END
