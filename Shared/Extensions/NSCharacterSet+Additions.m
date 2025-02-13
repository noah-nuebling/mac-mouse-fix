//
// --------------------------------------------------------------------------
// NSCharacterSet+Additions.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2025
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "NSCharacterSet+Additions.h"
#import "MFDefer.h"

@implementation NSCharacterSet (Additions)

#pragma mark - Convenience macros

#define makeCharSet(str) (NSCharacterSet *) ({                                                 \
    static NSCharacterSet *result = nil;                                    \
    static dispatch_once_t onceToken;                                       \
    dispatch_once(&onceToken, ^{                                            \
        result = [NSCharacterSet characterSetWithCharactersInString: (str)];\
    });                                                                     \
    result;                                                                 \
})

#define mergeCharSets(sets...) (NSCharacterSet *) ({        /** Variadic (...) so that the sets arg can contain commas. */\
    static NSMutableCharacterSet *result = nil;             \
    static dispatch_once_t onceToken;                       \
    dispatch_once(&onceToken, ^{                            \
        result = [[NSMutableCharacterSet alloc] init];      \
        for (NSCharacterSet *set in (sets)) {               \
            [result formUnionWithCharacterSet: set];        \
        }                                                   \
        result = [result copy];                             /** Make immutable || IIRC the docs mention that immutable characterSets are more efficient.*/\
    });                                                     \
    result;                                                 \
})                                                          \

#pragma mark - ASCII character sets

/// The standard NSCharacterSet methods such as +[decimalDigitCharacterSet] contain all sorts of crazy unicode characters beyond ASCII

+ (NSCharacterSet *)lowercaseASCIILetterCharacterSet {
    return makeCharSet(@"abcdefghijklm"
                        "nopqrstuvwxyz");
}
+ (NSCharacterSet *)uppercaseASCIILetterCharacterSet {
    return makeCharSet(@"ABCDEFGHIJKLM"
                        "NOPQRSTUVWXYZ");
}
+ (NSCharacterSet *)asciiDigitCharacterSet {
    return makeCharSet(@"0123456789");
}
+ (NSCharacterSet *)asciiLetterCharacterSet {
    return mergeCharSets(@[
        self.lowercaseASCIILetterCharacterSet,
        self.uppercaseASCIILetterCharacterSet
    ]);
}

#pragma mark - C/OBJC identifiers

/// Source: C23 standard - 6.4.2 Identifiers (https://www.open-std.org/jtc1/sc22/wg14/www/docs/n3088.pdf)
///     The C standard says that C compilers can also allow unicode `XID_Start` and `XID_Continue` characters to be used in identifiers.
///         This allows for using stuff like umlauts, or Chinese characters in identifiers. (Both of which do seem to be supported in clang)
///         However, we're not supporting that here, to keep things simple. [Feb 2025]
///
///         Aside from the basic requirements encoded by these character sets, the standard also reserves some identifiers:
///             - They cannot be equal to a reserved keyword like `if`
///             - They shouldn't start with `__` or `_` followed by an uppercase letter. (E.g. `_Nullable`) – those identifiers are reserved for internal use. (If I understood correctly. I'm a bit confused.)

+ (NSCharacterSet *)cIdentifierCharacterSet_Start {
    /// Allowed characters for the first character of a c identifier
    return mergeCharSets(@[
        self.asciiLetterCharacterSet,
        [NSCharacterSet characterSetWithCharactersInString:@"_"]
        /// First character of a c identifier cannot be a digit (0-9)
    ]);
}

+ (NSCharacterSet *)cIdentifierCharacterSet_Continue {
    /// Allowed characters for the non-first characters of a c identifier
    NSCharacterSet *result = mergeCharSets(@[
        self.asciiLetterCharacterSet,
        [NSCharacterSet characterSetWithCharactersInString:@"_"],
        self.asciiDigitCharacterSet
    ]);
    
    assert([result isSupersetOfSet:NSCharacterSet.cIdentifierCharacterSet_Start] &&
           "cIdentifierCharacterSet: _Continue is not a superset of _Start. We might be assuming that during parsing.");
    
    return result;
}

@end
