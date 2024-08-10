//
// --------------------------------------------------------------------------
// NSString+Additions.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "NSString+Additions.h"
#import "NSAttributedString+Additions.h"

@implementation NSString (Additions)

- (NSString *)substringWithRegex:(NSString *)regex {
    
    NSRange range = [self rangeOfString:regex options:NSRegularExpressionSearch];
    
    NSString *result;
    if (range.location == NSNotFound) {
        result = nil;
    } else {
        result = [self substringWithRange:range];
    }
    
    return result;
}

- (NSAttributedString *)attributed {
    return [[NSAttributedString alloc] initWithString:self];
}

- (NSString *)firstCapitalized {
    NSString *firstChar = [self substringToIndex:1];
    NSString *rest = [self substringFromIndex:1];
    
    return [[[firstChar capitalizedString] stringByAppendingString:rest] copy]; /// Why copy?
}
- (NSString *)stringByRemovingAllWhiteSpace {
    return [self.attributed attributedStringByRemovingAllWhitespace].string;
}
- (NSString *)stringByTrimmingWhiteSpace {
    return [[[self attributed] attributedStringByTrimmingWhitespace] string];
}

- (NSString *)stringByAddingIndent:(NSInteger)indent {
    return [self stringByAddingIndent:indent withCharacter:@" "];
}

- (NSString *)stringByAddingIndent:(NSInteger)indent withCharacter:(NSString *)indentCharacter {
    
    /// Split self
    NSArray *lines = [self componentsSeparatedByString:@"\n"];
    
    /// Build padded lines
    NSMutableArray *paddedLines = [NSMutableArray arrayWithCapacity:[lines count]];
    for (NSString *line in lines) {
        NSString *paddedLine = [line stringByPrependingCharacter:indentCharacter count:indent];
        [paddedLines addObject:paddedLine];
    }
    /// Join result
    NSString *result = [paddedLines componentsJoinedByString:@"\n"];
    
    /// Return
    return result;
}

- (NSString *)stringByPrependingCharacter:(NSString *)prependedCharacter count:(NSInteger)count {
    /// Create padding string
    NSString *padding = [@"" stringByPaddingToLength:count withString:prependedCharacter startingAtIndex:0];
    NSString *result = [padding stringByAppendingString:self];
    return result;
}

@end
