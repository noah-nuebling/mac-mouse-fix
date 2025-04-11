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

- (NSString *_Nullable)substringWithRegex:(NSString *_Nonnull)regex {
    
    NSRange range = [self rangeOfString:regex options:NSRegularExpressionSearch];
    
    NSString *result;
    if (range.location == NSNotFound) {
        result = nil;
    } else {
        result = [self substringWithRange:range];
    }
    
    return result;
}

- (NSAttributedString *_Nonnull)attributed {
    return [[NSAttributedString alloc] initWithString:self];
}

- (NSString *_Nonnull)firstCapitalized {
    NSString *firstChar = [self substringToIndex:1];
    NSString *rest = [self substringFromIndex:1];
    
    return [[[firstChar capitalizedString] stringByAppendingString:rest] copy]; /// Why copy?
}
- (NSString *_Nonnull)stringByRemovingAllWhiteSpace {
    return [self.attributed attributedStringByRemovingAllWhitespace].string;
}
- (NSString *_Nonnull)stringByTrimmingWhiteSpace {
    return [[[self attributed] attributedStringByTrimmingWhitespace] string];
}

- (NSString *_Nonnull)stringByAddingIndent:(NSInteger)indent {
    return [self stringByAddingIndent:indent withCharacter:@" "];
}

- (NSString *_Nonnull)stringByAddingIndent:(NSInteger)indent withCharacter:(NSString *_Nonnull)ch {
    
    /// Note: [Apr 2025]
    ///     Could also implement this with regex find-and-replace.
    ///     We have multiple implementations of 'addIndent' functions. Search for `)(.)` to find the ones using regex find-and-replace
    ///     At some point we should probably consolidate the implementations
    
    /// Split self
    NSArray *lines = [self componentsSeparatedByString:@"\n"];
    
    /// Build padded lines
    NSMutableArray *paddedLines = [NSMutableArray arrayWithCapacity:[lines count]];
    for (NSString *line in lines) {
        NSString *paddedLine = [line stringByPrependingCharacter:ch count:indent];
        [paddedLines addObject:paddedLine];
    }
    /// Join result
    NSString *result = [paddedLines componentsJoinedByString:@"\n"];
    
    /// Return
    return result;
}

- (NSString *_Nonnull)stringByPrependingCharacter:(NSString *_Nonnull)ch count:(NSInteger)count {
    
    NSString *result = [self stringByPaddingToLength: (self.length + ch.length*count)
                                          withString: ch
                                     startingAtIndex: 0];
    return result;
}

@end
