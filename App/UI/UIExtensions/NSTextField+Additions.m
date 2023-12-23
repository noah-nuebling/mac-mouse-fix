//
// --------------------------------------------------------------------------
// NSTextField+Additions.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "NSTextField+Additions.h"

@implementation NSTextField (Additions)

// Copy paste template for adding attributes to an attributed string. Contains all possible attributes

//    [str addAttributes:@{
//        NSFontAttributeName:                NSNull.null,
//        NSParagraphStyleAttributeName:      NSNull.null,
//        NSForegroundColorAttributeName:     NSNull.null,
//        NSBackgroundColorAttributeName:     NSNull.null,
//        NSLigatureAttributeName:            NSNull.null,
//        NSKernAttributeName:                NSNull.null,
//        NSStrikethroughStyleAttributeName:  NSNull.null,
//        NSUnderlineStyleAttributeName:      NSNull.null,
//        NSStrokeColorAttributeName:         NSNull.null,
//        NSStrokeWidthAttributeName:         NSNull.null,
//        NSShadowAttributeName:              NSNull.null,
//        NSTextEffectAttributeName:          NSNull.null,
//        NSAttachmentAttributeName:          NSNull.null,
//        NSLinkAttributeName:                NSNull.null,
//        NSBaselineOffsetAttributeName:      NSNull.null,
//        NSUnderlineColorAttributeName:      NSNull.null,
//        NSStrikethroughColorAttributeName:  NSNull.null,
//        NSObliquenessAttributeName:         NSNull.null,
//        NSExpansionAttributeName:           NSNull.null,
//        NSWritingDirectionAttributeName:    NSNull.null,
//        NSVerticalGlyphFormAttributeName:   NSNull.null,
//    } range:NSMakeRange(0, str.length)];

/// In my testing NSTextField.attributedStringValue actually returned a string without _any_ attributes. Not even a font or anything.
/// This lead to issues when trying to calculate the fitting height for a certain width of the NSTextField.
/// This function takes some of the properties of the NSTextField and returns an NSAttributed string based on those.
/// The returned attributed string describes the way that the text of the NSTextField is rendered much closer,.
- (NSAttributedString *)effectiveAttributedStringValue {
    
    NSMutableAttributedString *str = self.attributedStringValue.mutableCopy;

    // Create paragraph style from NSTextField properties
    
    // Not sure if we're setting these properties correctly, and there could be more properties we should be setting
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.alignment = self.alignment;
    paragraphStyle.baseWritingDirection = self.baseWritingDirection;
    paragraphStyle.lineBreakMode = self.lineBreakMode;
    paragraphStyle.allowsDefaultTighteningForTruncation = self.allowsDefaultTighteningForTruncation;
    if (@available(macOS 10.15, *)) paragraphStyle.lineBreakStrategy = self.lineBreakStrategy;
    
    // Add attributes to AttributedString based on NSTextField properties
     
    [str addAttributes:@{
        NSFontAttributeName:                self.font,
        NSParagraphStyleAttributeName:      paragraphStyle,
        NSForegroundColorAttributeName:     self.textColor,
        NSBackgroundColorAttributeName:     self.backgroundColor,
//        NSLigatureAttributeName:            NSNull.null,
//        NSKernAttributeName:                NSNull.null,
//        NSStrikethroughStyleAttributeName:  NSNull.null,
//        NSUnderlineStyleAttributeName:      NSNull.null,
//        NSStrokeColorAttributeName:         NSNull.null,
//        NSStrokeWidthAttributeName:         NSNull.null,
//        NSShadowAttributeName:              NSNull.null, //self.shadow,
//        NSTextEffectAttributeName:          NSNull.null,
//        NSAttachmentAttributeName:          NSNull.null,
//        NSLinkAttributeName:                NSNull.null,
//        NSBaselineOffsetAttributeName:      NSNull.null, //self.baselineOffsetFromBottom,
//        NSUnderlineColorAttributeName:      NSNull.null,
//        NSStrikethroughColorAttributeName:  NSNull.null,
//        NSObliquenessAttributeName:         NSNull.null,
//        NSExpansionAttributeName:           NSNull.null,
//        NSWritingDirectionAttributeName:    NSNull.null, //self.baseWritingDirection,
//        NSVerticalGlyphFormAttributeName:   NSNull.null,
    } range:NSMakeRange(0, str.length)];
    
    // return NSAttributedString
    
    return str;
    
}

@end
