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
    
    /// For stenography. Based on this readme https://github.com/Endrem/Zero-Width-Characters
    
    MFZeroWidthCharacterSpace = 0x0000200b,     /// We use this to group 8 bits into a byte
    MFZeroWidthCharacterNonJoiner = 0x0000200c, /// We use this to encode 0
    MFZeroWidthCharacterJoiner = 0x0000200d,    /// We use this to encode 1
};


- (NSString *)stringByAppendingStringAsSecretMessage:(NSString *)message {
    NSString *secretMessage = [message encodedAsSecretMessage];
    return [self stringByAppendingString:secretMessage];
}


- (NSString *)encodedAsSecretMessage {
    
    /// Returns `self` encoded as a zero-width string.
    ///     The result will contain a sequence of zero-width 200b, 200c, and 200d unicode characters.
    ///     200c and 200d encode 0 and 1, while 200b serves as a divider between packets of 8 bits.
    ///     This sequence of bytes represents the UTF8 encoding of `self`.
    ///
    ///     If we represent 200b as `B`, 200c as `c` and 200d as `d`, the resulting sequence might look like this:
    ///         BccddcdddBddccddcdBdddcccdcB
    ///

    /// Get binary representation of self
    NSArray *binaryCharacters = [self binaryCharacters];
    
    /// Convert binary to UTF32Char array containing invisible characters.
    NSMutableArray<NSNumber *> *UTF32Result = [NSMutableArray array];
    for (NSArray *byte in binaryCharacters) {
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

- (NSString *)decodedAsSecretMessage {
    
    /// Decodes `self` if `self` is a message previously encoded with `encodedAsSecretMessage:`
    ///     Don't use this on random strings.
    ///     This function should crash if the string doesn't exactly follow the secret message encoding.
    
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
    NSString *result = [NSString stringWithBinaryCharacters:resultArray];
    
    /// Return
    return result;
}

- (NSArray<NSString *> *)secretMessages {

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
        NSString *decodedMessage = [encodedMessage decodedAsSecretMessage];
        [result addObject:decodedMessage];
    }
    
    /// Return
    return result;
}

///
/// Binary array conversion
///

+ (NSString *)stringWithBinaryCharacters:(NSArray<NSArray<NSNumber *> *> *)characters {
    
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
    resultCString[characters.count] = '\0';
    
    /// Convert cString to NSString
    NSString *result = [NSString stringWithCString:resultCString encoding:NSUTF8StringEncoding];
    
    /// Return
    return result;
}

- (NSArray<NSArray<NSNumber *> *> *)binaryCharacters {
    
    /// Returns an array of arrays where the inner arrays each contain 8 NSNumbers that are either @(0) or @(1)
    ///     Each of the inner arrays represents the binary representation of a c char in the UTF8 encoding of `self`
    
    NSMutableArray *result = [NSMutableArray array];
    
    const char *str = [self cStringUsingEncoding:NSUTF8StringEncoding];
    
    for (int i = 0; i < strlen(str); i++) {
        
        char c = str[i];
        NSMutableArray *bits = [NSMutableArray array];
        
        for (int j = 0; j < 8; j++) {
            
            if (c & 1) {
                [bits insertObject:@(1) atIndex:0];
            } else {
                [bits insertObject:@(0) atIndex:0];
            }
            c = c >> 1;
        }
        
        [result addObject:bits];
    }
    
    return result;
}


///
/// UTF32 conversion
///

+ (NSString *)stringWithUTF32Characters:(NSArray<NSNumber *> *)characters {
    
    /// Convert NSArray to UTF32Char array
    UTF32Char buffer[characters.count + 1];
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
- (NSArray<NSNumber *> *)UTF32Characters {
    
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

- (NSString *)UTF32CharacterDescription {
    
    /// Returns a string that looks like
    ///     0x00000031 0x00000061 0x00000061 0x00000062 ...`
    
    NSMutableArray *resultArray = [NSMutableArray array];
    for (NSNumber *character in [self UTF32Characters]) {
        [resultArray addObject:[NSString stringWithFormat:@"%#010x", [character intValue]]];
    }
    
    NSString *result = [resultArray componentsJoinedByString:@" "];
    
    return result;
}

@end
