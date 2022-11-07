//
// --------------------------------------------------------------------------
// NSAttributedString+Additions.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

#import "NSAttributedString+Additions.h"
#import <Cocoa/Cocoa.h>

#if IS_MAIN_APP
#import "Mac_Mouse_Fix-Swift.h"
#endif

#if IS_HELPER
#import "Mac_Mouse_Fix_Helper-Swift.h"
#endif

void assignAttributedStringKeepingBase(NSAttributedString *_Nonnull *_Nonnull assignee, NSAttributedString *newValue) {
    
    /// This is meant for assigning attributed strings to interface elements whose text has been styled in IB already. And where we want to keep the style from IB as base
    
    /// There are some places where we still do this manually which we could replace with this. Search for "attributesAtIndex:" to find them.
    
    /// Get old attributes
    NSAttributedString *s = *assignee;
    NSDictionary<NSAttributedStringKey, id> *oldAttributes = [s attributesAtIndex:0 effectiveRange:NULL];
    
    /// Add old attributes as base
    newValue = [newValue attributedStringByAddingStringAttributesAsBase:oldAttributes];
    
    /// Fill out base with default attributes just to be sure everything is filled out
    newValue = [newValue attributedStringByFillingOutBase];
    
    /// Assign newValue to assignee
    *assignee = newValue;
}

@implementation NSAttributedString (Additions)

#pragma mark Trim whitespace

- (NSAttributedString *)attributedStringByCapitalizingFirst {
        
    NSMutableAttributedString *s = self.mutableCopy;
    [s replaceCharactersInRange:NSMakeRange(0, 1) withString:[[s.string substringToIndex:1] localizedUppercaseString]];
    
    return s;
}

- (NSAttributedString *)attributedStringByTrimmingWhitespace {
    
    /// Deletes leading, trailing, and duplicate whitespace from a string.
    ///     "Trimming" should maybe be "stripping"? Trimming usually only refers to cutting off the leading and trailing.
    
    /// Mutable copy
    NSMutableAttributedString *s = self.mutableCopy;
    
    /// Declare chars to trim
    NSCharacterSet *whitespaceChars = NSCharacterSet.whitespaceCharacterSet; /// I don't think this contains linebreaks? Not sure.
    
    /// Loop forwards
    ///     Remove leading
    
    while (true) {
        
        /// Get next whitespace
        NSRange whitespace = [s.string rangeOfCharacterFromSet:whitespaceChars];
        
        /// Remove whitespace if leading
        ///     Break if no leading whitespace
        if (whitespace.location == 0) {
            [s deleteCharactersInRange: whitespace];
        } else {
            break;
        }
    }
    
    /// Loop backwards
    ///     Remove trailing and duplicates

    NSRange lastWhitespace = NSMakeRange(NSNotFound, 0);
    NSRange searchRange = NSMakeRange(0, s.length);
    while (true) {
        
        /// Get next range
        NSRange whitespace = [s.string rangeOfCharacterFromSet:whitespaceChars options:NSBackwardsSearch range:searchRange];
        
        /// Break
        if (whitespace.location == NSNotFound) {
            break;
        }
        
        /// Delete things
        
        BOOL deletedWhitespace = YES;
        
        if (NSMaxRange(whitespace) - 1 == s.length - 1) {
            
            /// Delete trailing
            [s deleteCharactersInRange:whitespace];
            
        } else if (NSMaxRange(whitespace) == lastWhitespace.location) {
            
            /// Delete consecutive
            [s deleteCharactersInRange:whitespace];
        
        } else {
            deletedWhitespace = NO;
        }
        
        /// Update search range
        ///     This makes the new search range go up to, but not include, the whitespace char we just processed
        searchRange = NSMakeRange(searchRange.location, whitespace.location);
        
        /// Update last
        if (!deletedWhitespace) {
            lastWhitespace = whitespace;
        } else {
            lastWhitespace.location -= 1;
        }
    }
    
    /// Return
    return s;
}

#pragma mark Append

- (NSAttributedString *)attributedStringByAppending:(NSAttributedString *)string {
    return [NSAttributedString attributedStringWithFormat:@"%@%@" args:@[self, string]];
}

#pragma mark Replace substring

+ (NSAttributedString *)attributedStringWithFormat:(NSString *)format args:(NSArray<NSAttributedString *> *)args {
        
    /// Convert format to attributed
    NSAttributedString *attributedFormat = [[NSAttributedString alloc] initWithString:format];

    /// Call core method
    return [self attributedStringWithAttributedFormat:attributedFormat args:args];
}

+ (NSAttributedString *)attributedStringWithAttributedFormat:(NSAttributedString *)format args:(NSArray<NSAttributedString *> *)args {
    
    /// Replaces occurences of %@ in the attributedString with the args
    ///     Also see lib function `initWithFormat:options:locale:`
    
    /// Early return
    if (args.count == 0) return format;
    if ([format.string isEqual:@""]) return format;
    
    /// Get mutable copy
    ///     On Ventura Beta, `format.mutableCopy` returns creates unreadable data, if format is an empty string.
    NSMutableAttributedString *mutableFormat = format.mutableCopy;
    
    /// Loop
    int i = 0;
    while (true) {
        
        /// Update replace range
        ///     Not sure if the localized is necessary/good here?
        NSRange replaceRange = [mutableFormat.string localizedStandardRangeOfString:@"%@"];
        if (replaceRange.location == NSNotFound) break;
        
        /// Replace
        [mutableFormat replaceCharactersInRange:replaceRange withAttributedString:args[i]];
        
        /// Update array index
        i++;
        if (args.count <= i) break;
    }
    
    return mutableFormat;
}

#pragma mark Padding

+ (NSAttributedString *)paddingStringWithWidth:(CGFloat)padding {
    
    /// Src: https://stackoverflow.com/a/56372833/10601702
    /// `symbolAttachment.lineLayoutPadding` is available on newer macOS versions
    /// This hasn't been working for me so far. See `stringWithSymbol:hPadding:vOffset:fallback:`
        
    /// Attempt 1
    
    NSAttributedString *paddingString = [[NSAttributedString alloc] initWithString:@"\u{200B}" attributes:@{
        NSKernAttributeName: @(padding)
    }];
    
    /// Attempt 2
    
//    unichar c[] = { NSAttachmentCharacter };
//    NSString *nonprintableString = [NSString stringWithCharacters:c length:1];
//    NSAttributedString *paddingString = [[NSAttributedString alloc] initWithString:nonprintableString attributes:@{
//        NSKernAttributeName : @(20) /// spacing in points
//    }];
    
    /// Attempt 3
    
//    NSTextAttachment *paddingAttachment = [[NSTextAttachment alloc] init];
//    paddingAttachment.bounds = NSInsetRect(NSZeroRect, -10, -10);
//    NSAttributedString *paddingString = [NSAttributedString attributedStringWithAttachment:paddingAttachment];
    
    return paddingString;
}

#pragma mark Symbols

+ (NSAttributedString *)stringWithSymbol:(NSString * _Nonnull)symbolName hPadding:(CGFloat)hPadding vOffset:(CGFloat)baselineOffset fallback:(NSString * _Nonnull)fallbackString {
    
    /// Get symbolString
    /// Primarily used by `[UIStrings stringWithSymbol:fallback:]`
    /// Larger vOffset displays higher on the screen
        
    /// Get image
    NSImage *image = [NSImage imageNamed:symbolName];
    image.accessibilityDescription = fallbackString;
    
    /// Get attachment
    NSTextAttachment *attachment = [[NSTextAttachment alloc] init];
    attachment.image = image;
    
    /// Create main string
    NSAttributedString *mainString = [NSAttributedString attributedStringWithAttachment:attachment];
    
    /// Add baseLineOffset
    ///     Using `symbolAttachment.bounds` made the string not display in my testing.
    mainString = [mainString attributedStringByAddingBaseLineOffset:baselineOffset];
    
    /// Add padding
    ///     This doesn't work (trying to use from `ScrollTabController.swift` to display a `ToastNofification`. Maybe the notification overrides the attributes or something? However I think the vertical spacing in the notification changes when we set kerning. Weirddd.)
    /// Using `paddingStringWithWidth:` to create separate padding strings didn't work either.
    mainString = [mainString attributedStringByAddingStringAttributes:@{
            NSKernAttributeName: @(hPadding)
    } forRange:NSMakeRange(0, mainString.length)];
    
    /// Return
    return mainString;
}

#pragma mark Markdown

+ (NSAttributedString *)labelWithMarkdown:(NSString *)md {
    return [self attributedStringWithCoolMarkdown:md];
}
+ (NSAttributedString *)secondaryLabelWithMarkdown:(NSString *)md {
    NSAttributedString *s = [self attributedStringWithCoolMarkdown:md];
    s = [s attributedStringBySettingFontSize:11];
    s = [s attributedStringBySettingSecondaryLabelColorForSubstring:s.string];
    return s;
}

+ (NSAttributedString * _Nullable)attributedStringWithCoolMarkdown:(NSString *)md {
    
    return [self attributedStringWithCoolMarkdown:md fillOutBase:YES];
}

+ (NSAttributedString * _Nullable)attributedStringWithCoolMarkdown:(NSString *)md fillOutBase:(BOOL)fillOutBase {
    
    NSAttributedString *result = nil;
    
    if ((NO)) {
        
        /// Never use Apple API, always use custom method - so things are consistent across versions and we can catch issues witht custom version during development
//
//        /// Use library function
//
//        /// Create options object
//        NSAttributedStringMarkdownParsingOptions *options = [[NSAttributedStringMarkdownParsingOptions alloc] init];
//
//        /// No idea what these do
//        options.allowsExtendedAttributes = NO;
//        options.appliesSourcePositionAttributes = NO;
//
//        /// Make it respect linebreaks
//        options.interpretedSyntax = NSAttributedStringMarkdownInterpretedSyntaxInlineOnlyPreservingWhitespace;
//
//        /// Create string
//        result = [[NSAttributedString alloc] initWithMarkdownString:md options:options baseURL:[NSURL URLWithString:@""] error:nil];
        
    } else {
        
        /// Fallback to custom function
        
        result = [MarkdownParser attributedStringWithMarkdown:md];
    }
    
    if (fillOutBase) {
        result = [result attributedStringByFillingOutBase];
    }
    
    return result;
}

#pragma mark Attributed string attributes
    
- (NSAttributedString *)attributedStringByAddingStringAttributes:(NSDictionary<NSAttributedStringKey, id> *)attributes forRange:(NSRange)range {
    
    /// Create mutable copy
    NSMutableAttributedString *ret = self.mutableCopy;
    
    /// Call lib method
    [ret addAttributes:attributes range:range];
    
    /// Return
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

- (NSAttributedString *)attributedStringByAddingSemiBoldForSubstring:(NSString *)subStr {
    double weight = 7; // 8;
    return [self attributedStringBySettingWeight:weight forSubstring:subStr];
}

- (NSAttributedString *)attributedStringBySettingSemiBoldColorForSubstring:(NSString *)subStr {
    /// I can't really get a semibold. It's too thick or too thin. So I'm trying to make it appear thicker by darkening the color.
    
    NSMutableAttributedString *ret = self.mutableCopy;
    NSRange subRange = [self.string rangeOfString:subStr];
    
    NSColor *color;
    
//    color = [NSColor.textColor colorWithAlphaComponent:1.0]; /// Custom colors disable the automatic color inversion when selecting a tableViewCell. See https://stackoverflow.com/a/29860102/10601702
    color = NSColor.controlTextColor; /// This is almost black and automatically inverts. See: http://sethwillits.com/temp/nscolor/
    
    [ret addAttribute:NSForegroundColorAttributeName value:color range:subRange];
    
    return ret;
}
/// Italic

- (NSAttributedString *)attributedStringByAddingItalicForSubstring:(NSString *)subStr {
    
    NSFontDescriptorSymbolicTraits traits = NSFontDescriptorTraitItalic;
    
    return [self attributedStringByAddingSymbolicFontTraits:traits forSubstring:subStr];
}

#pragma mark Alignment

- (NSAttributedString *)attributedStringByAligningSubstring:(NSString * _Nullable)subStr alignment:(NSTextAlignment)alignment {
    
    /// Pass in nil for the subStr for the whole string
    
    NSMutableAttributedString *ret = [[NSMutableAttributedString alloc] initWithAttributedString:self];
    
    NSRange subRange;
    if (subStr == nil) {
        subRange = NSMakeRange(0, self.length);
    } else {
        subRange = [self.string rangeOfString:subStr];
    }
    
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

- (NSAttributedString *)attributedStringBySettingSecondaryLabelColorForSubstring:(NSString * _Nullable)subStr {
    /// Pass nil for the substring to set for the whole string
    
    NSMutableAttributedString *ret = self.mutableCopy;
    NSRange subRange;
    if (subStr == nil) {
        subRange = NSMakeRange(0, self.length);
    } else {
        subRange = [self.string rangeOfString:subStr];
    }
    
    [ret addAttribute:NSForegroundColorAttributeName value:NSColor.secondaryLabelColor range:subRange];
    
    return ret;
}

#pragma mark Determine size

- (NSSize)sizeAtMaxWidth:(CGFloat)maxWidth {
    /// Copied from here https://stackoverflow.com/a/33903242/10601702
    
    NSTextContainer *textContainer = [[NSTextContainer alloc] initWithSize:CGSizeMake(maxWidth, CGFLOAT_MAX)];
    NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
    [layoutManager addTextContainer:textContainer];

    NSTextStorage *textStorage = [[NSTextStorage alloc] initWithAttributedString:self];
    [textStorage addLayoutManager:layoutManager];
    [layoutManager glyphRangeForTextContainer:textContainer];
    
    NSSize size = [layoutManager usedRectForTextContainer:textContainer].size;
    
    return size;
}

- (NSSize)sizeAtMaxWidthOld:(CGFloat)maxWidth {
    /// Old function for getting size at some max width. Cleaner than the new one in principle becuase it reuses other functions. b
    /// Unfortunately it doesn't work properly because we can't get self.preferredWidth to work properly.
    
    CGFloat preferredWidth = self.preferredWidth;
    
    CGFloat width = preferredWidth <= maxWidth ? preferredWidth : maxWidth;
    CGFloat height = [self heightAtWidth:width];
    
    return NSMakeSize(width, height);
}

- (CGFloat)heightAtWidth:(CGFloat)width {
    /// Derived from sizeAtMaxWidth
    
    /// Method 1
//    NSTextStorage *textStorage = [[NSTextStorage alloc] initWithAttributedString:self];
//    NSTextContainer *textContainer = [[NSTextContainer alloc] initWithContainerSize:NSMakeSize(width, FLT_MAX)];
//    NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
//    [layoutManager addTextContainer:textContainer];
//    [textStorage addLayoutManager:layoutManager];
//    [layoutManager glyphRangeForTextContainer:textContainer];
//    CGFloat result1 = [layoutManager usedRectForTextContainer:textContainer].size.height;
        
    /// Method 2
    NSRect bounds = [self boundingRectWithSize:NSMakeSize(width, FLT_MAX) options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading];
    CGFloat result2 = bounds.size.height; //CGRectIntegral(bounds).size.height;
    
    // ---
//    DDLogDebug(@"NSAttributedString height for width: %f - layoutManager: %f, boundingRect: %f", width, result1, result2);
    return ceil(result2);
    // ^ Using `result1` has multiline NSTextFields clipping their last line. `result2` seems to work perfectly.
    //      > `result1` seems to be slightly too small
}


- (CGFloat)preferredWidth {
    /// Width of the string if we don't introduce any extra line breaks.
    /// Can't get this to work properly
    
    /// Method 1
//    NSTextStorage *textStorage = [[NSTextStorage alloc] initWithAttributedString:self];
//    NSTextContainer *textContainer = [[NSTextContainer alloc] initWithContainerSize:NSMakeSize(FLT_MAX, FLT_MAX)];
//    NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
//    [layoutManager addTextContainer:textContainer];
//    [textStorage addLayoutManager:layoutManager];
//    [layoutManager glyphRangeForTextContainer:textContainer];
//    CGFloat result1 = [layoutManager usedRectForTextContainer:textContainer].size.width;
    
    /// Method 2
    NSRect bounds = [self boundingRectWithSize:NSMakeSize(FLT_MAX, FLT_MAX) options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading];
    bounds = NSIntegralRect(bounds);
    CGFloat result2 = bounds.size.width; //CGRectIntegral(bounds).size.height;
    
//    return floor(result1); // Need this for sizeAtMaxWidth: to work on short "Primary Button can't be used" notifications. Using result2, we'll underestimate the width needed, leading to a line break we didn't expect, leading to our calculated height to be incorrect, leading to clipping the last line.
    
    return result2 + 0;
    /// Underestimates preferred width for short lines.
    /// Need this for sizeAtMaxWidth: to work properly for some button capture notifications with long lines which need to be broken. Using result1, sometimes the returned line width is too wide and we end up clipping the last line because sizeAtMaxWidth doesn't get that there needs to be a line break. (That's my theory at least)
}

#pragma mark Fill out default attributes (to make size code work)

- (NSAttributedString *)attributedStringByFillingOutBase {

    /// Fill out default attributes, because layout code won't work if the string doesn't have a font and a textColor attribute on every character. See https://stackoverflow.com/questions/13621084/boundingrectwithsize-for-nsattributedstring-returning-wrong-size
    
    NSDictionary *attributesDictionary = @{
        NSFontAttributeName: [NSFont systemFontOfSize:NSFont.systemFontSize],
        NSForegroundColorAttributeName: NSColor.labelColor,
        NSFontWeightTrait: @(NSFontWeightMedium),
    };
    
    return [self attributedStringByAddingStringAttributesAsBase:attributesDictionary];
}

- (NSAttributedString *)attributedStringByFillingOutBaseAsHint {

    NSDictionary *attributesDictionary = @{
        NSFontAttributeName: [NSFont systemFontOfSize:NSFont.smallSystemFontSize],
        NSForegroundColorAttributeName: NSColor.secondaryLabelColor,
        NSFontWeightTrait: @(NSFontWeightRegular), /// Not sure whether to use medium or regular here
    };
    
    return [self attributedStringByAddingStringAttributesAsBase:attributesDictionary];
}

- (NSAttributedString *)attributedStringByAddingStringAttributesAsBase:(NSDictionary<NSAttributedStringKey, id> *)baseAttributes {

    /// Create string by adding values from `baseAttributes`, without overriding any of the attributes set for `self`
    
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

+ (NSAttributedString *)hyperlinkFromString:(NSString *)inString withURL:(NSURL *)aURL {
    /// Copy-pasted this from somewhere
    
    NSMutableAttributedString *attrString = [[NSMutableAttributedString alloc] initWithString:inString.mutableCopy];
    NSRange range = NSMakeRange(0, attrString.length);
 
    [attrString beginEditing];
    [attrString addAttribute:NSLinkAttributeName value:aURL.absoluteString range:range];
 
    /// Make the text appear in blue
    ///     This doesn't seem to be necessary. The links will still be blue if we don't do this.
//    [attrString addAttribute:NSForegroundColorAttributeName value:[NSColor blueColor] range:range];
 
    /// Next make the text appear with an underline
    ///     This is unnecessary in NSTextView but necessary in NSTextField
    [attrString addAttribute:NSUnderlineStyleAttributeName value:@(NSUnderlineStyleSingle) range:range];
 
    [attrString endEditing];
 
    return attrString;
}

#pragma mark String fallback for attachments

- (NSString *)stringWithAttachmentDescriptions {
    /// NSStrings can't display attachments. This method inserts a description of the attachment where the attachment would be in the attributedString.
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
