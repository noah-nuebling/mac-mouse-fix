//
// --------------------------------------------------------------------------
// LocalizedStringAnnotation.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "LocalizedStringAnnotation.h"
#import "AnnotationUtility.h"
#import "NSString+Steganography.h"
#import "SharedUtility.h"
#import "NSAttributedString+Additions.h"
#import "NSString+Additions.h"
#import "Logging.h"

@implementation LocalizedStringAnnotation

@end

@implementation NSBundle (MFAnnotation)

+ (NSString *)annotationStringWithKey:(NSString *)key table:(NSString *_Nullable)table {
    
    /// Notes:
    ///     - We keep the format string short to stay under the 512 character XCUITest limit.
    ///     - Pattern recognition would break if key or table name contain `:`
    ///     - If table is nill the formatted string would include literal "(null)", so we map to empty string.
    ///     - I've seen our' current secretMessage encoding break the UI text a little bit:
    ///         - Markdown __underscore emphasis__ is not parsed anymore - (we had the same issue with chinese - the `__` syntax  requires spaces to work while `**` does not. ZeroWidthSpace is not enough. We should just switch over to using `**`)
    ///         - Markdown parsing normally removes anything over a double linebreak. But not when the secretMessage is in the blank space.
    ///         - Pluralized localizedStrings break from our annotations it seems. They render as `%#@someidentifier@` after being formatted. Perhaps if we put the annotation to the string's end for strings starting with %#@, that could fix it?
    
    NSString *annotation = stringf(@"mfkey:%@:%@:", key, table ?: @"");
    NSString *secretMessage = [annotation encodedAsSecretMessage];
    return secretMessage;
    
}

+ (void)setUnderlyingString:(NSString *)underlyingString toLocalizedString:(id)localizedString {
    [localizedString setValue:underlyingString forKey:@"original"];
    NSMutableDictionary *config = [[localizedString valueForKeyPath:@"config"] mutableCopy];
    config[@"NSStringLocalizedFormatKey"] = underlyingString;
    [localizedString setValue:config forKey:@"config"];
}

void doBreak(NSString *context) {
    
}

+ (void)load {
    
    /// Check
    ///     Only swizzle when flag is set
    if (![NSProcessInfo.processInfo.arguments containsObject:@"-MF_ANNOTATE_LOCALIZED_STRINGS"]) {
        return;
    }
        
    /// Swizzle
    swizzleMethodOnClassAndSubclasses([self class], @{ @"framework": @"AppKit" }, @selector(localizedStringForKey:value:table:), MakeInterceptorFactory(NSString *, (NSString *key, NSString *value, NSString *table), {
        
        /// Call og
        NSString *result = OGImpl(key, value, table);
        
        BOOL isOurBundle = [m_self isEqual:NSBundle.mainBundle]; /// The system loads tons of strings from other bundles such as `AppKit`
        if (isOurBundle) {
            
            /// Add secret message
            NSString *annotation = [self annotationStringWithKey:key table:table];
            NSString *annotatedString = [annotation stringByAppendingString:result];
            
            
            if ([result isKindOfClass:NSClassFromString(@"__NSLocalizedString")]) {
                /// Add secret message to pluralized strings (`__NSLocalizedString` class)
                [self setUnderlyingString:annotatedString toLocalizedString:result];
            } else {
                /// Default case
                result = annotatedString; /// We prepend the annotation because XCUITest will seemingly cut of the string at 512 chars. By putting the annotation first it should be before the cutoff.
            }
            
            /// Log
            DDLogDebug(@"LocalizedStringAnnotation: Annotated: \"%@\": \"%@\" (table: %@)", key, result, table);
        }
        
        /// Return
        return result;
    }));
    
    swizzleMethodOnClassAndSubclasses([self class], @{ @"framework": @"AppKit" }, @selector(localizedAttributedStringForKey:value:table:), MakeInterceptorFactory(NSAttributedString *, (NSString *key, NSString *value, NSString *table), {
        
        /// Call og
        NSAttributedString *result = OGImpl(key, value, table);
        
        BOOL isOurBundle = [m_self isEqual:NSBundle.mainBundle];
        if (isOurBundle) {
        
            /// Add secret message
            NSString *annotation = [self annotationStringWithKey:key table:table];
            NSAttributedString *annotatedString = [[annotation attributed] attributedStringByAppending:result];
            
            if ([result isKindOfClass:NSClassFromString(@"__NSLocalizedString")]) {
                assert(false); /// Don't know how to handle this.
                result = annotatedString;
            } else {
                /// Default case
                result = annotatedString;
            }
            
            /// Log
            DDLogDebug(@"LocalizedStringAnnotation: Annotated: \"%@\": \"%@\" (table: %@)", key, result, table);
        }
        
        /// Return
        return result;
    }));
    
    

}

@end


