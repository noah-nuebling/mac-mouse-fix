//
// --------------------------------------------------------------------------
// NSAttributedString+Additions.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "NSAttributedString+Additions.h"
#import <Cocoa/Cocoa.h>

@implementation NSAttributedString (Additions)

#pragma mark Markdown

+ (NSAttributedString *)attributedStringWithMarkdown:(NSString *)md API_AVAILABLE(macos(13.0)) {
    
    /// Create options object
    NSAttributedStringMarkdownParsingOptions *options = [[NSAttributedStringMarkdownParsingOptions alloc] init];
    
    /// No idea what these do
    options.allowsExtendedAttributes = NO;
    options.appliesSourcePositionAttributes = NO;
    
    /// Make it respect linebreaks
    options.interpretedSyntax = NSAttributedStringMarkdownInterpretedSyntaxInlineOnlyPreservingWhitespace;
    
    /// Create string
    NSAttributedString *result = [[NSAttributedString alloc] initWithMarkdownString:md options:options baseURL:[NSURL URLWithString:@""] error:nil];
    
    /// Return result
    return result;
}

#pragma mark Attributed string attributes

- (NSAttributedString *)attributedStringByAddingStringAttributes:(NSDictionary<NSAttributedStringKey, id> *)attributes forRange:(NSRange)range {
    
    NSMutableAttributedString *ret = self.mutableCopy;
    
    [ret addAttributes:attributes range:range];
    
    return ret;
}

/// Baseline offset

- (NSAttributedString *)attributedStringByAddingBaseLineOffset:(CGFloat)offset forRange:(NSRange)range {
    /// Offset in points
    
    return [self attributedStringByAddingStringAttributes:@{
        NSBaselineOffsetAttributeName: @(offset),
    } forRange:range];
}

- (NSAttributedString *)attributedStringByAddingBaseLineOffset:(CGFloat)offset {
    
    NSRange range = NSMakeRange(0, self.length);
    return [self attributedStringByAddingBaseLineOffset:offset forRange:range];
}


#pragma mark Font attributes
/// Font attributes are a subset of attributed string attributes.
///     It might be smart to use our function for adding string attributes for adding font attributes

- (NSAttributedString *)attributedStringByAddingFontAttributes:(NSDictionary<NSFontDescriptorAttributeName,id> *)attributes forRange:(NSRange)range {
    
    NSMutableAttributedString *ret = self.mutableCopy;
    
    [self enumerateAttribute:NSFontAttributeName inRange:range options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
        NSFont *currentFont = (NSFont *)value;
        
        if (currentFont == nil) {
            currentFont = [NSFont systemFontOfSize:NSFont.systemFontSize];
        }
        NSFontDescriptor *newDescriptor = [currentFont.fontDescriptor fontDescriptorByAddingAttributes:attributes];
        
        NSFont *newFont = [NSFont fontWithDescriptor:newDescriptor size:currentFont.pointSize];
        
        [ret addAttribute:NSFontAttributeName value:newFont range:range];
    }];
    return ret;
}

#pragma mark Font traits
/// Font traits are a subset of font attributes
///     We have a completely separate function for adding font traits (instead of utilitzing the func for adding font attributes), so that we can add font traits without overriding exising ones. Not sure if this separate func is actually necessary to achieve this.

- (NSAttributedString *)attributedStringByAddingFontTraits:(NSDictionary<NSFontDescriptorTraitKey, id> *)traits forRange:(NSRange)range {
    
    NSMutableAttributedString *ret = self.mutableCopy;
    [self enumerateAttribute:NSFontAttributeName inRange:range options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
        
        NSFont *currentFont = (NSFont *)value;
        
        if (currentFont == nil) {
            currentFont = [NSFont systemFontOfSize:NSFont.systemFontSize];
        }
        
        /// Get existing traits
        NSDictionary<NSFontDescriptorTraitKey, id> *currentTraits = [currentFont.fontDescriptor fontAttributes][NSFontTraitsAttribute];
        if (currentTraits == nil) {
            currentTraits = [NSMutableDictionary dictionary];
        }
        /// Override with new traits
        NSMutableDictionary *newTraits = currentTraits.mutableCopy;
        for (NSFontDescriptorTraitKey key in traits.allKeys) {
            newTraits[key] = traits[key];
        }
        
        /// Set new overriden traits
        NSFontDescriptor *newDescriptor = [currentFont.fontDescriptor fontDescriptorByAddingAttributes:@{
            NSFontTraitsAttribute: newTraits
        }];
        NSFont *newFont = [NSFont fontWithDescriptor:newDescriptor size:currentFont.pointSize];
        
        [ret addAttribute:NSFontAttributeName value:newFont range:range];
    }];
    
    return ret;
}

- (NSAttributedString *)attributedStringByAddingFontTraits:(NSDictionary<NSFontDescriptorTraitKey, id> *)traits {
    NSRange range = NSMakeRange(0, self.length);
    return [self attributedStringByAddingFontTraits:traits forRange:range];
}

/// Weight

- (NSAttributedString *)attributedStringByAddingWeight:(NSFontWeight)weight inRange:(NSRange)range {
    ///  Weight is a double between -1 and 1
    
    return [self attributedStringByAddingFontTraits:@{
        NSFontWeightTrait: @(weight),
    } forRange:range];
}
- (NSAttributedString *)attributedStringByAddingWeight:(NSFontWeight)weight {
    
    NSRange range = NSMakeRange(0, self.length);
    return [self attributedStringByAddingWeight:weight inRange:range];
}

#pragma mark Symbolic font traits
/// Symbolic font traits are an abstract and easy way to control font traits and font attributes

/// Base

- (NSAttributedString *)attributedStringByAddingSymbolicFontTraits:(NSFontDescriptorSymbolicTraits)traits forRange:(NSRange)range {
    
    NSDictionary *originalAttributes = [self attributesAtIndex:0 effectiveRange:nil];
    NSFont *originalFont = originalAttributes[NSFontAttributeName];
    if (originalFont == nil) {
        originalFont = [NSFont systemFontOfSize:NSFont.systemFontSize];
    }
    NSFontDescriptor *newFontDescriptor = [originalFont.fontDescriptor fontDescriptorWithSymbolicTraits:traits];
    NSFont *newFont = [NSFont fontWithDescriptor:newFontDescriptor size:originalFont.pointSize];
    
    NSMutableAttributedString *ret = [[NSMutableAttributedString alloc] initWithAttributedString:self];
    [ret addAttribute:NSFontAttributeName value:newFont range:range];
    
    return ret;
}
- (NSAttributedString *)attributedStringByAddingSymbolicFontTraits:(NSFontDescriptorSymbolicTraits)traits forSubstring:(NSString *)subStr {
    
    NSRange subStrRange = [self.string rangeOfString:subStr];
    return [self attributedStringByAddingSymbolicFontTraits:traits forRange:subStrRange];
}

- (NSAttributedString *)attributedStringByAddingSymbolicFontTraits:(NSFontDescriptorSymbolicTraits)traits {
    
    NSRange range = NSMakeRange(0, self.length);
    return [self attributedStringByAddingSymbolicFontTraits:traits forRange:range];
}

/// Bold

- (NSAttributedString *)attributedStringByAddingBoldForSubstring:(NSString *)subStr {
    
    NSFontDescriptorSymbolicTraits traits = NSFontDescriptorTraitBold;
    
    return [self attributedStringByAddingSymbolicFontTraits:traits forSubstring:subStr];
}

- (NSAttributedString *)attributedStringByAddingBold {
    
    NSFontDescriptorSymbolicTraits traits = NSFontDescriptorTraitBold;
    NSRange range = NSMakeRange(0, self.length);
    
    return [self attributedStringByAddingSymbolicFontTraits:traits forRange:range];
}

/// Italic

- (NSAttributedString *)attributedStringByAddingItalicForSubstring:(NSString *)subStr {
    
    NSFontDescriptorSymbolicTraits traits = NSFontDescriptorTraitItalic;
    
    return [self attributedStringByAddingSymbolicFontTraits:traits forSubstring:subStr];
}

#pragma mark Alignment

- (NSAttributedString *)attributedStringByAligningSubstring:(NSString *)subStr alignment:(NSTextAlignment)alignment {
    
    NSMutableAttributedString *ret = [[NSMutableAttributedString alloc] initWithAttributedString:self];
    NSRange subRange = [self.string rangeOfString:subStr];
    
    [self enumerateAttribute:NSParagraphStyleAttributeName inRange:subRange options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
        NSMutableParagraphStyle *newParagraphStyle = ((NSParagraphStyle *)value).mutableCopy;
        if (newParagraphStyle == nil) {
            newParagraphStyle = [NSMutableParagraphStyle new];
        }
        newParagraphStyle.alignment = alignment;
        [ret addAttribute:NSParagraphStyleAttributeName value:newParagraphStyle range:range];
    }];
    
    return ret.copy;
}

#pragma mark Weight

/// Set weight directly

- (NSMutableAttributedString *)attributedStringBySettingWeight:(NSInteger)weight forRange:(NSRange)subRange {
    /// Weight is int between 0 and 15. 5 is normal weight
    ///  I think it is more  ideal to use `attributedStringByAddingFontTraits:` (or `attributedStringByAddingWeight:` which is built on it)
    ///     This function is for legacy. It only allows 15 weights and is incompatible with NSFontWeight. NSFontManager is not intended for this I think. Remove this eventually
    
    
    NSMutableAttributedString *ret = self.mutableCopy;
    
    [self enumerateAttribute:NSFontAttributeName inRange:subRange options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
        NSFont *currentFont = (NSFont *)value;
        
        if (currentFont == nil) {
            currentFont = [NSFont systemFontOfSize:NSFont.systemFontSize];
        }
        
        NSString *fontFamily = currentFont.familyName;
        NSFontTraitMask traits = [NSFontManager.sharedFontManager traitsOfFont:currentFont];
        //        NSInteger originalWeight = [NSFontManager.sharedFontManager weightOfFont:currentFont];
        CGFloat size = currentFont.pointSize;
        
        NSFont *newFont = [NSFontManager.sharedFontManager fontWithFamily:fontFamily traits:traits weight:weight size:size];
        
        [ret addAttribute:NSFontAttributeName value:newFont range:range];
    }];
    return ret;
}

- (NSMutableAttributedString *)attributedStringBySettingWeight:(NSInteger)weight forSubstring:(NSString * _Nonnull)subStr {
    
    NSRange subRange = [self.string rangeOfString:subStr];
    return [self attributedStringBySettingWeight:weight forRange:subRange];
}

- (NSMutableAttributedString *)attributedStringBySettingWeight:(NSInteger)weight {
    
    NSRange range = NSMakeRange(0, self.length);
    return [self attributedStringBySettingWeight:weight forRange:range];
}

/// Thin

- (NSAttributedString *)attributedStringBySettingThinForSubstring:(NSString *)subStr {
    
    NSInteger weight = 3;
    
    return [self attributedStringBySettingWeight:weight forSubstring:subStr];
}

#pragma mark Font size

- (NSAttributedString *)attributedStringBySettingFontSize:(CGFloat)size {
    ///  I think it is more  ideal to use `attributedStringByAddingFontAttributes:` (ideally build a wrapper around it for setting size)
    ///     NSFontManager is not intended for this, this is probably slower than using `attributedStringByAddingFontAttributes:`.
    
    NSMutableAttributedString *ret = self.mutableCopy;
    NSRange enumerateRange = NSMakeRange(0, self.length);
    
    [self enumerateAttribute:NSFontAttributeName inRange:enumerateRange options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
        
        NSFont *currentFont = (NSFont *)value;
        if (currentFont == nil) {
            currentFont = [NSFont systemFontOfSize:NSFont.systemFontSize];
        }
            
        NSFont *newFont = [NSFont fontWithDescriptor:currentFont.fontDescriptor size:size];
        
        [ret addAttribute:NSFontAttributeName value:newFont range:range];
    }];
    
    
    return ret;
}

#pragma mark Color

- (NSAttributedString *)attributedStringBySettingSecondaryButtonTextColorForSubstring:(NSString *)subStr {
    
    NSMutableAttributedString *ret = self.mutableCopy;
    NSRange subRange = [self.string  rangeOfString:subStr];
    
    [ret addAttribute:NSForegroundColorAttributeName value:NSColor.secondaryLabelColor range:subRange];
    
    return ret;
}

#pragma mark Determine size

// Copied from here https://stackoverflow.com/a/33903242/10601702
- (NSSize)sizeAtMaxWidth:(CGFloat)maxWidth {
    
    NSTextContainer *textContainer = [[NSTextContainer alloc] initWithSize:CGSizeMake(maxWidth, CGFLOAT_MAX)];
    NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
    [layoutManager addTextContainer:textContainer];
    
    NSTextStorage *textStorage = [[NSTextStorage alloc] initWithAttributedString:self];
    [textStorage addLayoutManager:layoutManager];
    [layoutManager glyphRangeForTextContainer:textContainer];
    
    NSSize size = [layoutManager usedRectForTextContainer:textContainer].size;
    
    return size;
}

/// Old function for getting size at some max width. Cleaner than the new one in principle becuase it reuses other functions. b
/// Unfortunately it doesn't work properly because we can't get self.preferredWidth to work properly.
- (NSSize)sizeAtMaxWidthOld:(CGFloat)maxWidth {
    
    CGFloat preferredWidth = self.preferredWidth;
    
    CGFloat width = preferredWidth <= maxWidth ? preferredWidth : maxWidth;
    CGFloat height = [self heightAtWidth:width];
    
    return NSMakeSize(width, height);
}

/// Derived from sizeAtMaxWidth
- (CGFloat)heightAtWidth:(CGFloat)width {
    
    // Method 1
    NSTextStorage *textStorage = [[NSTextStorage alloc] initWithAttributedString:self];
    NSTextContainer *textContainer = [[NSTextContainer alloc] initWithContainerSize:NSMakeSize(width, FLT_MAX)];
    NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
    [layoutManager addTextContainer:textContainer];
    [textStorage addLayoutManager:layoutManager];
    [layoutManager glyphRangeForTextContainer:textContainer];
    CGFloat result1 = [layoutManager usedRectForTextContainer:textContainer].size.height;
        
    // Method 2
    NSRect bounds = [self boundingRectWithSize:NSMakeSize(width, FLT_MAX) options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading];
    CGFloat result2 = bounds.size.height; //CGRectIntegral(bounds).size.height;
    
    // ---
#if DEBUG
//    NSLog(@"NSAttributedString height for width: %f - layoutManager: %f, boundingRect: %f", width, result1, result2);
#endif
    return ceil(result2);
    // ^ Using `result1` has multiline NSTextFields clipping their last line. `result2` seems to work perfectly.
    //      > `result1` seems to be slightly too small
}

/// Width of the string if we don't introduce any extra line breaks.
/// Can't get this to work properly
- (CGFloat)preferredWidth {
    // Method 1
    NSTextStorage *textStorage = [[NSTextStorage alloc] initWithAttributedString:self];
    NSTextContainer *textContainer = [[NSTextContainer alloc] initWithContainerSize:NSMakeSize(FLT_MAX, FLT_MAX)];
    NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
    [layoutManager addTextContainer:textContainer];
    [textStorage addLayoutManager:layoutManager];
    [layoutManager glyphRangeForTextContainer:textContainer];
    CGFloat result1 = [layoutManager usedRectForTextContainer:textContainer].size.width;
    
    // Method 2
    NSRect bounds = [self boundingRectWithSize:NSMakeSize(FLT_MAX, FLT_MAX) options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading];
    bounds = NSIntegralRect(bounds);
    CGFloat result2 = bounds.size.width; //CGRectIntegral(bounds).size.height;
    
//    return floor(result1); // Need this for sizeAtMaxWidth: to work on short "Primary Button can't be used" notifications. Using result2, we'll underestimate the width needed, leading to a line break we didn't expect, leading to our calculated height to be incorrect, leading to clipping the last line.
    
    return result2 + 0;
    // Underestimates preferred width for short lines.
    // Need this for sizeAtMaxWidth: to work properly for some button capture notifications with long lines which need to be broken. Using result1, sometimes the returned line width is too wide and we end up clipping the last line because sizeAtMaxWidth doesn't get that there needs to be a line break. (That's my theory at least)
}

#pragma mark Fill out default attributes (to make size code work)

/// Fill out default attributes, because layout code won't work if the string doesn't have a font and a textColor attribute on every character. See https://stackoverflow.com/questions/13621084/boundingrectwithsize-for-nsattributedstring-returning-wrong-size
- (NSAttributedString *)attributedStringByFillingOutBase {
    
    NSFont *font = [NSFont systemFontOfSize:NSFont.systemFontSize];
    NSColor *color = NSColor.labelColor;
    NSDictionary *attributesDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                          font, NSFontAttributeName,
                                          color, NSForegroundColorAttributeName,
                                          nil];
    
    return [self attributedStringByAddingStringAttributesAsBase:attributesDictionary];
}

/// Create string by adding values from `baseAttributes`, without overriding any of the attributes set for `self`
- (NSAttributedString *)attributedStringByAddingStringAttributesAsBase:(NSDictionary<NSAttributedStringKey, id> *)baseAttributes {
    
    NSMutableAttributedString *s = self.mutableCopy;
    
    [s addAttributes:baseAttributes range:NSMakeRange(0, s.length)]; /// Base attributes will override string attributes
    [self enumerateAttributesInRange:NSMakeRange(0, s.length) options:0 usingBlock:^(NSDictionary<NSAttributedStringKey,id> * _Nonnull attrs, NSRange range, BOOL * _Nonnull stop) {
        [s addAttributes:attrs range:range];
    }]; /// Override base attributes with original string attributes to undo overrides of original string attributes
    return s.copy;
}

#pragma mark Hyperlink

- (NSAttributedString *)attributedStringByAddingLinkWithURL:(NSURL *)linkURL forSubstring:(NSString *)substring {
    
    NSMutableAttributedString *str = self.mutableCopy;
    
    NSRange foundRange = [str.mutableString rangeOfString:substring];
    NSAttributedString *linkString = [NSAttributedString hyperlinkFromString:substring withURL:linkURL];
    [str replaceCharactersInRange:foundRange withAttributedString:linkString];
    
    return str;
}

/// Copy-pasted this from somewhere
+ (NSAttributedString *)hyperlinkFromString:(NSString *)inString withURL:(NSURL *)aURL {
    
    NSMutableAttributedString *attrString = [[NSMutableAttributedString alloc] initWithString:inString.mutableCopy];
    NSRange range = NSMakeRange(0, attrString.length);
 
    [attrString beginEditing];
    [attrString addAttribute:NSLinkAttributeName value:aURL.absoluteString range:range];
 
    // Make the text appear in blue
//    [attrString addAttribute:NSForegroundColorAttributeName value:[NSColor blueColor] range:range];
 
    // Next make the text appear with an underline
//    [attrString addAttribute:NSUnderlineStyleAttributeName value:@(NSUnderlineStyleSingle) range:range];
 
    [attrString endEditing];
 
    return attrString;
}

#pragma mark String fallback for attachments

- (NSString *)coolString {
    /// Enhance the string method to support fallback values for text attachments
    ///     Can't override `- string` for some reason. Probably bc `- string` is already declared in another category or sth
    
    NSMutableString *result = [NSMutableString string];
    
    NSUInteger i = 0;
    while (true) {
        NSRange range;
        NSDictionary<NSAttributedStringKey, id> *attributes = [self attributesAtIndex:i effectiveRange:&range];
        NSTextAttachment *attachment = attributes[NSAttachmentAttributeName];
        if (attachment != nil) {
            NSString *description = attachment.image.accessibilityDescription;
            if (description != nil) {
                [result appendString:description];
            }
        } else {
            NSString *substring = [self attributedSubstringFromRange:range].string;
            [result appendString:substring];
        }
        i = NSMaxRange(range);
        if (i >= self.length) {
            break;
        }
    }
    
    return result;
}

@end
