//
// --------------------------------------------------------------------------
// NSAttributedString+Additions.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "NSAttributedString+Additions.h"
#import <Cocoa/Cocoa.h>
#import "MarkdownParser/MarkdownParser.h"

#if IS_MAIN_APP
#import "Mac_Mouse_Fix-Swift.h"
#endif

#if IS_HELPER
#import "Mac_Mouse_Fix_Helper-Swift.h"
#endif

@implementation NSAttributedString (Additions)

#pragma mark Trim whitespace

- (NSAttributedString *)attributedStringByCapitalizingFirst {
    
    if (self.length == 0) {
        return self.copy;
    }
    
    NSMutableAttributedString *s = self.mutableCopy;
    [s replaceCharactersInRange:NSMakeRange(0, 1) withString:[[s.string substringToIndex:1] localizedUppercaseString]];
    
    return s;
}

- (NSAttributedString *)attributedStringByRemovingAllWhitespace {
    
    ///
    /// Remove all whitespace and newline chars from the string
    ///
    
    NSCharacterSet *whitespaceAndNewlineChars = NSCharacterSet.whitespaceAndNewlineCharacterSet;
    
    NSMutableAttributedString *s = self.mutableCopy;
    NSRange searchRange = NSMakeRange(0, s.length);
    
    while (true) {
        NSRange whitespace = [s.string rangeOfCharacterFromSet:whitespaceAndNewlineChars options:0 range:searchRange];
        if (whitespace.location == NSNotFound) break;
        [s deleteCharactersInRange:whitespace];
        searchRange = NSMakeRange(whitespace.location, s.length - whitespace.location);
        assert(searchRange.location + searchRange.length == s.length); /// End of the search range should always be the end of the string
    }
    
    return s;
}

- (NSAttributedString *)attributedStringByTrimmingWhitespace {
    
    /// Deletes leading, trailing, and duplicate whitespace from a string.
    ///     Also removes leading and trailling newlines (but not duplicate newlines)
    ///     "Trimming" should maybe be "stripping"? Trimming usually only refers to cutting off the leading and trailing.
    ///     
    ///     Performance:
    ///     - I was somehow worrying about the performance of this but I used an MFBenchmark and it takes 0.003 ms on averate (3/1000 of a millisecond), so nothing to worry about.
    
    
    /// Mutable copy
    NSMutableAttributedString *s = [self mutableCopy];
    
    /// Handle edge case
    if (self.length == 0) {
        return s;
    }
    
    /// Declare chars to trim
    NSCharacterSet *whitespaceChars = NSCharacterSet.whitespaceCharacterSet;
    NSCharacterSet *whitespaceAndNewlineChars = NSCharacterSet.whitespaceAndNewlineCharacterSet;
    
    /// Count leading whitespace
    NSInteger i = 0;
    while (true) {
        
        /// Break
        if (i >= s.length) break;
        
        /// Get c
        unichar c = [s.string characterAtIndex:i];
        
        /// Break
        BOOL isWhitespace = [whitespaceAndNewlineChars characterIsMember:c];
        if (!isWhitespace) break;
        
        /// Increment
        i++;
    }
    /// Remove leading whitespace
    if (i > 0) {
        [s deleteCharactersInRange:NSMakeRange(0, i)];
    }
    
    if ((YES)) {
        
        ///
        /// New implementation
        ///
        
        /// Count trailing whitespace
        i = s.length - 1;
        while (true) {
            
            /// Break
            if (i < 0) break;
            
            /// Get c
            unichar c = [s.string characterAtIndex:i];
            
            /// Break
            BOOL isWhitespace = [whitespaceAndNewlineChars characterIsMember:c];
            if (!isWhitespace) break;
            
            /// Decrement
            i--;
        }
        /// Remove trailling whitespace
        if (i < s.length - 1) {
            NSInteger nOfTraillingWhitespaces = (s.length - 1) - i; /// We started i at s.length-1, and decremented it for every whitespace char we found.
            NSRange trailingWSRange = NSMakeRange(s.length - nOfTraillingWhitespaces, nOfTraillingWhitespaces);
            assert(trailingWSRange.location + trailingWSRange.length == s.length); /// The range should end at the end of the string.
            [s deleteCharactersInRange:trailingWSRange];
        }
        
        /// Remove duplicates
        ///     Note how we're using `whitespaceChars` here not `whitespaceAndNewlineChars`. Since we don't want to remove double linebreaks.
        ///     This
        NSInteger i = 0;
        while (true) {
            
            /// Break
            ///     Only continue if there are at least two chars left in the string that we haven't looked at
            BOOL cIsBeforeLastChar = i < s.length - 1;
            if (!cIsBeforeLastChar) break;
            
            /// Check `str[i]` isWhitespace?
            unichar c = [s.string characterAtIndex:i];
            BOOL cIsWhitespace = [whitespaceChars characterIsMember:c];
            if (cIsWhitespace) {
                
                /// Check `str[i+1]` isWhitespace?
                unichar d = [s.string characterAtIndex:i+1];
                BOOL dIsWhitespace = [whitespaceChars characterIsMember:d];
                if (dIsWhitespace) {
                    /// Found duplicate whitespace - delete the first one!
                    [s deleteCharactersInRange:NSMakeRange(i, 1)];
                } else {
                    /// Found non-duplicate whitespace
                    i++;
                }
            } else {
                /// Found non-whitespace
                i++;
            }
        }
        
    } else { /// If NO
        
        /// Old backwards looping implementation
        ///     (Might be more efficient, since it does duplicate removal and removal of trailing chars in one, but it's harder to read, and doesn't let us apply different character sets for trailing removal vs duplicate removal)
        
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
    
    /// Use SFSymbolStrings instead of this
    
    abort();
    
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
    mainString = [mainString attributedStringByAddingBaseLineOffset:baselineOffset forRange:NULL];
    
    /// Add padding
    ///     This doesn't work (trying to use from `ScrollTabController.swift` to display a `ToastNofification`. Maybe the notification overrides the attributes or something? However I think the vertical spacing in the notification changes when we set kerning. Weirddd.)
    /// Using `paddingStringWithWidth:` to create separate padding strings didn't work either.
    mainString = [mainString attributedStringByAddingStringAttributes:@{
        NSKernAttributeName: @(hPadding)
    } forRange:NULL];
    
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
    s = [s attributedStringByAddingColor:NSColor.secondaryLabelColor forRange:NULL];
    
    return s;
}

+ (NSAttributedString *_Nullable)attributedStringWithAttributedMarkdown:(NSAttributedString *)md {
    return [MarkdownParser attributedStringWithAttributedMarkdown:md];
}

+ (NSAttributedString *_Nullable)attributedStringWithCoolMarkdown:(NSString *)md {
    
    return [self attributedStringWithCoolMarkdown:md fillOutBase:YES];
}

+ (NSAttributedString *_Nullable)attributedStringWithCoolMarkdown:(NSString *)md fillOutBase:(BOOL)fillOutBase {
    
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

#pragma mark Determine size

- (NSSize)sizeAtMaxWidth:(CGFloat)maxWidth {
    
    /// Notes:
    /// - Why didn't we use the native `boundingRectWithSize:`? Was there really no way to make it work? Well this works so no need to change it.
    
    if (@available(macOS 12.0, *)) {
        
        /// TextKit 2 Implementation
        ///     v2 APIs were introduced in macOS 12
        ///     See WWDC intro: https://developer.apple.com/videos/play/wwdc2021/10061/
        
        ///
        /// Create objects
        ///
        
        /// Create v2 layoutMgr
        NSTextLayoutManager *textLayoutManager = [[NSTextLayoutManager alloc] init];
        
        /// Create v2 contentMgr
        NSTextContentStorage *textContentStorage = [[NSTextContentStorage alloc] init];
        
        /// Create container
        NSTextContainer *textContainer = [[NSTextContainer alloc] initWithSize:CGSizeMake(maxWidth, CGFLOAT_MAX)]; /// `initWithContainerSize:` was deprecated in macOS 12
        
        ///
        /// Link objects
        ///
        
        /// Link contentMgr -> self
        [textContentStorage setAttributedString:self];
        
        /// Link layoutMgr -> container
        [textLayoutManager setTextContainer:textContainer];
        
        /// Link layoutMgr -> contentMgr
        [textLayoutManager replaceTextContentManager:textContentStorage];
        [textContentStorage setPrimaryTextLayoutManager:textLayoutManager]; /// Not sure if necessary
        
        ///
        /// Get size from layoutMgr
        ///
        
        /// On options:
        ///     - `NSTextLayoutFragmentEnumerationOptionsEnsuresExtraLineFragment` is for ensuring layout consistency with editable text, which we don't need here.
        ///     - `NSTextLayoutFragmentEnumerationOptionsEstimatesSize` is a faster, but less accurate alternative to `NSTextLayoutFragmentEnumerationOptionsEnsuresLayout`
        
        __block NSRect resultRect = NSZeroRect;
        NSTextLayoutFragmentEnumerationOptions enumerationOptions = NSTextLayoutFragmentEnumerationOptionsEnsuresLayout;
        [textLayoutManager enumerateTextLayoutFragmentsFromLocation:nil options:enumerationOptions usingBlock:^BOOL(NSTextLayoutFragment * _Nonnull layoutFragment) {
            resultRect = NSUnionRect(resultRect, layoutFragment.layoutFragmentFrame);
            return YES;
        }];
        
        ///
        /// Return
        ///
        return resultRect.size;
        
    } else {

        /// TextKit v1 implementation
        ///     Originally Copied from here https://stackoverflow.com/a/33903242/10601702
        
        ///
        /// Create objects
        ///
        
        /// Create layoutMgr
        NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];

        /// Create content
        NSTextStorage *textStorage = [[NSTextStorage alloc] init];
        
        /// Create container
        NSTextContainer *textContainer = [[NSTextContainer alloc] initWithSize:CGSizeMake(maxWidth, CGFLOAT_MAX)];

        
        ///
        /// Link objects
        ///
        
        /// Link content -> self
        [textStorage setAttributedString:self]; /// This needs to happen before other linking steps, otherwise it won't work. Not sure why.
        
        /// Link layoutMgr -> container
        [layoutManager addTextContainer:textContainer];
        
        /// Link layoutMgr -> content
        [layoutManager replaceTextStorage:textStorage];
        [textStorage addLayoutManager:layoutManager]; /// Not sure if necessary

        ///
        /// Force glyph generation & layout
        ///
        NSInteger numberOfGlyphs = [layoutManager numberOfGlyphs];                  /// Forces glyph generation
        [layoutManager ensureLayoutForGlyphRange:NSMakeRange(0, numberOfGlyphs)];   /// Forces layout
        
        ///
        /// Get size from layoutMgr
        ///
        NSSize size = [layoutManager usedRectForTextContainer:textContainer].size;
        
        ///
        /// Return
        ///
        return size;
    }

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
    CGFloat result2 = bounds.size.width; /// CGRectIntegral(bounds).size.height;
    
    //    return floor(result1); // Need this for sizeAtMaxWidth: to work on short "Primary Button can't be used" notifications. Using result2, we'll underestimate the width needed, leading to a line break we didn't expect, leading to our calculated height to be incorrect, leading to clipping the last line.
    
    return result2 + 0;
    /// Underestimates preferred width for short lines.
    /// Need this for sizeAtMaxWidth: to work properly for some button capture notifications with long lines which need to be broken. Using result1, sometimes the returned line width is too wide and we end up clipping the last line because sizeAtMaxWidth doesn't get that there needs to be a line break. (That's my theory at least)
}

#pragma mark Fill out base
/// Need this to make size code work

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
    
    return s.copy; /// Why are we copying here?
}

#pragma mark Assign while keeping base

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

#pragma mark Attachment fallback

- (NSString *)stringWithAttachmentDescriptions {
    /// NSStrings can't display attachments. This method inserts a description of the attachment where the attachment would be in the attributedString.
    ///     Can't override `- string` for some reason. Probably bc `- string` is already declared in another category or sth
    
    NSMutableString *result = [NSMutableString string];
    
    NSUInteger i = 0;
    while (true) {
        if (i >= self.length) break;
        
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
    }
    
    return result;
}

#pragma mark - CORE: String attrs
///


- (NSAttributedString *)attributedStringByAddingStringAttributes:(NSDictionary<NSAttributedStringKey, id> *)attributes forRange:(const NSRangePointer _Nullable)inRange {
    
    /// Set range to cover whole string if NULL
    
    NSRange range;
    if (inRange == NULL) {
        range = NSMakeRange(0, self.length);
    } else {
        range = *inRange;
    }
    
    /// Create mutable copy
    NSMutableAttributedString *ret = self.mutableCopy;
    
    /// Call lib method
    [ret addAttributes:attributes range:range];
    
    /// Return
    return ret;
}

- (NSAttributedString *)attributedStringByAddingStringAttributes:(NSDictionary<NSAttributedStringKey, id> *)attributes forSubstring:(NSString *)substring {
    
    NSRange range = [self.string rangeOfString:substring];
    return [self attributedStringByAddingStringAttributes:attributes forRange:&range];
}

#pragma mark Color

- (NSAttributedString *)attributedStringByAddingColor:(NSColor *)color forSubstring:(NSString *)subStr {
    
    assert(subStr != nil);
    
    return [self attributedStringByAddingStringAttributes:@{
        NSForegroundColorAttributeName: color //NSColor.secondaryLabelColor
    } forSubstring:subStr];
}

- (NSAttributedString *)attributedStringByAddingColor:(NSColor *)color forRange:(const NSRangePointer _Nullable)range {
    
    return [self attributedStringByAddingStringAttributes:@{
        NSForegroundColorAttributeName: color //NSColor.secondaryLabelColor
    } forRange:range];
}

#pragma mark Baseline offset

- (NSAttributedString *)attributedStringByAddingBaseLineOffset:(CGFloat)offset forRange:(const NSRangePointer _Nullable)range {
    /// Offset in points
    
    return [self attributedStringByAddingStringAttributes:@{
        NSBaselineOffsetAttributeName: @(offset),
    } forRange:range];
}

#pragma mark Hyperlink

+ (NSAttributedString *)hyperlinkFromString:(NSString *)inString withURL:(NSURL *)url {
    
    /// Note: is .mutableCopy really necessary here?
    NSAttributedString *string = [[NSAttributedString alloc] initWithString:inString];
    string = [string attributedStringByAddingHyperlink:url forRange:NULL];
    
    return string;
}

- (NSAttributedString *)attributedStringByAddingHyperlink:(NSURL *)url forSubstring:(NSString *)substring {
    
    NSRange subRange = [self.string rangeOfString:substring];
    return [self attributedStringByAddingHyperlink:url forRange:&subRange];
}

- (NSAttributedString *)attributedStringByAddingHyperlink:(NSURL *_Nonnull)aURL forRange:(const NSRangePointer _Nullable)range {
    
    /// Notes:
    /// - Making the text blue explicitly doesn't seem to be necessary. The links will still be blue if we don't do this.
    /// - Adding an underline explicitlyis unnecessary in NSTextView but necessary in NSTextField
    
    return [self attributedStringByAddingStringAttributes:@{
        NSLinkAttributeName: aURL.absoluteString,
        NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle),
        //        NSForegroundColorAttributeName: NSColor.blueColor,
    } forRange:range];
}


- (NSAttributedString *)attributedStringByAddingFont:(NSFont *)font forRange:(const NSRangePointer _Nullable)range {
    
    NSAttributedString *result = [self attributedStringByAddingStringAttributes:@{
        NSFontAttributeName: font,
    } forRange:range];
    
    return result;
}


#pragma mark - META CORE: Modify attrs

- (NSAttributedString *)attributedStringByModifyingAttribute:(NSAttributedStringKey)attribute forRange:(const NSRangePointer _Nullable)inRange modifier:(id _Nullable (^)(id _Nullable attributeValue))modifier {
    
    NSRange range;
    if (inRange == NULL) {
        range = NSMakeRange(0, self.length);
    } else {
        range = *inRange;
    }
    
    NSMutableAttributedString *result = self.mutableCopy;
    
    [self enumerateAttribute:attribute inRange:range options:0 usingBlock:^(id _Nullable value, NSRange range, BOOL * _Nonnull stop) {
        
        /// Notes:
        /// Should we pass in `stop` to the callback?
        /// Do we need to copy the value or sth?
        
        id newValue = modifier(value);
        [result addAttribute:attribute value:newValue range:range];
    }];
    
    return result;
}

- (NSAttributedString *)attributedStringByModifyingAttribute:(NSAttributedStringKey)attribute forSubstring:(NSString *)substring modifier:(id _Nullable(^)(id _Nullable attributeValue))modifier {
    
    NSRange range = [self.string rangeOfString:substring];
    return [self attributedStringByModifyingAttribute:attribute forRange:&range modifier:modifier];
}

#pragma mark - CORE: Paragraph style

- (NSAttributedString *)attributedStringByModifyingParagraphStyleForRange:(const NSRangePointer _Nullable)inRange modifier:(NSParagraphStyle *_Nullable (^)(NSMutableParagraphStyle *_Nullable style))modifier {
    
    return [self attributedStringByModifyingAttribute:NSParagraphStyleAttributeName forRange:inRange modifier:^id _Nullable(id  _Nullable attributeValue) {
        
        NSMutableParagraphStyle *newValue = ((NSMutableParagraphStyle *)attributeValue).mutableCopy;
        if (newValue == nil) {
            newValue = [NSMutableParagraphStyle new];
        }
        return modifier(newValue);
    }];
}

- (NSAttributedString *)attributedStringByModifyingParagraphStyleForSubstring:(NSString *)substring modifier:(NSParagraphStyle *_Nullable (^)(NSMutableParagraphStyle *_Nullable style))modifier {
    
    NSRange subRange = [self.string rangeOfString:substring];
    return [self attributedStringByModifyingParagraphStyleForRange:&subRange modifier:modifier];
    
}

#pragma mark Paragraph spacing

- (NSAttributedString *)attributedStringByAddingParagraphSpacing:(CGFloat)spacing forRange:(const NSRangePointer _Nullable)range {
    
    return [self attributedStringByModifyingParagraphStyleForRange:range modifier:^NSParagraphStyle * _Nullable(NSMutableParagraphStyle * _Nullable style) {
        style.paragraphSpacing = spacing;
        return style;
    }];
}

#pragma mark Alignment

- (NSAttributedString *)attributedStringByAddingAlignment:(NSTextAlignment)alignment forRange:(const NSRangePointer _Nullable)rangeIn {
    
    return [self attributedStringByModifyingParagraphStyleForRange:rangeIn modifier:^NSParagraphStyle * _Nullable(NSMutableParagraphStyle * _Nullable style) {
        style.alignment = alignment;
        return style;
    }];
}

//- (NSAttributedString *)attributedStringByAddingAlignment:(NSTextAlignment)alignment forSubstring:(NSString * _Nullable)subStr {
//
//    return [self attributedStringByModifyingAttribute:NSParagraphStyleAttributeName forSubstring:subStr modifier:^NSParagraphStyle *(NSParagraphStyle *value) {
//
//        NSMutableParagraphStyle *newValue = value.mutableCopy;
//        if (newValue == nil) {
//            newValue = [NSMutableParagraphStyle new];
//        }
//        newValue.alignment = alignment;
//        return newValue;
//    }];
//}

#pragma mark - CORE: Font attributes
/// Font attributes are a subset of attributed string attributes.
///     It might be smart to use our function for adding string attributes instead of the function for adding font attributes

- (NSAttributedString *)attributedStringByAddingFontAttributes:(NSDictionary<NSFontDescriptorAttributeName,id> *)attributes forRange:(const NSRangePointer _Nullable)inRange {
    
    /// TODO: Use `attributedStringByModifyingAttribute:`
    
    NSRange range;
    if (inRange == NULL) {
        range = NSMakeRange(0, self.length);
    } else {
        range = *inRange;
    }
    
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

#pragma mark CORE: Font traits
/// Font traits are a subset of font attributes
///     We have a completely separate function for adding font traits (instead of utilitzing the func for adding font attributes), so that we can add font traits without overriding exising ones. Not sure if this separate func is actually necessary to achieve this.

- (NSAttributedString *)attributedStringByAddingFontTraits:(NSDictionary<NSFontDescriptorTraitKey, id> *)traits forRange:(const NSRangePointer _Nullable)inRange {
    
    /// TODO: Move this to modifyFont core
    
    /// This might mutate the font and the size
    ///  (If there's no font, yet, this will assign systemFont at default size.)
    
    NSRange range;
    if (inRange == NULL) {
        range = NSMakeRange(0, self.length);
    } else {
        range = *inRange;
    }
    
    NSMutableAttributedString *ret = self.mutableCopy;
    [self enumerateAttribute:NSFontAttributeName inRange:range options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
        
        NSFont *currentFont = (NSFont *)value;
        
        if (currentFont == nil) {
            //            assert(false);
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

- (NSAttributedString *)attributedStringByAddingFontTraits:(NSDictionary<NSFontDescriptorTraitKey, id> *)traits forSubstring:(NSString *)substring {
    
    NSRange range = [self.string rangeOfString:substring];
    return [self attributedStringByAddingFontTraits:traits forRange:&range];
}

- (NSAttributedString *)attributedStringByAddingFontTraits:(NSDictionary<NSFontDescriptorTraitKey, id> *)traits {
    
    assert(false); /// Just pass nil for the range to achieve the same thing
    
    NSRange range = NSMakeRange(0, self.length);
    return [self attributedStringByAddingFontTraits:traits forRange:&range];
}



#pragma mark Weight

- (NSAttributedString *)attributedStringByAddingWeight:(NSFontWeight)weight {
    
    assert(false); /// Just pass nil for the range to achieve the same thing
    
    return [self attributedStringByAddingFontTraits:@{
        NSFontWeightTrait: @(weight),
    }];
}

- (NSAttributedString *)attributedStringByAddingWeight:(NSFontWeight)weight forRange:(const NSRangePointer _Nullable)range {
    
    ///  Weight is a double between -1 and 1
    ///  You can use predefined constants starting with NSFontWeight, such as NSFontWeightBold
    return [self attributedStringByAddingFontTraits:@{
        NSFontWeightTrait: @(weight),
    } forRange:range];
}

- (NSAttributedString *)attributedStringByAddingWeight:(NSFontWeight)weight forSubstring:(NSString *)string {
    
    return [self attributedStringByAddingFontTraits:@{
        NSFontWeightTrait: @(weight)
    } forSubstring:string];
}

#pragma mark CORE: Symbolic font traits
/// Symbolic font traits are an abstract and easy way to control font traits and font attributes

- (NSAttributedString *)attributedStringByAddingSymbolicFontTraits:(NSFontDescriptorSymbolicTraits)traits forRange:(const NSRangePointer _Nullable)inRange {
    
    /// This might unintentionally mutate  font and size!
    /// (If there's no font, yet, this will asign systemFont at default size)
    
    NSRange range;
    if (inRange == NULL) {
        range = NSMakeRange(0, self.length);
    } else {
        range = *inRange;
    }
    
    NSDictionary *originalAttributes = [self attributesAtIndex:0 effectiveRange:nil];
    NSFont *originalFont = originalAttributes[NSFontAttributeName];
    
    if (originalFont == nil) {
//        assert(false);
        originalFont = [NSFont systemFontOfSize:NSFont.systemFontSize];
    }
    
    NSFontDescriptor *newFontDescriptor = [originalFont.fontDescriptor fontDescriptorWithSymbolicTraits:traits];
    NSFont *newFont = [NSFont fontWithDescriptor:newFontDescriptor size:originalFont.pointSize];
    
    NSMutableAttributedString *ret = [[NSMutableAttributedString alloc] initWithAttributedString:self];
    [ret addAttribute:NSFontAttributeName value:newFont range:range];
    
    return ret;
}
- (NSAttributedString *)attributedStringByAddingSymbolicFontTraits:(NSFontDescriptorSymbolicTraits)traits forSubstring:(NSString *)subStr {
    
    NSRange range = [self.string rangeOfString:subStr];
    return [self attributedStringByAddingSymbolicFontTraits:traits forRange:&range];
}

#pragma mark Bold

- (NSAttributedString *)attributedStringByAddingBoldForSubstring:(NSString *)subStr {
    return [self attributedStringByAddingSymbolicFontTraits:NSFontDescriptorTraitBold forSubstring:subStr];
}
    
- (NSAttributedString *)attributedStringByAddingBoldForRange:(const NSRangePointer _Nullable)range {
    return [self attributedStringByAddingSymbolicFontTraits:NSFontDescriptorTraitBold forRange:range];
}

#pragma mark Italic

- (NSAttributedString *)attributedStringByAddingItalicForSubstring:(NSString *)subStr {
    return [self attributedStringByAddingSymbolicFontTraits:NSFontDescriptorTraitItalic forSubstring:subStr];
}

- (NSAttributedString *)attributedStringByAddingItalicForRange:(const NSRangePointer _Nullable)range {
    return [self attributedStringByAddingSymbolicFontTraits:NSFontDescriptorTraitItalic forRange:range];
}

#pragma mark - Weird CORES
/// Using  weird methods that can't be reduced to the other CORE methods
///
///

#pragma mark Font size

- (NSAttributedString *)attributedStringBySettingFontSize:(CGFloat)size {
    
    /// TODO: Move this to modifiyFont core
    
    /// I think it is more  ideal to use `attributedStringByAddingFontAttributes:` (ideally build a wrapper around it for setting size)
    ///  NSFontManager is not intended for this, this is probably slower than using `attributedStringByAddingFontAttributes:`.
    ///
    /// How to use:
    /// - You can pass in NSFont.smallSystemFontSize, which is 11.0
    /// - You can pass in NSFont.systemFontSize, which is 13.0 I believe
    /// - You can pass in other arbitrary floating point numbers
    
    
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

#pragma mark Weight

- (NSMutableAttributedString *)attributedStringBySettingWeight:(NSInteger)weight forRange:(const NSRangePointer _Nullable)inRange {

    /// TODO: Move this to modifyFont core
    
    /// Notes:
    /// - This uses NSFontManager init to get a font of the desired size. Should probably stop using this at some point.
    /// - Weight is int between 0 and 15. 5 is normal weight
    ///   - I think it is more  ideal to use `attributedStringByAddingFontTraits:` (or `attributedStringByAddingWeight:` which is built on it)
    ///   - This function is for legacy. It only allows 15 weights and is incompatible with NSFontWeight. NSFontManager is not intended for this I think. Remove this eventually in favour of `attributedStringByAddingWeight:`
    /// - This will also add systemFont at default size to subRange if there is no font, yet

    NSRange range;
    if (inRange == NULL) {
        range = NSMakeRange(0, self.length);
    } else {
        range = *inRange;
    }
    
    NSMutableAttributedString *ret = self.mutableCopy;

    [self enumerateAttribute:NSFontAttributeName inRange:range options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
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
    return [self attributedStringBySettingWeight:weight forRange:&subRange];
}

- (NSMutableAttributedString *)attributedStringBySettingWeight:(NSInteger)weight {
    return [self attributedStringBySettingWeight:weight forRange:NULL];
}

- (NSAttributedString *)attributedStringBySettingThinForSubstring:(NSString *)subStr {

    NSInteger weight = 3;

    return [self attributedStringBySettingWeight:weight forSubstring:subStr];
}

- (NSAttributedString *)attributedStringByAddingSemiBoldForSubstring:(NSString *)subStr {
    double weight = 7; // 8;
    return [self attributedStringBySettingWeight:weight forSubstring:subStr];
}

#pragma mark - Special usecases

- (NSAttributedString *)attributedStringByAddingHintStyle {
    
    /// Notes:
    /// - The is the style of the small grey 'hint' texts we see all over the the General Tab and other Tabs. However those are mostly defined inside Interface Builder.
    /// - Problem: .secondaryLabelColor seems to look good on NSTextFields but in NSTextViews, it's really dim in darkmode.
    ///     - (As of 30.08.2024, macOS Sequoia Beta)
    ///     - .systemGrayColor seems to look better, maybe we should switch to that if this isn't resolved.
    ///     - Our ToastNotifications use NSTextViews to be able to display links properly.
    
    NSAttributedString *ret = self.copy;
    ret = [ret attributedStringBySettingFontSize:NSFont.smallSystemFontSize];
    ret = [ret attributedStringByAddingColor:NSColor.secondaryLabelColor forRange:nil];
    
    return ret;
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


@end
