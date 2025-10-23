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
#import "MFLoop.h"
#import "NSString+Steganography.h"
#import "NSDictionary+Additions.h"


#if IS_MAIN_APP
#import "Mac_Mouse_Fix-Swift.h"
#endif

#if IS_HELPER
#import "Mac_Mouse_Fix_Helper-Swift.h"
#endif

@implementation NSAttributedString (Additions)

#pragma mark Trim whitespace

- (NSAttributedString *)attributedStringByCapitalizingFirst {
    
    /// Notes:
    ///     - The code for finding the first letter is I think only necessary for skipping over the zero-width characters we insert when taking screenshots (See `NSString+Steganography.m` and `-MF_ANNOTATE_LOCALIZED_STRINGS`) [Sep 2025]
    ///     - Could we just use `-[NSAttributedString localizedCapitalizedString]`? [Sep 2025]
    
    /// Null check
    if (self.length == 0) {
        return [self copy];
    }
    
    /// Find the first letter
    NSUInteger firstLetterIndex = NSUIntegerMax;
    {
        unichar chars[self.length];
        [self.string getCharacters: chars];
        
        loopc(i, self.length) {
            if ([NSCharacterSet.letterCharacterSet characterIsMember: chars[i]]) {
                firstLetterIndex = i;
                break;
            }
        }
    }
    
    /// Guard no letters
    if (firstLetterIndex == NSUIntegerMax) {
        assert(false && "No letters found to capitalize");
        return [self copy];
    }
    
    /// Uppercase the first letter
    NSMutableAttributedString *s = [self mutableCopy];
    NSRange firstLetterRange = NSMakeRange(firstLetterIndex, 1);
    [s replaceCharactersInRange: firstLetterRange withString: [[s.string substringWithRange: firstLetterRange] localizedUppercaseString]];
    
    /// Return
    return s;
}

- (NSAttributedString *)attributedStringByRemovingAllWhitespace {
    
    ///
    /// Remove all whitespace and newline chars from the string
    ///
    
    /// Used by the licenseField [Sep 2025]
    
    NSCharacterSet *whitespaceAndNewlineChars = NSCharacterSet.whitespaceAndNewlineCharacterSet;
    
    NSMutableAttributedString *s = [self mutableCopy];
    NSRange searchRange = NSMakeRange(0, s.length);
    
    while (true) {
        NSRange whitespace = [s.string rangeOfCharacterFromSet: whitespaceAndNewlineChars options: 0 range: searchRange];
        if (whitespace.location == NSNotFound) break;
        [s deleteCharactersInRange: whitespace];
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
    
    /// Null check
    if (!self.length) return [self copy];
    
    /// Create mutable result
    NSMutableAttributedString *s = [self mutableCopy];
    
    /// Create shorthands
    #define str(i) [s.string characterAtIndex: i] /// [Sep 2025] We could use `-[NSString getCharacters:]` for similar ergonomics with better performance, but we'd have to repeat that every time that we modify the string.
    NSCharacterSet *whitespaceChars = NSCharacterSet.whitespaceCharacterSet;
    NSCharacterSet *whitespaceAndNewlineChars = NSCharacterSet.whitespaceAndNewlineCharacterSet;
    
    /// Skip over secretMessage
    ///     Skip over the zero-width characters we insert when taking screenshots (See `NSString+Steganography.m`) [Sep 2025]
    NSInteger realStartIndex = 0;
    if ([NSProcessInfo.processInfo.arguments containsObject:@"-MF_ANNOTATE_LOCALIZED_STRINGS"]) {
        loopc(i, s.length) {
            BOOL isSecretMessageChar = [[NSString secretMessageChars] characterIsMember: str(i)]; /// [Sep 2025] Maybe we should use `-[NSString secretMessages]` instead?
            if (!isSecretMessageChar) {
                realStartIndex = (NSInteger)i;
                break;
            }
        }
    }
    
    nowarn_push(-Wsign-conversion)      /// Caution: [Sep 2025] The loop variable (i) may not be unsigned, otherwise the backwards loop underflows and goes on forever.
    nowarn_push(-Wsign-compare)         ///         But this way we get lots of signed/unsigned warnings! Not sure how to deal with this except `nowarn_push`. See `Clang Diagnostic Flags - Sign.md`
    {
        /// Remove leading whitespace
        loopc(i, realStartIndex, s.length, +1) {
            if (![whitespaceAndNewlineChars characterIsMember: str(i)]) {
                [s deleteCharactersInRange: NSMakeRange(realStartIndex, i - realStartIndex)]; /// (i-1) is the last of the leading whitespace chars
                break;
            }
            if (i == s.length-1) [s deleteCharactersInRange: NSMakeRange(realStartIndex, s.length - realStartIndex)]; /// Edge case: Reached the end of the string and it's all whitespace – delete it all.
        }
            
        /// Remove trailling whitespace
        loopc(i, realStartIndex, s.length, -1)
            if (![whitespaceAndNewlineChars characterIsMember: str(i)]) {
                [s deleteCharactersInRange: NSMakeRange(i+1, s.length - (i+1))]; /// (i+1) is the first of the trailing whitespace chars
                break;
            }
        
        /// Remove duplicates
        ///     Note how we're using `whitespaceChars` here not `whitespaceAndNewlineChars`. Since we don't want to remove double linebreaks.
        loopc(i, realStartIndex, s.length-1, +1) /// Only iterate up to the second-last element. [Sep 2025]
            if (
                [whitespaceChars characterIsMember: str(i)] &&
                [whitespaceChars characterIsMember: str(i+1)]
            ) {
                [s deleteCharactersInRange: NSMakeRange(i, 1)]; /// Found duplicate whitespace - delete the first one, and don't increment i
                i--;
            }
    }
    nowarn_pop()
    nowarn_pop()
    
    if ((0)) {
        
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
    #undef str
}

#pragma mark Replace substring

- (NSAttributedString *) attributedStringByReplacing: (NSString *)old with: (NSAttributedString *)new {
    return [self attributedStringByReplacing: old with: new count: -1];
}
- (NSAttributedString *) attributedStringByReplacing: (NSString *)old with: (NSAttributedString *)new count: (int)count {
    
    /// Replaces occurrences of `searchedString` with `replacementString`.
    ///     Replaces at most `count` occurences. To replace *all* occurences, set `count` to -1.
    
    NSMutableAttributedString *result = [self mutableCopy];
    
    if ([old isEqual: new.string]) return result; /// Prevent infinite loop in edge case.
    
    for (int i = 0;; i++) {

        if (count > 0)
            if (i >= count) break;
    
        NSRange replaceRange = [result.string rangeOfString: old]; /// Could activate regex here [Sep 2025]
        if (replaceRange.location == NSNotFound) break;
        
        [result replaceCharactersInRange: replaceRange withAttributedString: new];
    }
    
    return result;
}

#pragma mark Append

- (NSAttributedString *) attributedStringByAppending: (NSAttributedString *)string { /// [Sep 2025] This probably shouldn't exist using astringf macro directly is more readable and both map to `attributedStringWithAttributedFormat:`
    return astringf([@"%@%@" attributed], self, string);
}

#pragma mark Formatting

+ (NSAttributedString *) attributedStringWithAttributedFormat: (NSAttributedString *)format args: (NSAttributedString *__strong _Nullable [_Nonnull])args argcount: (int)argcount {
    
    /// Replaces occurences of %@ in the attributedString with the args
    ///     Usage tip:                  Use the `astringf()` macro which wraps this.
    ///     Also see:                     lib function `initWithFormat:options:locale:` (Only available on macOS 12.0)
    ///     Optimization idea:      We could also make an attributed variant of -[NSArray componentsJoinedByString:] if this is too slow
    ///     Implementation note: We're using a C array instead of NSArray to not crash when an arg is nil.
    ///         We currently map nil to @"", unlike native string formatting which maps to @"(null)" IIRC. Not sure this makes sense. [Sep 2025]
    ///         Swift note: The C array makes this a bit annoying to call from Swift. Should probably create a convenience wrapper if we use it more from Swift.
    
    /// Early return
    if (argcount == 0) return format;
    if ([format.string isEqual: @""]) return format;
    
    /// Find all format specifiers
    auto searchRange = NSMakeRange(0, format.length);
    auto *formatSpecifierRanges = [NSMutableData new]; /// Using NSMutableData to store NSRanges instead of NSMutableArray cause it's faster maybe? [Sep 2025]
    int i;
    for (i = 0; ; i++) {
        NSRange formatSpecifierRange = [format.string rangeOfString: @"%@" options: 0 range: searchRange]; /// Find the next format specifier to replace
        if (formatSpecifierRange.location == NSNotFound) break;
        [formatSpecifierRanges appendBytes: &formatSpecifierRange length: sizeof(NSRange)]; /// Store found range
        searchRange = NSMakeRange(NSMaxRange(formatSpecifierRange), format.length - NSMaxRange(formatSpecifierRange)); /// Update searchRange
    }
    
    if (i != argcount) {
        assert(false && "attributedStringWithAttributedFormat: Number of format specifiers doesn't match number of args");
        i = MIN(i, argcount);
    }
    
    /// Get mutable copy of format
    ///     On Ventura Beta, `[format mutableCopy]` returns creates unreadable data, if format is an empty string.
    NSMutableAttributedString *mutableFormat = [format mutableCopy];
    
    /// Replace
    ///     Note: [Sep 2025] We replace in a second pass after finding the formatSpecifiers, so we don't replace formatSpecifiers *contained inside* the replacement strings.
    int offset = 0;
    loopc(j, i) {
        auto replaceRange = ((NSRange *)[formatSpecifierRanges bytes])[j];
        replaceRange.location += offset; /// This converts signed to unsigned, which I'd expect to underflow, but somehow works correctly in my godbolt testing. (Also see `Clang Diagnostic Flags - Sign.md`)
        [mutableFormat replaceCharactersInRange: replaceRange withAttributedString: args[j] ?: [@"" attributed]];
        offset += args[j].length - replaceRange.length;
    }
    
    /// Return
    return mutableFormat;
}

#pragma mark Split string

- (NSArray<NSAttributedString *> *) split: (NSString *)separator maxSplit: (int)maxSplit {
    
    /// Overview: Like `-[NSString componentsSeparatedByString:]`, but for NSAttributedString and the API is a bit more like Python's `str.split()`
    /// Question: Is it a good idea to make the method name shorter and more Python-y instead of following the verbose naming scheme of the other methods? [Sep 2025]
    /// Usage:
    ///     Pass in -1 for maxSplit to turn it off.
    
    auto result = [NSMutableArray new];
    
    auto restRange = NSMakeRange(0, self.length);
    
    for (int split = 1; ; split++) {
        
        if (maxSplit > 0)
            if (split > maxSplit)
                break;
        
        auto separatorRange = [self.string
            rangeOfString: separator
            options: 0          /// Could use `NSRegularExpressionSearch`? But we don't need that right now.
            range: restRange
            locale: nil
        ];
        
        if (separatorRange.location == NSNotFound) break;
        
        [result addObject: [self attributedSubstringFromRange: NSMakeRange(restRange.location, separatorRange.location - restRange.location)]];
        
        restRange = NSMakeRange(NSMaxRange(separatorRange), self.length - NSMaxRange(separatorRange));
    }
    [result addObject: [self attributedSubstringFromRange: restRange]];
    
    return result;
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
    mainString = [mainString attributedStringByAddingAttributes: @{
        NSKernAttributeName: @(hPadding)
    } forRange:NULL];
    
    /// Return
    return mainString;
}

#pragma mark Markdown

+ (NSAttributedString *) labelWithMarkdown: (NSString *)md {
    return [MarkdownParser attributedStringWithCoolMarkdown: md fillOutBase: YES];
}
+ (NSAttributedString *) secondaryLabelWithMarkdown: (NSString *)md {
    
    NSAttributedString *s = [MarkdownParser attributedStringWithCoolMarkdown: md fillOutBase: YES];
    s = [s attributedStringBySettingFontSize: 11];
    s = [s attributedStringByAddingColor: NSColor.secondaryLabelColor forRange: NULL];
    
    return s;
}

#pragma mark Determine size

static NSRect MFUnionRect(NSRect r, NSRect s) {
    
    /// Replacement for `NSUnionRect`
    ///     `NSUnionRect` seems to ignore rects with zero-width,
    ///     which makes it not work for `NSTextLayoutFragment`s representing blank-lines. [Oct 2025]
    
    CGFloat minX = MIN(r.origin.x, s.origin.x);
    CGFloat maxX = MAX(
        (r.origin.x + r.size.width),
        (s.origin.x + s.size.width)
    );
    CGFloat minY = MIN(r.origin.y, s.origin.y);
    CGFloat maxY = MAX(
        (r.origin.y + r.size.height),
        (s.origin.y + s.size.height)
    );
    
    return (NSRect){ { .x = minX, .y = minY }, { .width = maxX-minX, .height = maxY-minY } };

}

- (NSSize)sizeAtMaxWidth:(CGFloat)maxWidth {
    
    /// Notes:
    /// - Why didn't we use the native `boundingRectWithSize:`? Was there really no way to make it work? Well this works so no need to change it.
    
    if (@available(macOS 12.0, *)) {
        
        /// TextKit 2 Implementation
        ///     v2 APIs were introduced in macOS 12
        ///     See WWDC intro: https://developer.apple.com/videos/play/wwdc2021/10061/
        
        /// Create objects
        NSTextLayoutManager *textLayoutManager;
        NSTextContentStorage *textContentStorage;
        NSTextContainer *textContainer;
        {
        
            /// Create v2 layoutMgr
            textLayoutManager = [[NSTextLayoutManager alloc] init];
            
            /// Create v2 contentMgr
            textContentStorage = [[NSTextContentStorage alloc] init];
            
            /// Create container
            textContainer = [[NSTextContainer alloc] initWithSize: CGSizeMake(maxWidth, CGFLOAT_MAX)]; /// `initWithContainerSize:` was deprecated in macOS 12
            textContainer.lineFragmentPadding = 0; /// 5.0 by default which makes the result always be smaller than the maxWidth (I think) [Sep 2025]
        }
        
        /// Link objects
        {
            /// Link contentMgr -> self
            [textContentStorage setAttributedString:self];
            
            /// Link layoutMgr -> container
            [textLayoutManager setTextContainer:textContainer];
            
            /// Link layoutMgr -> contentMgr
            [textLayoutManager replaceTextContentManager:textContentStorage];
            [textContentStorage setPrimaryTextLayoutManager:textLayoutManager]; /// Not sure if necessary
        }
        
        /// Get size from layoutMgr
        __block NSRect resultRect;
        {
            /// On options:
            ///     - `NSTextLayoutFragmentEnumerationOptionsEnsuresExtraLineFragment` is for ensuring layout consistency with editable text, which we don't need here.
            ///     - `NSTextLayoutFragmentEnumerationOptionsEstimatesSize` is a faster, but less accurate alternative to `NSTextLayoutFragmentEnumerationOptionsEnsuresLayout`
            resultRect = NSZeroRect;
            NSTextLayoutFragmentEnumerationOptions enumerationOptions = (
                NSTextLayoutFragmentEnumerationOptionsEnsuresLayout |
                NSTextLayoutFragmentEnumerationOptionsEnsuresExtraLineFragment /// Doesn't seem to make a difference [Oct 2025]
            );
            [textLayoutManager enumerateTextLayoutFragmentsFromLocation: nil options: enumerationOptions usingBlock: ^BOOL(NSTextLayoutFragment * _Nonnull layoutFragment) {
                resultRect = MFUnionRect(resultRect, layoutFragment.layoutFragmentFrame);
                return YES;
            }];
        }
        
        /// Return
        return resultRect.size;
        
    } else {

        /// TextKit v1 implementation
        ///     Originally Copied from here https://stackoverflow.com/a/33903242/10601702
        
        /// [Jul 2025] Note from master branch (Copying this over while merging master into feature-strings-catalog) (master used a slightly older implementation of the TextKit v1 implementation, so this might not apply here)
        ///     I think the text on the TrialNotification was too short in Chinese due to this. (See 83c6812740c176f8b2ec084c7d5798a5d2968b57)
        ///     I did some minimal testing on the TrialNotification and this seemed consistently smaller than the real size of the NSTextView when there were Chinese characters, while matching exactly, when there were only English characters. Update: Yep the Toasts are also too small in Chinese due to this. (macOS Sequoia 15.5)
        ///     TODO: Maybe review other uses of this in Chinese.
        ///     If this doesn't work reliably, perhaps you always have to layout your NSTextView / NSTextField and then measure that. Or perhaps you can solve all this stuff by just using autolayout constraints directly?
        
        /// Create objects
        NSLayoutManager *layoutManager;
        NSTextStorage *textStorage;
        NSTextContainer *textContainer;
        {
            /// Create layoutMgr
            layoutManager = [[NSLayoutManager alloc] init];

            /// Create content
            textStorage = [[NSTextStorage alloc] init];
            
            /// Create container
            textContainer = [[NSTextContainer alloc] initWithSize:CGSizeMake(maxWidth, CGFLOAT_MAX)];
            textContainer.lineFragmentPadding = 0.0; /// Copied from the TextKit v2 implementation. Untested [Sep 2025]
        }
        
        /// Link objects
        {
            /// Link content -> self
            [textStorage setAttributedString:self]; /// This needs to happen before other linking steps, otherwise it won't work. Not sure why.
            
            /// Link layoutMgr -> container
            [layoutManager addTextContainer:textContainer];
            
            /// Link layoutMgr -> content
            [layoutManager replaceTextStorage:textStorage];
            [textStorage addLayoutManager:layoutManager]; /// Not sure if necessary
        }

        /// Force glyph generation & layout
        NSInteger numberOfGlyphs = [layoutManager numberOfGlyphs];                  /// Forces glyph generation
        [layoutManager ensureLayoutForGlyphRange:NSMakeRange(0, numberOfGlyphs)];   /// Forces layout
        
        /// Get size from layoutMgr
        NSSize size = [layoutManager usedRectForTextContainer:textContainer].size;
        
        /// Return
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

#pragma mark intentionalFontAttributes

typedef struct { NSFont *font; bool fallBackToCurrentFontAttributes; } getIntentionalFontAttributes_args; /// [Sep 2025] If C could just do type inference for designated initializers, this boilerplate wouldn't be necessary. Macros don't really help either I think.
NSMutableDictionary<NSFontDescriptorAttributeName, id> *getIntentionalFontAttributes(getIntentionalFontAttributes_args args) {
    #define getIntentionalFontAttributes(args...) getIntentionalFontAttributes((getIntentionalFontAttributes_args){ args })
    
    /**
        Explanation: What are we doing here? What are 'intentionalFontAttributes' (Aka 'intentionalAttributes')? [Sep 2025]
        Problem:
            When we manipulate a NSFont on an NSAttributedString, we can only do that (in a sane way?) by converting the NSFont into a fontAttributes dict, then manipulating that, and then converting that back to an NSFont.
            There are some problems with this:
                1. Problem: If you only want to specify a specific font attribute, like 'bold', you still have to create a whole NSFont with size and fontName and stuff to be able to store that on the NSAttributedString.
                    - Then, you can no longer tell apart, which attributes of the font were 'intentionally' set and which were just a byproduct of having to create an NSFont to hold the attribute you wanted to specify.
                        - This is a problem for our 'asBase' mechanism which wants to set a set of 'base' attributes on the NSAttributedString, except if those attributes have already been specified before.
                2. Problem: The conversion between NSFont and fontAttributes is not always reversible. Multiple attributes you specified may get folded into a single or other attributes when converting back from the NSFont.
                    - But I think this also only matters when you wanna keep track of which attributes you 'intentionally' set so you can ignore the others for the 'asBase' mechanism

        Solution:
            We attach a dict of 'intentionalAttributes' to the NSFont, and then when we manipulate the font, we don't try to extract the attributes directly from the font but from the attached 'intentionalAttributes', which only contains the attributes we actually specified.
            This makes the 'asBase' mechanism work correctly for NSFonts nested inside NSAttributedStrings.
        
        Sidenote:
            Aside from NSFont, I think there are other objects nested inside NSAttributedStrings like NSParapraphstyle (or whatever it's called) which have similar problems with 'asBase' but we haven't run into those problems, yet.
        
        Criticisms:
            - We were doing fine without this. This might have been a waste of time:
                - I think the the 'asBase' mechanism could be entirely avoided, if we refactored our code such that we're simply setting the attributes we want as base *before* the other attributes.
                    Counterpoint: I'm not sure how much work it would be to refactor, and it is quite nice to have.
                - The 'asBase' mechanism mostly worked already, I think the only problem is that making a word bold also specifies a fontFamily and fontSize for it. But we don't want to use a font aside from the system one and we don't need asBase for the fontSize except if we want different fontSizes in the same string which is rare.
                - The only practical problem I encountered was when writing that mechanism where the second and following lines of Toasts automatically becomes small hint text,
                    But then I wanted to override the text size for the 'learn more' at the very bottom to be normal sized. This works now. But I decided it looks bad and so now we don't even need the intentionalFontAttributes stuff afaik.
                        -> I should've probably just prototyped this, instead of trying to fix a 'fundamental problem' that we don't even really have. Counterpoint: Perhaps it will be a bit easier to prototype and play around in the future with the 'asBase' mechanism working more robustly.
            - macOS 12.0 can do this out of the box
                - macOS 12.0 brought native markdown support NSAttributedString. While doing this, they added NSAttributedString attributes, for specifying things like bold and italic *directly* on the NSAttributedString, instead of on an NSFont nested inside the NSAttributedString.
                    This solves all these problems. So we're kinda only doing this to support macOS 10.15 and macOS 11.0, and it took quite a bit of time, which may not be worth it. [Sep 2025]
                    -> We probably should have used the macOS 12.0 mechanism, with a fallback that looks a bit ugly but still works for older versions.
                        But this works now, so oh well.
        Lesson:
            Simple beats correct! Stop trying to make theoretically 'correct' solutions that add more complexity than they are worth. A simple hack is better than a 'correct' general solution that solves the same problem with more complexity. I don't think this is always always true, but I sway too much in the other direction lately.
            
            Hack that would've worked in this case:
                We could've just added an optional arg to the ToastController that says "don't add hint styling here, let the caller handle it all". Then we could've made the 'learn more' link larger very easily. (See above.) (And then we would've discovered we don't even like that.)
                
                Once the hack got annoying we should've probably switched to the native macOS 12.0 solution.
                
            Nuance:
                We shouldn't have tried to 'fix the infrastructure', but the nuance is that I didn't know how much work it would be to 'fix the infrastructure'. You only get a sense for the complexity once you're halfway through the refactor. Where it then feels harder to throw all that away and go back to a hack. (Mind is already occupied and immersed in the problem, I may have added other bits of valuable code and comments in the big refactor that would be work to salvage, you really wanna finish it and feel like you don't have time to go back to the drawing board.) But maybe I should've explored the hack first? – Yes I should have. Especially since I discovered I don't even want the functionality right now.
                    Anotherrr nuance: This just started as a bug investigation. But as soon as I understood the problem and understood that you need slightly gnarly 'infrastructure hacks' like this I should've perhaps abandoned this approach and switched to hacks. I could've just left a note about the bug and moved on without trying to fix it.
    
        Sidenote on asBase:
            I think we originally only created the asBase mechanism to make the `-[NSAttributedString sizeAtMaxWidth:]` method work which is used when we do programmatic layout in ToastController.m (Tried to switch to autolayout, but that's complicated. See b423681c3c319774baad4b76ae9de1829519797c or the commit before.) That makes me think – Perhaps there's some way more simple way to solve all this?
            
        Sidenote on why 'fixing the infrastructure' is compelling:
            It feels like you're making yourself more 'powerful' in the long run. Sometimes this is true, but here it was quite a niche thing and probably not worth it. (It didn't take that much time, but these kinds of bad overengeneering decisions add up I think.)
    */
    
    /// Helper function
    
    static const char *MFintentionalFontAttributesKey = "MFintentionalFontAttributesKey";
    
    if (!args.font) return nil;
    
    NSMutableDictionary *result = objc_getAssociatedObject(args.font, MFintentionalFontAttributesKey);
    if (!result) {
        if (args.fallBackToCurrentFontAttributes) {
            result = [[[args.font fontDescriptor] fontAttributes] mutableCopy]; /// If we call `objc_setAssociatedObject` here, the text becomes really fat when this is called in `attributedStringByAddingAttributesAsBase:`. I'm not sure why. Maybe this fallback mechanism doesn't belong here. [Sep 2025]
        }
        else {
            result = [NSMutableDictionary new];
            objc_setAssociatedObject(args.font, MFintentionalFontAttributesKey, result, OBJC_ASSOCIATION_RETAIN);
        }
    }
    return result;
}

#pragma mark Fill out base

- (NSAttributedString *)attributedStringByFillingOutBase {
    
    /// Fill out default attributes, because layout code won't work if the string doesn't have a font and a textColor attribute on every character. See https://stackoverflow.com/questions/13621084/boundingrectwithsize-for-nsattributedstring-returning-wrong-size
    
    NSDictionary *attributesDictionary = @{
        NSFontAttributeName: [NSFont systemFontOfSize:NSFont.systemFontSize],
        NSForegroundColorAttributeName: NSColor.labelColor,
        NSFontWeightTrait: @(NSFontWeightMedium),
    };
    
    return [self attributedStringByAddingAttributesAsBase:attributesDictionary];
}

- (NSAttributedString *)attributedStringByFillingOutBaseAsHint {
    
    NSDictionary *attributesDictionary = @{
        NSFontAttributeName: [NSFont systemFontOfSize:NSFont.smallSystemFontSize],
        NSForegroundColorAttributeName: NSColor.secondaryLabelColor,
        NSFontWeightTrait: @(NSFontWeightRegular), /// Not sure whether to use medium or regular here
    };
    
    return [self attributedStringByAddingAttributesAsBase:attributesDictionary];
}

- (NSAttributedString *)attributedStringByAddingAttributesAsBase:(NSDictionary<NSAttributedStringKey, id> *)baseAttributes {
    
    /// Create string by adding values from `baseAttributes`, without overriding any of the attributes set for `self`
    
    NSMutableAttributedString *result = [self mutableCopy];
    
    /// Add baseAttributes
    ///     baseAttributes will override current attributes
    [result addAttributes: baseAttributes range: NSMakeRange(0, result.length)]; /// I observed this *not* override the `NSFont`. Perhaps because the `NSFonts` were `isEqual:`. However this could lead to issues with our `IntentionalFontAttributes` mechanism in edge cases. [Oct 2025]
    
    /// Add original string attributes
    ///     to undo overrides by the baseAttributes
    [self enumerateAttributesInRange: NSMakeRange(0, self.length) options: 0 usingBlock: ^(NSDictionary<NSAttributedStringKey,id> * _Nonnull attrs, NSRange range, BOOL * _Nonnull stop) {
            
        { /// Skip font (Cause we handle that separately below)
            NSMutableDictionary *attrs2 = [attrs mutableCopy];
            attrs2[NSFontAttributeName] = nil;
            attrs = attrs2;
        }
        
        [result addAttributes: attrs range: range];
    }];
    
    /// Add original font attributes back
    ///     (But only the intentional ones)
    __block NSAttributedString *result2 = result;
    [self enumerateAttribute: NSFontAttributeName inRange: NSMakeRange(0, result.length) options: 0 usingBlock: ^(NSFont *_Nullable ogFont, NSRange range, BOOL * _Nonnull stop) {
        auto ogFontAttributes = getIntentionalFontAttributes(ogFont, .fallBackToCurrentFontAttributes = true);
        result2 = [result2 attributedStringByModifyingFontAttributesForRange: &range withOverrides: ogFontAttributes];
    }];
    
    return result2;
}

#pragma mark Assign while keeping base

void assignAttributedStringKeepingBase(NSAttributedString *_Nonnull *_Nonnull assignee, NSAttributedString *newValue) {
    
    /// This is meant for assigning attributed strings to interface elements whose text has been styled in IB already. And where we want to keep the style from IB as base
    
    /// There are some places where we still do this manually which we could replace with this. Search for "attributesAtIndex:" to find them.
    
    /// Get assigneeAttributes
    auto assigneeAttributes = [*assignee attributesAtIndex: 0 effectiveRange: NULL];
    
    /// Add assignee's attributes as base for the newValue
    newValue = [newValue attributedStringByAddingAttributesAsBase: assigneeAttributes];
    
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

#pragma mark - CORE: Add stringAttributes

- (NSAttributedString *)attributedStringByAddingAttributes: (NSDictionary<NSAttributedStringKey, id> *)attributes forRange:(const NSRangePointer _Nullable)inRange {
    
    /// Notes:
    ///     Also see `attributedStringByModifyingAttribute:` below
    
    NSRange range;
    if (inRange == NULL)    range = NSMakeRange(0, self.length);
    else                    range = *inRange;
    
    NSMutableAttributedString *ret = [self mutableCopy];

    [ret addAttributes: attributes range: range];
    
    return ret;
}

- (NSAttributedString *)attributedStringByAddingAttributes: (NSDictionary<NSAttributedStringKey, id> *)attributes forSubstring:(NSString *)substring {
    
    NSRange range = [self.string rangeOfString:substring];
    return [self attributedStringByAddingAttributes: attributes forRange:&range];
}

    #pragma mark Color

    - (NSAttributedString *)attributedStringByAddingColor:(NSColor *)color forSubstring:(NSString *)subStr {
        
        assert(subStr != nil);
        
        return [self attributedStringByAddingAttributes: @{
            NSForegroundColorAttributeName: color //NSColor.secondaryLabelColor
        } forSubstring:subStr];
    }

    - (NSAttributedString *)attributedStringByAddingColor:(NSColor *)color forRange:(const NSRangePointer _Nullable)range {
        
        return [self attributedStringByAddingAttributes: @{
            NSForegroundColorAttributeName: color //NSColor.secondaryLabelColor
        } forRange:range];
    }

    #pragma mark Baseline offset

    - (NSAttributedString *)attributedStringByAddingBaseLineOffset:(CGFloat)offset forRange:(const NSRangePointer _Nullable)range {
        /// Offset in points
        
        return [self attributedStringByAddingAttributes: @{
            NSBaselineOffsetAttributeName: @(offset),
        } forRange:range];
    }

    #pragma mark Hyperlink

    + (NSAttributedString *)hyperlinkFromString:(NSString *)inString withURL:(NSURL *)url {
        
        NSAttributedString *string = [[NSAttributedString alloc] initWithString: inString];
        string = [string attributedStringByAddingHyperlink: url forRange: NULL];
        
        return string;
    }

    - (NSAttributedString *) attributedStringByAddingHyperlink: (NSURL *_Nullable)url forSubstring: (NSString *)substring {
        
        NSRange subRange = [self.string rangeOfString: substring];
        return [self attributedStringByAddingHyperlink: url forRange: &subRange];
    }

    - (NSAttributedString *) attributedStringByAddingHyperlink: (NSURL *_Nullable) aURL forRange: (const NSRangePointer _Nullable)range {
        
        /// Notes:
        /// - Making the text blue explicitly doesn't seem to be necessary. The links will still be blue if we don't do this.
        /// - Adding an underline explicitlyis unnecessary in NSTextView but necessary in NSTextField
        
        if (!aURL) return [self copy];
        
        return [self attributedStringByAddingAttributes: @{
            NSLinkAttributeName: aURL.absoluteString ?: @"",
            NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle),
            //        NSForegroundColorAttributeName: NSColor.blueColor,
        } forRange: range];
    }


    - (NSAttributedString *)attributedStringByAddingFont:(NSFont *)font forRange:(const NSRangePointer _Nullable)range {
        
        NSAttributedString *result = [self attributedStringByAddingAttributes: @{
            NSFontAttributeName: font,
        } forRange:range];
        
        return result;
    }


#pragma mark - CORE: Modify stringAttributes

- (NSAttributedString *) attributedStringByModifyingAttribute: (NSAttributedStringKey)attribute forRange: (const NSRangePointer _Nullable)inRange modifier: (id _Nullable (^)(id _Nullable attributeValue))modifier {
    
    /// Explanation:
    ///     This here is more powerful, callback-based equivalent to `attributedStringByAddingAttributes: `,
    ///         which allows us to 'modify' attributes instead of just setting them. This is crucial for complex nested attributes like the font (`NSFontAttributeName`) [Sep 2025]
    
    NSRange range;
    if (inRange == NULL) range = NSMakeRange(0, self.length);
    else                 range = *inRange;
    
    NSMutableAttributedString *result = [self mutableCopy];
    
    [self enumerateAttribute: attribute inRange: range options: 0 usingBlock: ^void (id _Nullable value, NSRange range, BOOL * _Nonnull stop) {
        
        /// Notes:
        ///     - Should we pass in `stop` to the callback?
        ///     - Do we need to copy the value or sth?
        ///     - Pretty sure `addAttribute:` overrides the existing attribute;
        id newValue = modifier(value);
        [result addAttribute: attribute value: newValue range: range];
    }];
    
    return result;
}

    - (NSAttributedString *) attributedStringByModifyingAttribute: (NSAttributedStringKey)attribute forSubstring: (NSString *)substring modifier: (id _Nullable(^)(id _Nullable attributeValue))modifier {
        
        NSRange range = [self.string rangeOfString: substring];
        return [self attributedStringByModifyingAttribute: attribute forRange: &range modifier: modifier];
    }

    #pragma mark - CORE: Paragraph style

    - (NSAttributedString *)attributedStringByModifyingParagraphStyleForRange:(const NSRangePointer _Nullable)inRange modifier:(NSParagraphStyle *_Nullable (^)(NSMutableParagraphStyle *_Nullable style))modifier {
        
        return [self attributedStringByModifyingAttribute: NSParagraphStyleAttributeName forRange:inRange modifier:^id _Nullable(id  _Nullable attributeValue) {
            
            NSMutableParagraphStyle *newValue = ((NSMutableParagraphStyle *)attributeValue).mutableCopy;
            if (newValue == nil) {
                newValue = [NSMutableParagraphStyle new];
            }
            return modifier(newValue);
        }];
    }

        - (NSAttributedString *)attributedStringByModifyingParagraphStyleForSubstring:(NSString *)substring modifier:(NSParagraphStyle *_Nullable (^)(NSMutableParagraphStyle *_Nullable style))modifier {
            
            NSRange subRange = [self.string rangeOfString: substring];
            return [self attributedStringByModifyingParagraphStyleForRange: &subRange modifier: modifier];
            
        }

        #pragma mark Paragraph spacing

        - (NSAttributedString *)attributedStringByAddingParagraphSpacing:(CGFloat)spacing forRange:(const NSRangePointer _Nullable)range { /// Note: [Oct 2025] A 'paragraph' seems to be delineated by any `\n`, not just `\n\n` (blank line). Use `attributedStringByAddingBlankLineHeight:` instead.
            
            return [self attributedStringByModifyingParagraphStyleForRange:range modifier:^NSParagraphStyle * _Nullable(NSMutableParagraphStyle * _Nullable style) {
                style.paragraphSpacing = spacing;
                return style;
            }];
        }
        #pragma mark Paragraph spacing before

        - (NSAttributedString *)attributedStringByAddingParagraphSpacingBefore:(CGFloat)spacing forRange:(const NSRangePointer _Nullable)range {
            
            return [self attributedStringByModifyingParagraphStyleForRange:range modifier:^NSParagraphStyle * _Nullable(NSMutableParagraphStyle * _Nullable style) {
                style.paragraphSpacingBefore = spacing;
                return style;
            }];
        }
        
        #pragma mark Line spacing

        - (NSAttributedString *)attributedStringByAddingLineSpacing:(CGFloat)spacing forRange:(const NSRangePointer _Nullable)range {
            
            return [self attributedStringByModifyingParagraphStyleForRange:range modifier:^NSParagraphStyle * _Nullable(NSMutableParagraphStyle * _Nullable style) {
                style.lineSpacing = spacing;
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

        #pragma mark - CORE: Modify fontAttributes
        /// fontAttributes are 'nested' inside fonts which are 'nested' inside stringAttributes
        
        typedef NSDictionary<NSFontDescriptorAttributeName, id> * MFNSFontAttributes;

        - (NSAttributedString *) attributedStringByModifyingFontAttributesForRange: (const NSRangePointer _Nullable)inRange withOverrides: fontAttributeOverrides {
        
            auto result = [self attributedStringByModifyingAttribute: NSFontAttributeName forRange: inRange modifier: ^NSFont *_Nullable(NSFont *_Nullable font) {
                    
                /// Convert font to attributes
                NSMutableDictionary<NSFontDescriptorAttributeName, id> *fontAttributes = nil;
                if (!font) fontAttributes = [NSMutableDictionary new]; /// Create *empty* dict, which signals that none of the attributes of the font we *will* create below are 'intentional'. [Sep 2025]
                else       fontAttributes = getIntentionalFontAttributes(font, .fallBackToCurrentFontAttributes = true); /// If there is no intentionalFontAttributes dict on the font, yet, that means it's a font that has been created and attached to the string outside of NSAttributedString+Additions.m, and we consider *all* its attributes 'intentional'. [Sep 2025]
                
                /// Add the new fontAttributes
                ///     Old note: Could maybe use `fontDescriptorByAddingAttributes:` instead [Sep 2025]
                [fontAttributes applyOverridesFromDictionary: fontAttributeOverrides];
            
                
                NSFont *newFont;
                {
                    /// Apply system default font as fallback.
                    ///     Overview:
                    ///         If you don't specify any attributes, the font will be Helvetica at size 12.0 instead of the default system font.
                    ///         If you use `[NSFont systemFontOfSize: NSFont.systemFontSize]` it will have exactly the two attributes we're using as fallbacks here:  `@"NSCTFontUIUsageAttribute"` and `NSFontSizeAttribute`.
                    ///     On 'intentional':
                    ///         We don't consider these fallback values 'intentional', they're just fallbacks that match how the system would display a string if it had no attributes. [Sep 2025]
                    ///     On `NSCTFontUIUsageAttribute` [Sep 2025]
                    ///         This is a private attribute that seems to be used for the systemFonts instead of a font name/family.
                    ///             It seems to encapsulate both the weight and font family. The weight can be overriden by `NSFontTraitsAttribute` but the font seemingly cannot be overriden, so we don't wanna set this if there's already a font. (Reality check: I don't *use* any other fonts so this is overengineering.)
                    ///     Criticism: We could just use `[NSFont systemFontOfSize: NSFont.systemFontSize]` if it wasn't for the getIntentionalFontAttributes() mechanism. -> Complexity of the getIntentionalFontAttributes() mechanism may not be worth it.
                    
                    NSMutableDictionary *fontAttributesForFont;
                    {
                        fontAttributesForFont = [fontAttributes mutableCopy];
                        if (
                            !fontAttributesForFont[@"NSCTFontUIUsageAttribute"] && /// Discussion on `NSCTFontUIUsageAttribute` above [Sep 2025]
                            !fontAttributesForFont[NSFontFamilyAttribute] &&
                            !fontAttributesForFont[NSFontNameAttribute]           /// I know fonts can be specified with NSFontFamilyAttribute and NSFontNameAttribute but there may be more.
                        ) {
                            fontAttributesForFont[@"NSCTFontUIUsageAttribute"] = @"CTFontRegularUsage";
                        }
                        if (!fontAttributesForFont[NSFontSizeAttribute]) fontAttributesForFont[NSFontSizeAttribute] = @(NSFont.systemFontSize);
                    }
                    
                    /// Convert font attributes to font
                    newFont = [NSFont
                        fontWithDescriptor: [NSFontDescriptor fontDescriptorWithFontAttributes: fontAttributesForFont]
                        size: 0.0  /// `size: 0.0` Should make the font use the fontSize specified by the fontDescriptor || UIFont docs document this behavior but NSFont docs don't [Sep 2025]
                    ];
                }
                
                /// Store the attributes that were used to create the font on the newFont
                [getIntentionalFontAttributes(newFont, .fallBackToCurrentFontAttributes = false) setDictionary: fontAttributes];
                
                /// Return
                return newFont;
            }];
            
            return result;
        }

            #pragma mark Font size

            - (NSAttributedString *) attributedStringBySettingFontSize: (CGFloat)newFontSize {
                return [self attributedStringBySettingFontSize: newFontSize forRange: NULL];
            }

            - (NSAttributedString *) attributedStringBySettingFontSize: (CGFloat)newFontSize forRange: (const NSRangePointer _Nullable)range {
                
                /// How to use:
                /// - You can pass in NSFont.smallSystemFontSize, which is 11.0
                /// - You can pass in NSFont.systemFontSize, which is 13.0 I believe
                /// - You can pass in other arbitrary floating point numbers
                
                auto result = [self attributedStringByModifyingFontAttributesForRange: range withOverrides: @{ NSFontSizeAttribute: @(newFontSize) }];
                
                return result;
            }
            
            #pragma mark CORE: fontTraits
            /// fontTraits are 'nested' inside' fontAttributes

            - (NSAttributedString *) attributedStringByAddingFontTraits: (NSDictionary<NSFontDescriptorTraitKey, id> *)fontTraitsToAdd forRange: (const NSRangePointer _Nullable)inRange {
                
                auto result = [self attributedStringByModifyingFontAttributesForRange: inRange withOverrides: @{ NSFontTraitsAttribute: fontTraitsToAdd }]; /// Only need to return the things we want to add, because the caller will use `applyOverridesFromDictionary:` and fontTraits are also a dict so it will recurse into that. [Sep 2025]

                return result;
            }

            - (NSAttributedString *) attributedStringByAddingFontTraits: (NSDictionary<NSFontDescriptorTraitKey, id> *)traits forSubstring: (NSString *)substring {
                
                NSRange range = [self.string rangeOfString: substring];
                return [self attributedStringByAddingFontTraits: traits forRange: &range];
            }

                #pragma mark Weight

                - (NSAttributedString *) attributedStringByAddingWeight: (NSFontWeight)weight forRange: (const NSRangePointer _Nullable)range {
                    
                    ///  Weight is a double between -1 and 1
                    ///  You can use predefined constants starting with NSFontWeight, such as NSFontWeightBold
                    return [self attributedStringByAddingFontTraits: @{
                        NSFontWeightTrait: @(weight),
                    } forRange: range];
                }

                - (NSAttributedString *) attributedStringByAddingWeight: (NSFontWeight)weight forSubstring: (NSString *)string {
                    
                    return [self attributedStringByAddingFontTraits: @{
                        NSFontWeightTrait: @(weight)
                    } forSubstring: string];
                }

        #pragma mark CORE: symbolicFontTraits
        /// Symbolic font traits are an abstract and easier way to control fontTraits and fontAttributes
        /// Discussion: [Sep 2025] Only interesting things this can do is italic and monospace, neither of which are currently used by MMF. We're currently also using it for bold text, but that could be achieved with normal fontTraits (`NSFontWeightTrait`)
        
        - (NSAttributedString *) attributedStringByAddingSymbolicFontTraits: (NSFontDescriptorSymbolicTraits)traits forRange: (const NSRangePointer _Nullable)inRange {
            
            auto result = [self attributedStringByModifyingFontAttributesForRange: inRange withOverrides: [[[NSFontDescriptor new] fontDescriptorWithSymbolicTraits: traits] fontAttributes]];
            
            return result;
        }
        - (NSAttributedString *) attributedStringByAddingSymbolicFontTraits: (NSFontDescriptorSymbolicTraits)traits forSubstring: (NSString *)subStr {
            
            NSRange range = [self.string rangeOfString: subStr];
            return [self attributedStringByAddingSymbolicFontTraits: traits forRange: &range];
        }

            #pragma mark Bold

            - (NSAttributedString *) attributedStringByAddingBoldForSubstring: (NSString *)subStr {
                return [self attributedStringByAddingSymbolicFontTraits: NSFontDescriptorTraitBold forSubstring: subStr];
            }
                
            - (NSAttributedString *) attributedStringByAddingBoldForRange: (const NSRangePointer _Nullable)range {
                return [self attributedStringByAddingSymbolicFontTraits: NSFontDescriptorTraitBold forRange: range];
            }

            #pragma mark Italic

            - (NSAttributedString *) attributedStringByAddingItalicForSubstring: (NSString *)subStr {
                return [self attributedStringByAddingSymbolicFontTraits: NSFontDescriptorTraitItalic forSubstring: subStr];
            }

            - (NSAttributedString *) attributedStringByAddingItalicForRange: (const NSRangePointer _Nullable)range {
                return [self attributedStringByAddingSymbolicFontTraits: NSFontDescriptorTraitItalic forRange: range];
            }

#pragma mark - Special usecases

- (NSAttributedString *) attributedStringByAddingBlankLineHeight: (CGFloat)height forRange:(const NSRangePointer _Nullable)range {

    assert(false); /// Unused and untested [Oct 2025]

    NSAttributedString * result = [self copy]; /// Not sure if copy is necessary here [Oct 2025]

    auto searchRange = NSMakeRange(0, self.length);

    while (1) {
        auto blankLinesRange = [result.string rangeOfString: @"(\n){2,}" options: NSRegularExpressionSearch range: searchRange];
        if (blankLinesRange.location == NSNotFound) break;
        
        /// Modify blankLine height
        {
            if ((0)) {
                /// Notes: [Oct 2025]
                ///     - The ParagraphSpacing controls the height of *any* linebreaks not just double linebreaks, so we can't just use that to specifically control blankLine height.
                ///     - The ParagraphSpacing *also influences* the overall height of blank lines but we'll ignore that for now.
                result = [result attributedStringByAddingParagraphSpacing: height forRange: &blankLinesRange];
            }
            else {
                result = [result attributedStringBySettingFontSize: height forRange: &blankLinesRange];
            }
        }
        
        searchRange = NSMakeRange(NSMaxRange(blankLinesRange), self.length - NSMaxRange(blankLinesRange));
    }
    
    return result;
};

- (NSAttributedString *) attributedStringByAddingHintStyle {
    
    /// Notes:
    /// - The is the style of the small grey 'hint' texts we see all over the the General Tab and other Tabs. However those are mostly defined inside Interface Builder.
    /// - Problem: .secondaryLabelColor seems to look good on NSTextFields but in NSTextViews, it's really dim in darkmode.
    ///     - (As of 30.08.2024, macOS Sequoia Beta)
    ///     - .systemGrayColor seems to look better, maybe we should switch to that if this isn't resolved.
    ///     - Our ToastNotifications use NSTextViews to be able to display links properly.
    
    NSAttributedString *ret = self.copy;
    ret = [ret attributedStringBySettingFontSize: NSFont.smallSystemFontSize];
    ret = [ret attributedStringByAddingColor: NSColor.secondaryLabelColor forRange: NULL];
    
    return ret;
}

#if 0
    #pragma mark Weight (legacy)

    - (NSMutableAttributedString *)attributedStringBySettingWeight:(NSInteger)weight forRange:(const NSRangePointer _Nullable)inRange {
        
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
        
        NSMutableAttributedString *ret = [self mutableCopy];

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
#endif

@end
