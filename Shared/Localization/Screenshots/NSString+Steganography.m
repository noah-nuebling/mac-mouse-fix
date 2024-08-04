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
#import "BidirectionalMap.h"

#if IS_MAIN_APP
#import "Mac_Mouse_Fix-Swift.h"
#elif IS_HELPER
#import "Mac_Mouse_Fix_Helper-Swift.h"
#endif

@implementation NSAttributedString (MFSteganography)

- (NSAttributedString *)attributedStringByAppendingStringAsSecretMessage:(NSString *)message {
    NSString *encodedMessage = [message encodedAsSecretMessage];
    NSAttributedString *result = [self attributedStringByAppending:encodedMessage.attributed];
    return result;
}

- (NSArray<NSString *> *)secretMessages {
    NSArray *result = [self.string secretMessages];
    return result;
}

@end

@implementation NSString (MFSteganography)

///
/// Secret messages
///

typedef NS_ENUM(UTF32Char, MFZeroWidthCharacter) {
    
    /// For steganography. Based on this readme https://github.com/Endrem/Zero-Width-Characters
    MFZeroWidthCharacterSpace                       = 0x200B,       /// This one get removed when we apply stripWhitespace()
    MFZeroWidthCharacterNonJoiner                   = 0x200C,       /// We use this to encode 0
    MFZeroWidthCharacterJoiner                      = 0x200D,       /// We use this to encode 1
    
    /// More values from https://mayadevbe.me/posts/projects/zw_steg/
    MFZeroWidthCharacterWordJoiner                  = 0x2060,       /// We use this to encode 2
    MFZeroWidthCharacterMongolianVowelSeparator     = 0x180E,       /// This one prints weirdly
    MFZeroWidthCharacterRightToLeftMark             = 0x200F,
    
    /// More characters from: https://330k.github.io/misc_tools/unicode_steganography.html
    MFZeroWidthCharacterLeftToRightMark             = 0x200E,
    MFZeroWidthCharacterLeftToRightEmbedding        = 0x202A,
    MFZeroWidthCharacterPopDirectionalFormatting    = 0x202C,
    MFZeroWidthCharacterLeftToRightOverride         = 0x202D,
    MFZeroWidthCharacterInvisibleTimes              = 0x2062,       /// We use this to encode 3
    MFZeroWidthCharacterInvisibleSeparator          = 0x2063,       /// We use this as a control character to mark the start/end of a secret message.
    MFZeroWidthCharacterNoBreakSpace                = 0xFEFF,
    
};

///
/// Base-4 secret message encoding/decoding
///

- (NSArray<NSNumber *> *)secretMessageStartSequence {
    NSArray *result = @[@0x2063, @0x200C, @0x2063, @0x200D, @0x2063]; /// 2063 is only used in the start/end sequence not in the secretMessage's body
    return result;
}
- (NSArray<NSNumber *> *)secretMessageEndSequence {
    NSArray *result = @[@0x2063, @0x200D, @0x2063, @0x200C, @0x2063]; /// Inverse of the start sequence
    return result;
}

- (BidirectionalMap<NSNumber *, NSNumber *> *)quaternaryDigitToZeroWidthCharacterMap {
        
    static BidirectionalMap *_characterMap = nil;
    if (_characterMap == nil) {
        _characterMap = [[BidirectionalMap alloc] initWithDictionary:@{
            @-1:    @0x2063,
            @0:     @0x200C,
            @1:     @0x200D,
            @2:     @0x2060,
            @3:     @0x2062,
        }];
    }
    
    return _characterMap;
}

- (NSString *)stringByAppendingStringAsSecretMessage:(NSString *)message {
    NSString *secretMessage = [message encodedAsSecretMessage];
    NSString *result = [self stringByAppendingString:secretMessage];
    return result;
}

static NSRegularExpression *secretMessageRegex(void) {
    
    /// Define pattern
    NSString *pattern = @"\u2063\u200C\u2063\u200D\u2063"           /// Start sequence
    "(?:(?:[\u200C\u200D\u2060\u2062]{4})*)"    /// Arbitrary sequence of the 4 characters encoding, 0,1,2,3. Sequence length needs to be divisible by 4 since 4 quaternary digits encode one UTF-8 char.
    "\u2063\u200D\u2063\u200C\u2063";           /// End sequence
    
    /// Create regex
    NSRegularExpressionOptions expressionOptions = 0;
    NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:pattern options:expressionOptions error:nil];
    
    /// Return
    return expression;
}

- (NSString *)withoutSecretMessages {
    
    /// Find secretMessages
    NSRegularExpression *regex = secretMessageRegex();
    NSMatchingOptions matchingOptions = 0;
    
    /// Remove secretMessages
    NSString *result = [regex stringByReplacingMatchesInString:self options:matchingOptions range:NSMakeRange(0, self.length) withTemplate:@""];
    
    /// Return
    return result;
}

- (NSArray<NSString *> *)secretMessages {
 
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
        [result addObject:decodedMessage];
    }
    
    /// Return
    return result;
}

- (NSString *)decodedAsSecretMessage {
        
    NSInteger startLength = [self secretMessageStartSequence].count;
    NSInteger endLength = [self secretMessageEndSequence].count;
    NSRange coreRange = NSMakeRange(startLength, self.length - startLength - endLength);
    NSString *coreMessage = [self substringWithRange:coreRange];
    
    NSMutableArray<NSNumber *> *quaternaryDigits = [NSMutableArray array];
    for (NSNumber *character in [coreMessage UTF32Characters]) {
        NSNumber *digit = [[self quaternaryDigitToZeroWidthCharacterMap] leftValueForRightValue:character];
        [quaternaryDigits addObject:digit];
    }
    NSString *result = [NSString stringWithQuaternaryArray:quaternaryDigits];
    
    return result;
}



- (NSString *)encodedAsSecretMessage {
    
    NSMutableArray *resultArray = [NSMutableArray array];
    
//    [resultArray addObject:@(MFZeroWidthCharacterSpace)]; /// Add space to prevent breaking markdown __emphasis__ but it doesn't work, also breaks our `[string.withoutSecretMessages isEqual:@"(null)]"` checks.
    [resultArray addObjectsFromArray:[self secretMessageStartSequence]];
    
    NSArray<NSNumber *> *digits = [self quaternaryArray];
    for (NSNumber *digit in digits) {
        NSNumber *zeroWidthCharacter = [[self quaternaryDigitToZeroWidthCharacterMap] rightValueForLeftValue:digit];
        [resultArray addObject:zeroWidthCharacter];
    }
    
    [resultArray addObjectsFromArray:[self secretMessageEndSequence]];
//    [resultArray addObject:@(MFZeroWidthCharacterSpace)];
    
    NSString *result = [NSString stringWithUTF32Characters:resultArray];
    
    return result;
}

///
/// Quaternary array conversion
///

- (NSArray<NSNumber *> *)quaternaryArray {
    
    /// Returns an array of @0, @1, @2, @3, which represents the quarternary encoding of the UTF8 encoding of `self`
    
    NSMutableArray *result = [NSMutableArray array];
    
    for (NSArray<NSNumber *> *byte in [self binaryArray]) {
        
        for (int i = 0; i < 8; i += 2) {
            
            int a = [byte[i] intValue];
            int b = [byte[i+1] intValue];
            int quart = (a << 1) + b;
            assert(0 <= quart && quart <= 3);
            
            [result addObject:@(quart)];
        }
    }
    
    return result;
}

+ (NSString *)stringWithQuaternaryArray:(NSArray<NSNumber *> *)digits {
        
    NSMutableArray<NSArray<NSNumber *> *> *binaryArray = [NSMutableArray array];
    
    for (int i = 0; i < digits.count; i += 4) {
        
        NSMutableArray *byte = [NSMutableArray array];
        
        for (int j = 0; j < 4; j++) {
            int quartDigit = [digits[i+j] intValue];
            [byte addObject:@((quartDigit & 2) != 0)]; /// Measure large bit of quart digit
            [byte addObject:@((quartDigit & 1) != 0)];  /// Measure small bit of quart digit
        }
        
        [binaryArray addObject:byte];
    }
    
    NSString *result = [self stringWithBinaryArray:binaryArray];
    return result;
}

///
/// Binary array conversion
///

- (NSArray<NSArray<NSNumber *> *> *)binaryArray {
    
    /// Returns an array of arrays where the inner arrays each contain 8 NSNumbers that are either @(0) or @(1)
    ///     Each of the inner arrays represents the binary representation of an 8-bit c char in the UTF8 encoding of `self`
    
    NSMutableArray *result = [NSMutableArray array];
    
    const char *str = [self cStringUsingEncoding:NSUTF8StringEncoding];
    
    for (int i = 0; i < strlen(str); i++) {
        
        char c = str[i];
        NSMutableArray *byte = [NSMutableArray array];
        
        for (int j = 0; j < 8; j++) {
            
            if (c & 1) {
                [byte insertObject:@(1) atIndex:0];
            } else {
                [byte insertObject:@(0) atIndex:0];
            }
            c = c >> 1;
        }
        
        [result addObject:byte];
    }
    
    return result;
}

+ (NSString *)stringWithBinaryArray:(NSArray<NSArray<NSNumber *> *> *)characters {
    
    char resultCString[characters.count + 1];
    
    for (int i = 0; i < characters.count; i++) {
        
        NSArray<NSNumber *> *characterBits = characters[i];
        
        /// Create c char from bit array
        
        char c = 0;
        BOOL isFirstIter = YES;
        
        for (NSNumber *bit in characterBits) {
            
            if (!isFirstIter) {
                c = c << 1;
            }
            isFirstIter = NO;
            
            if (bit.intValue == 0) {
                c = c | 0; /// This doesn't do anything
            } else if (bit.intValue == 1) {
                c = c | 1;
            } else {
                assert(false);
            }
        }
        
        /// Add the char to the cString
        resultCString[i] = c;
    }
    
    /// Set last char to string terminator
    resultCString[characters.count] = '\0'; /// Don't think this is necessary, since the last char should already be initialized to 0.
    
    /// Convert cString to NSString
    NSString *result = [NSString stringWithCString:resultCString encoding:NSUTF8StringEncoding];
    
    /// Return
    return result;
}

///
/// UTF32 conversion
///

- (NSArray<NSNumber *> *)UTF32Characters {
    
    /// Returns an array of UTF32Chars that make up the string
    ///     Note: UTF32 is the simplest encoding. Each unicode character in the string is represented by exactly one 32-bit char. Whereas with UTF8, each unicode character might by represented by between 1 and 4 8-bit chars.
    
    /// Get UTF32Char  array
    UTF32Char buffer[self.length + 1]; /// Not sure why `+ 1` Probably null terminator?
    NSStringEncodingConversionOptions conversionOptions = 0;
    [self getBytes:buffer maxLength:sizeof(UTF32Char) * self.length usedLength:nil encoding:NSUTF32LittleEndianStringEncoding options:conversionOptions range:NSMakeRange(0, self.length) remainingRange:nil];
    
    /// Convert to NSArray
    NSMutableArray *result = [NSMutableArray array];
    for (int i = 0; i < self.length; i++) {
        UTF32Char c = buffer[i];
        [result addObject:@(c)];
    }
    
    /// Return
    return result;
}

+ (NSString *)stringWithUTF32Characters:(NSArray<NSNumber *> *)characters {
    
    /// Convert NSArray to UTF32Char array
    UTF32Char buffer[characters.count + 1]; /// Don't need the + 1 (null terminator) here I think.
    int i = 0;
    for (NSNumber *character in characters) {
        UTF32Char c = [character intValue];
        buffer[i] = c;
        i++;
    }
    
    /// Convert to string
    NSString *result = [[NSString alloc] initWithBytes:buffer length:sizeof(UTF32Char) * characters.count encoding:NSUTF32LittleEndianStringEncoding];
    
    /// Return
    return result;
}

- (NSString *)UTF32CharacterDescription {
    
    /// Returns a string that looks like
    ///     0x00000031 0x00000061 0x00000061 0x00000062 ...`
    /// For debugging
    
    NSMutableArray *resultArray = [NSMutableArray array];
    for (NSNumber *character in [self UTF32Characters]) {
        [resultArray addObject:[NSString stringWithFormat:@"%#010x", [character intValue]]];
    }
    
    NSString *result = [resultArray componentsJoinedByString:@" "];
    
    return result;
}

///
/// Older space-inefficient encoding
///

/// Discussion:
///     This encoding uses just 2+1 zero-width characters, to create a base-2 encoding. There's a character limit of 512 in the UIStrings we can retrieve inside an XCUITest, which lead to problems,
///     so we'll create a new base-4 encoding that will hopefully be space-efficient enough.
///     Update: There we still problems on some strings so we found a new solution: We get the raw AXUIElement from the XCUIElement through private methods and get the string from there - it doesn't have the 512 character limit. Now we could theoretically use the simpler binary encoding again. But it the quaternary one also works fine.

- (NSString *)stringByAppendingStringAsSecretMessage_Inefficient:(NSString *)message {
    NSString *secretMessage = [message encodedAsSecretMessage_Inefficient];
    return [self stringByAppendingString:secretMessage];
}


- (NSArray<NSString *> *)secretMessages_Inefficient {

    /// Finds any secret messages in `self`, dedodes them and returns them in an array
    
    /// Declare result
    NSMutableArray *result = [NSMutableArray array];
    
    /// Finds secret messages in the string.
    NSString *pattern = @"(?:\u200b[\u200c\u200d]{8})*\u200b"; /// Matches packets of 8 200c or 200d chars surrounded by 200b chars.
    NSRegularExpressionOptions expressionOptions = 0;
    NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:pattern options:expressionOptions error:nil];
    NSMatchingOptions matchingOptions = 0;
    NSArray<NSTextCheckingResult *> *matches = [expression matchesInString:self options:matchingOptions range:NSMakeRange(0, self.length)];
    
    /// Decode the secret messages
    for (NSTextCheckingResult *match in matches) {
        NSRange r = [match range];
        NSString *encodedMessage = [self substringWithRange:r];
        NSString *decodedMessage = [encodedMessage decodedAsSecretMessage_Inefficient];
        [result addObject:decodedMessage];
    }
    
    /// Return
    return result;
}

- (NSString *)encodedAsSecretMessage_Inefficient {
    
    /// Returns `self` encoded as a zero-width string.
    ///     The result will contain a sequence of zero-width 200b, 200c, and 200d unicode characters.
    ///     200c and 200d encode 0 and 1, while 200b serves as a divider between packets of 8 bits.
    ///     This sequence of bytes represents the UTF8 encoding of `self`.
    ///
    ///     If we represent 200b as `B`, 200c as `c` and 200d as `d`, the resulting sequence might look like this:
    ///         BccddcdddBddccddcdBdddcccdcB
    ///

    /// Get binary representation of self
    NSArray *binaryArray = [self binaryArray];
    
    /// Convert binary to UTF32Char array containing invisible characters.
    ///     Note: I don't think we'd have to be using UTF32 stuff here instead of UTF8
    NSMutableArray<NSNumber *> *UTF32Result = [NSMutableArray array];
    for (NSArray *byte in binaryArray) {
        [UTF32Result addObject:@(MFZeroWidthCharacterSpace)];
        for (NSNumber *bit in byte) {
            if (bit.intValue == 0) {
                [UTF32Result addObject:@(MFZeroWidthCharacterNonJoiner)];
            } else if (bit.intValue == 1) {
                [UTF32Result addObject:@(MFZeroWidthCharacterJoiner)];
            } else {
                assert(false);
            }
        }
    }
    [UTF32Result addObject:@(MFZeroWidthCharacterSpace)];
    
    /// Convert UTF32 char array to string
    NSString *result = [NSString stringWithUTF32Characters:UTF32Result];
    
    /// Return
    return result;
}

- (NSString *)decodedAsSecretMessage_Inefficient {
    
    /// Decodes `self` if `self` is a message previously encoded with `encodedAsSecretMessage:`
    ///     Don't use this on random strings.
    ///     This function could crash if the string doesn't exactly follow the secret message encoding.
    
    NSMutableArray<NSArray<NSNumber *> *> *resultArray = [NSMutableArray array];
    
    NSMutableArray<NSNumber *> *latestByteArray = [NSMutableArray array];
    
    /// Get UTF32Char array for self
    NSArray<NSNumber *> *UTF32Chars = [self UTF32Characters];
    
    /// Iterate UTF32 chars
    BOOL isFirstIter = YES;
    for (int i = 0; i < UTF32Chars.count; i++) {
        
        /// Get UTF32Char
        UTF32Char c = [UTF32Chars[i] intValue];
        
        /// Append to result when we hit a byte divider
        BOOL isByteDivider = i % 9 == 0;
        if (isByteDivider) {
            assert(c == MFZeroWidthCharacterSpace);
            if (!isFirstIter) {
                [resultArray addObject:latestByteArray];
                latestByteArray = [NSMutableArray array];
            }
        } else {
         
            if (c == MFZeroWidthCharacterNonJoiner) {
                [latestByteArray addObject:@(0)];
            } else if (c == MFZeroWidthCharacterJoiner) {
                [latestByteArray addObject:@(1)];
            } else {
                assert(false);
            }
        }
        
        isFirstIter = NO;
    }
    
    /// Convert binary array to string
    NSString *result = [NSString stringWithBinaryArray:resultArray];
    
    /// Return
    return result;
}

@end

