//
// --------------------------------------------------------------------------
// NSString+Steganography.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "NSString+Steganography.h"
#import "NSAttributedString+Additions.h"
#import "NSString+Additions.h"
#import "MFLoop.h"

#if IS_MAIN_APP
#import "Mac_Mouse_Fix-Swift.h"
#elif IS_HELPER
#import "Mac_Mouse_Fix_Helper-Swift.h"
#endif
///
/// History: [Nov 2025]
///     - We first used a base-2 encoding,
///     - then we switched to base-4 to save space due to character limit of 512 in the UIStrings we can retrieve inside an XCUITest.
///     - But that still wasn't enough for some strings, so we we got the raw AXUIElement from the XCUIElement through private methods and get the string from there.
///     - After that, we kept the base-4 encoding for a while, but turns out \u2062, and \u2063 break NSLineBreakStrategyPushOut, so we simplified things back to base-2 encoding. [Nov 2025] While doing that we also simplified the implementation a lot.
///         - Actually, NSLineBreakStrategyPushOut is broken by any linebreaks characters, if there are too many of them. u2062, and \u2063 don't seem special. See `extractAnnotationsFromString:` for our solution [Nov 2025]
///             - Also see `playground-oct-2025 > orphaned-word-tests`
///

typedef NS_ENUM(unichar, MFZeroWidthCharacter) {
    
    /// Note: [Sep 2025] None of the 5 characters we use (\u200C, \u200D, \u2060, \u2062, \u2063) are part of `NSCharacterSet.whitespaceAndNewlineCharacterSet`
    ///     Update, we stopped using `\u2062` and `\u2063` [Nov 2025]
    
    /// For steganography. Based on this readme https://github.com/Endrem/Zero-Width-Characters
    MFZeroWidthCharacterSpace                       = u'\u200B',       /// This one get removed when we apply stripWhitespace()
    MFZeroWidthCharacterNonJoiner                   = u'\u200C',       /// We use this to encode 0
    MFZeroWidthCharacterJoiner                      = u'\u200D',       /// We use this to encode 1
    
    /// More values from https://mayadevbe.me/posts/projects/zw_steg/
    MFZeroWidthCharacterWordJoiner                  = u'\u2060',       /// We use this as a control character to mark the start/end of a secret message.
    MFZeroWidthCharacterMongolianVowelSeparator     = u'\u180E',       /// This one prints weirdly
    MFZeroWidthCharacterRightToLeftMark             = u'\u200F',
    
    /// More characters from: https://330k.github.io/misc_tools/unicode_steganography.html
    MFZeroWidthCharacterLeftToRightMark             = u'\u200E',
    MFZeroWidthCharacterLeftToRightEmbedding        = u'\u202A',
    MFZeroWidthCharacterPopDirectionalFormatting    = u'\u202C',
    MFZeroWidthCharacterLeftToRightOverride         = u'\u202D',
    MFZeroWidthCharacterInvisibleTimes              = u'\u2062',    /// Usable. Used as `kannotationSuffix`in `LocalizedStringAnnotation.m` [Nov 2025]
    MFZeroWidthCharacterInvisibleSeparator          = u'\u2063',    /// Usable
    MFZeroWidthCharacterNoBreakSpace                = u'\uFEFF',
    
};

MFDataClassImplement2(MFDataClassBase, FoundSecretMessage,
    readwrite, strong, nonnull, NSString *, secretMessage,
    readwrite, assign,        , NSRange,    rangeInString
)

static NSString *secretMessageRegexString(void) {
    NSString *pattern = @""
        "\u2060\u200C\u2060\u200D\u2060"            /// Start sequence
        "(?:(?:[\u200C\u200D]{8})*)"                /// Arbitrary sequence of the 2 characters encoding 0 and 1. Each packet of 8 0/1 encodes one UTF-8 char.
        @"\u2060\u200D\u2060\u200C\u2060";          /// End sequence
    return pattern;
}

static NSRegularExpression *secretMessageRegex(void) {
    NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern: secretMessageRegexString() options: 0 error: NULL];
    return expression;
}

@implementation NSAttributedString (MFSteganography)

- (NSAttributedString *)attributedStringByAppendingStringAsSecretMessage:(NSString *)message {
    NSString *encodedMessage = [message encodedAsSecretMessage];
    NSAttributedString *result = [self attributedStringByAppending:encodedMessage.attributed];
    return result;
}

- (NSArray<FoundSecretMessage *> *)_secretMessages {
    NSArray *result = [self.string _secretMessages];
    return result;
}

- (NSAttributedString *)withoutSecretMessages { /// Also see `-[NSString withoutSecretMessages]` below [Dec 2025]
    assert(false); /// Unused [Dec 2025]
    return [self attributedStringByReplacing: secretMessageRegexString() with: @"".attributed options: NSRegularExpressionSearch];
}

@end

@implementation NSString (MFSteganography)

+ (NSCharacterSet *) secretMessageChars {
    /// All the characters used in our secret messages [Sep 2025]
    ///     Note: [Sep 2025] Could use `-fobjc-constant-literals` if our deployment target was macOS 11+ (See: https://developer.apple.com/forums/thread/783930)
    static NSCharacterSet *result = nil;
    mfonce(mfoncet, ^{
        result = [NSCharacterSet characterSetWithCharactersInString: @"\u2060\u200C\u200D"];
    });
    return result;
}

- (NSString *)secretMessageStartSequence {

    return @"\u2060\u200C\u2060\u200D\u2060"; /// 2060 is only used in the start/end sequence not in the secretMessage's body
}
- (NSString *)secretMessageEndSequence {
    return @"\u2060\u200D\u2060\u200C\u2060"; /// Inverse of the start sequence
    
}

unichar steg_bitToChar(int bit) {
    if (bit == 0) return u'\u200C';
    if (bit == 1) return u'\u200D';
    else          abort();
}
int steg_charToBit(unichar c) {
    if (c == u'\u200C') return 0;
    if (c == u'\u200D') return 1;
    else          abort();
}


- (NSString *)stringByAppendingStringAsSecretMessage:(NSString *)message {
    NSString *secretMessage = [message encodedAsSecretMessage];
    NSString *result = [self stringByAppendingString:secretMessage];
    return result;
}

- (NSString *)withoutSecretMessages { /// Also see `-[NSAttributedString withoutSecretMessages]` above
    return [self stringByReplacingOccurrencesOfString: secretMessageRegexString() withString: @"" options: NSRegularExpressionSearch range: NSMakeRange(0, self.length)];
}

- (NSArray<FoundSecretMessage *> *)_secretMessages { /// Probably don't use this directly, and use `extractAnnotationsFromString:` instead [Dec 2025]
 
    /// Declare result
    NSMutableArray *result = [NSMutableArray array];
    
    /// Find secret messages in the string.
    NSRegularExpression *regex = secretMessageRegex();
    NSMatchingOptions matchingOptions = 0;
    NSArray<NSTextCheckingResult *> *matches = [regex matchesInString:self options:matchingOptions range:NSMakeRange(0, self.length)];
    
    /// Decode the messages
    for (NSTextCheckingResult *match in matches) {
        NSRange r = [match range];
        NSString *encodedMessage = [self substringWithRange:r];
        NSString *decodedMessage = [encodedMessage decodedAsSecretMessage];
        
        [result addObject: [[FoundSecretMessage alloc] initWith_secretMessage: decodedMessage rangeInString: r]];
    }
    
    /// Return
    return result;
}

- (NSString *)decodedAsSecretMessage {
        
    NSUInteger startLength = [[self secretMessageStartSequence] length];
    NSUInteger endLength = [[self secretMessageEndSequence] length];
    NSRange coreRange = NSMakeRange(startLength, self.length - startLength - endLength);
    NSString *coreMessage = [self substringWithRange: coreRange];
    
    unichar invisibleChars[coreMessage.length];
    [coreMessage getCharacters: invisibleChars];
    if (arrcount(invisibleChars) % 8 != 0) {
        assert(false);
        return @"";
    }
    char decodedChars[arrcount(invisibleChars) / 8] = {};
    {
        int i = 0;
        int j = 0;
        while (1) {
            if (i >= arrcount(invisibleChars)) break;
            
            decodedChars[j] |= steg_charToBit(invisibleChars[i]) << (i % 8);
            
            i++;
            if (i % 8 == 0) j += 1; /// Move to next decoded char
        }
    }
    
    auto result = [[NSString alloc] initWithBytes: decodedChars length: sizeof(decodedChars) encoding: NSUTF8StringEncoding];
    
    if (!result) assert(false);
    
    return result ?: @"";
}
- (NSString *)encodedAsSecretMessage {
    
    const char *decodedChars = self.UTF8String;
    unichar invisibleChars[strlen(decodedChars) * 8] = {};
    
    for (int i = 0; decodedChars[i]; i++)
        loopc(j, 8)
            invisibleChars[(i*8)+j] = steg_bitToChar(!!(decodedChars[i] & (1 << j)));
    
    auto result = stringf(@"%@%@%@",
        [self secretMessageStartSequence],
        [NSString stringWithCharacters: invisibleChars length: arrcount(invisibleChars)],
        [self secretMessageEndSequence]
    );
    
    return result;
}

@end

