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

/// Fill out default attributes, because layout code won't work if the string doesn't have a font and a textColor attribute on every character. See https://stackoverflow.com/questions/13621084/boundingrectwithsize-for-nsattributedstring-returning-wrong-size
- (NSAttributedString *)attributedStringByFillingOutDefaultAttributes {
    
    NSFont *font = [NSFont systemFontOfSize:NSFont.systemFontSize];
    NSColor *color = NSColor.labelColor;
    NSDictionary *attributesDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                         font, NSFontAttributeName,
                                         color, NSForegroundColorAttributeName,
                                         nil];
    
    return [self attributedStringByAddingBaseAttributes:attributesDictionary];
}

/// Create string by adding values from `baseAttributes`, without overriding any of the attributes set for `self`
- (NSAttributedString *)attributedStringByAddingBaseAttributes:(NSDictionary *)baseAttributes {
    
    NSMutableAttributedString *s = self.mutableCopy;
    
    [s addAttributes:baseAttributes range:NSMakeRange(0, s.length)]; // Base attributes will override string attributes
    [self enumerateAttributesInRange:NSMakeRange(0, s.length) options:0 usingBlock:^(NSDictionary<NSAttributedStringKey,id> * _Nonnull attrs, NSRange range, BOOL * _Nonnull stop) {
        [s addAttributes:attrs range:range];
    }]; // Override base attributes with original string attributes to undo overrides of original string attributes
    return s.copy;
}

- (NSAttributedString *)attributedStringByAddingLinkWithURL:(NSURL *)linkURL forSubstring:(NSString *)substring {
    
    NSMutableAttributedString *str = self.mutableCopy;
    
     NSRange foundRange = [str.mutableString rangeOfString:substring];
     NSAttributedString *linkString = [NSAttributedString hyperlinkFromString:substring withURL:linkURL];
     [str replaceCharactersInRange:foundRange withAttributedString:linkString];
    
     return str;
}

- (NSAttributedString *)attributedStringByAddingSymbolicFontTraits:(NSFontDescriptorSymbolicTraits)traits forSubstring:(NSString *)subStr {
    
    NSDictionary *originalAttributes = [self attributesAtIndex:0 effectiveRange:nil];
    NSFont *originalFont = originalAttributes[NSFontAttributeName];
    if (originalFont == nil) {
        originalFont = [NSFont systemFontOfSize:NSFont.systemFontSize];
    }
    NSFontDescriptor *newFontDescriptor = [originalFont.fontDescriptor fontDescriptorWithSymbolicTraits:traits];
    NSFont *newFont = [NSFont fontWithDescriptor:newFontDescriptor size:originalFont.pointSize];
    
    NSRange subStrRange = [self.string rangeOfString:subStr];
    
    NSMutableAttributedString *ret = [[NSMutableAttributedString alloc] initWithAttributedString:self];
    [ret addAttribute:NSFontAttributeName value:newFont range:subStrRange];
    
    return ret;
}

- (NSAttributedString *)attributedStringByAddingBoldForSubstring:(NSString *)subStr {
    
    NSFontDescriptorSymbolicTraits traits = NSFontDescriptorTraitBold;
    
    return [self attributedStringByAddingSymbolicFontTraits:traits forSubstring:subStr];
    
//    NSFont *boldFont = [NSFont boldSystemFontOfSize:NSFont.systemFontSize];
//    NSRange subStrRange = [self.string rangeOfString:subStr];
//
//    NSMutableAttributedString *ret = [[NSMutableAttributedString alloc] initWithAttributedString:self];
//    [ret addAttribute:NSFontAttributeName value:boldFont range:subStrRange];
//    return ret;
}

- (NSAttributedString *)attributedStringByAddingItalicForSubstring:(NSString *)subStr {
    
    NSFontDescriptorSymbolicTraits traits = NSFontDescriptorTraitItalic;
    
    return [self attributedStringByAddingSymbolicFontTraits:traits forSubstring:subStr];
}

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

- (NSMutableAttributedString *)attributedStringBySettingWeight:(NSInteger)weight forSubstring:(NSString * _Nonnull)subStr {
    
    NSMutableAttributedString *ret = self.mutableCopy;
    NSRange subRange = [self.string rangeOfString:subStr];
    
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

- (NSAttributedString *)attributedStringByAddingThinForSubstring:(NSString *)subStr {
    
    NSInteger weight = 3;
    
    return [self attributedStringBySettingWeight:weight forSubstring:subStr];
}

- (NSAttributedString *)attributedStringBySettingSecondaryButtonTextColorForSubstring:(NSString *)subStr {
    
    NSMutableAttributedString *ret = self.mutableCopy;
    NSRange subRange = [self.string  rangeOfString:subStr];
    
    [ret addAttribute:NSForegroundColorAttributeName value:NSColor.secondaryLabelColor range:subRange];
    
    return ret;
}

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

// Derived from https://stackoverflow.com/questions/2282629/how-to-get-height-for-nsattributedstring-at-a-fixed-width/2460091#2460091
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

@end
