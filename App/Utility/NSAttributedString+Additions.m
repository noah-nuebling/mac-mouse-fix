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

- (NSAttributedString *)attributedStringByAddingLinkWithURL:(NSURL *)linkURL forSubstring:(NSString *)substring {
    
    NSMutableAttributedString *str = self.mutableCopy;
    
     NSRange foundRange = [str.mutableString rangeOfString:substring];
     if (foundRange.location != NSNotFound) {
         NSAttributedString *linkString = [NSAttributedString hyperlinkFromString:substring withURL:linkURL];
         [str replaceCharactersInRange:foundRange withAttributedString:linkString];
     }
     return str;
}

+(id)hyperlinkFromString:(NSString *)inString withURL:(NSURL *)aURL {
    
    NSMutableAttributedString *attrString = [[NSMutableAttributedString alloc] initWithString:inString.mutableCopy];
    NSRange range = NSMakeRange(0, attrString.length);
 
    [attrString beginEditing];
    [attrString addAttribute:NSLinkAttributeName value:aURL.absoluteString range:range];
 
    // make the text appear in blue
    [attrString addAttribute:NSForegroundColorAttributeName value:[NSColor blueColor] range:range];
 
    // next make the text appear with an underline
    [attrString addAttribute:
            NSUnderlineStyleAttributeName value:[NSNumber numberWithInt:NSSingleUnderlineStyle] range:range];
 
    [attrString endEditing];
 
    return attrString;
}

- (NSSize)sizeAtMaxWidth:(CGFloat)maxWidth {
    
    CGFloat width = self.width <= maxWidth ? self.width : maxWidth;
    CGFloat height = [self heightAtWidth:width];
    
    return NSMakeSize(width, height);
}

// Derived from https://stackoverflow.com/questions/2282629/how-to-get-height-for-nsattributedstring-at-a-fixed-width/2460091#2460091
// 
- (CGFloat)heightAtWidth:(CGFloat)width {
    
    // Method 1
    NSTextStorage *textStorage = [[NSTextStorage alloc] initWithAttributedString:self];
    NSTextContainer *textContainer = [[NSTextContainer alloc] initWithContainerSize:
        NSMakeSize(width, FLT_MAX)];
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
    NSLog(@"NSAttributedString height for width: %f - layoutManager: %f, boundingRect: %f", width, result1, result2);
#endif
    return ceil(result1);
}

- (CGFloat)width {
    // Method 1
    NSTextStorage *textStorage = [[NSTextStorage alloc] initWithAttributedString:self];
    NSTextContainer *textContainer = [[NSTextContainer alloc] initWithContainerSize:
        NSMakeSize(FLT_MAX, FLT_MAX)];
    NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
    [layoutManager addTextContainer:textContainer];
    [textStorage addLayoutManager:layoutManager];
    [layoutManager glyphRangeForTextContainer:textContainer];
    CGFloat result1 = [layoutManager usedRectForTextContainer:textContainer].size.width;
    
    return ceil(result1);
}


@end
