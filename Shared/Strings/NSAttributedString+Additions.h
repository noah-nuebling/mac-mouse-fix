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
#import "MarkdownParser/MarkdownParser.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSAttributedString (Additions)

/// For usage guide, see Apple Typography Human Interface Guidelines: https://developer.apple.com/design/human-interface-guidelines/typography

void assignAttributedStringKeepingBase(NSAttributedString *_Nonnull *_Nonnull assignee, NSAttributedString *newValue);

- (NSAttributedString *)attributedStringByCapitalizingFirst;
- (NSAttributedString *)attributedStringByRemovingAllWhitespace;
- (NSAttributedString *)attributedStringByTrimmingWhitespace;

- (NSAttributedString *) attributedStringByReplacing: (NSString *)searchedString with: (NSAttributedString *)replacementString;
- (NSAttributedString *) attributedStringByReplacing: (NSString *)searchedString with: (NSAttributedString *)replacementString count: (int)count;
- (NSAttributedString *) attributedStringByAppending: (NSAttributedString *)string;
+ (NSAttributedString *) attributedStringWithAttributedFormat: (NSAttributedString *)format args: (NSAttributedString *__strong _Nullable [_Nonnull])args argcount: (int)argcount;
- (NSArray<NSAttributedString *> *) split: (NSString *)separator maxSplit: (int)maxSplit;

- (NSAttributedString *)attributedStringByAddingBaseLineOffset:(CGFloat)offset forRange:(const NSRangePointer _Nullable)range;

- (NSString *)stringWithAttachmentDescriptions;

- (NSAttributedString *)attributedStringByAddingFontTraits:(NSDictionary<NSFontDescriptorTraitKey, id> *)traits forRange:(const NSRangePointer _Nullable)inRange;
- (NSAttributedString *)attributedStringByAddingWeight:(NSFontWeight)weight forRange:(const NSRangePointer _Nullable)range;

- (NSAttributedString *)attributedStringByAddingSymbolicFontTraits:(NSFontDescriptorSymbolicTraits)traits forSubstring:(NSString *)subStr;
- (NSAttributedString *)attributedStringByAddingSymbolicFontTraits:(NSFontDescriptorSymbolicTraits)traits forRange:(const NSRangePointer _Nullable)inRange;

- (NSAttributedString *)attributedStringByFillingOutBase;
- (NSAttributedString *)attributedStringByFillingOutBaseAsHint;

- (NSAttributedString *)attributedStringByAddingAttributesAsBase:(NSDictionary<NSAttributedStringKey, id> *)baseAttributes;
+ (NSAttributedString *)hyperlinkFromString:(NSString *)inString withURL:(NSURL *)url;
- (NSAttributedString *)attributedStringByAddingHyperlink:(NSURL *_Nullable)url forSubstring:(NSString *)substring;
    - (NSAttributedString *)attributedStringByAddingHyperlink:(NSURL *_Nullable)aURL forRange:(const NSRangePointer _Nullable)range;
- (NSAttributedString *)attributedStringByAddingFont:(NSFont *)font forRange:(const NSRangePointer _Nullable)range;

- (NSAttributedString *)attributedStringByAddingBoldForSubstring:(NSString *)subStr;
- (NSAttributedString *)attributedStringByAddingBoldForRange:(const NSRangePointer _Nullable)range;
- (NSAttributedString *)attributedStringByAddingItalicForRange:(const NSRangePointer _Nullable)range;
- (NSAttributedString *)attributedStringByAddingItalicForSubstring:(NSString *)subStr;
- (NSAttributedString *)attributedStringByAddingAlignment:(NSTextAlignment)alignment forRange:(const NSRangePointer _Nullable)rangeIn;
- (NSAttributedString *)attributedStringByDisablingOrphanedWordsForRange:(const NSRangePointer _Nullable)rangeIn;
- (NSAttributedString *)attributedStringByAddingParagraphSpacingBefore:(CGFloat)spacing forRange:(const NSRangePointer _Nullable)range;
- (NSAttributedString *)attributedStringByAddingParagraphSpacing:(CGFloat)spacing forRange:(const NSRangePointer _Nullable)range;
- (NSAttributedString *)attributedStringByAddingLineSpacing:(CGFloat)spacing forRange:(const NSRangePointer _Nullable)range;

#if 0
    - (NSAttributedString *)attributedStringBySettingWeight:(NSInteger)weight;
    - (NSAttributedString *)attributedStringBySettingThinForSubstring:(NSString *)subStr;
#endif

- (NSAttributedString *)attributedStringBySettingFontSize:(CGFloat)size;
- (NSAttributedString *)attributedStringByAddingColor:(NSColor *)color forSubstring:(NSString *)subStr;
- (NSAttributedString *)attributedStringByAddingColor:(NSColor *)color forRange:(const NSRangePointer _Nullable)range;

- (NSAttributedString *) attributedStringByAddingBlankLineHeight: (CGFloat)height forRange:(const NSRangePointer _Nullable)range;
- (NSAttributedString *)attributedStringByAddingHintStyle;

- (NSSize)sizeAtMaxWidth:(CGFloat)maxWidth;
- (CGFloat)heightAtWidth:(CGFloat)width;
//- (CGFloat)preferredWidth;

@end

NS_ASSUME_NONNULL_END
