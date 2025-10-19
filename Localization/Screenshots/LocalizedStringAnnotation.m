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

+ (NSString *) annotateString: (NSString *)string withKey: (NSString *)key table: (NSString *_Nullable)table {
    
    /// Notes:
    ///     - We keep the format string short to stay under the 512 character XCUITest limit. (Update: We removed the limit by getting the raw AXUIElement)
    ///     - Pattern recognition would break if key or table name contain `:`
    ///     - I've seen our' current secretMessage encoding break the UI text a little bit:
    ///         - Markdown __underscore emphasis__ is not parsed anymore - (we had the same issue with chinese - the `__` syntax  requires spaces to work while `**` does not. ZeroWidthSpace is not enough. We should just switch over to using `**`)
    ///         - Markdown parsing normally removes anything over a double linebreak. But not when the secretMessage is in the blank space.
    ///         - Pluralized localizedStrings break from our annotations it seems. Update: Fixed.
    
    NSString *prefix = [stringf(@"<mfkey:%@:%@>", key, (table ?: @"")) encodedAsSecretMessage];
    NSString *suffix = [stringf(@"</mfkey>") encodedAsSecretMessage];
    return stringf(@"%@%@%@", prefix, string, suffix);
}

+ (NSAttributedString *) annotateAttributedString: (NSAttributedString *)string withKey: (NSString *)key table: (NSString *_Nullable)table {
    
    /// Keep in-sync with `annotateString:withKey:table:`
    
    NSString *prefix = [stringf(@"<mfkey:%@:%@>", key, (table ?: @"")) encodedAsSecretMessage];
    NSString *suffix = [stringf(@"</mfkey>") encodedAsSecretMessage];
    return astringf(@"%@%@%@", [prefix attributed], string, [suffix attributed]);
}

id nsLocalizedStringBySwappingOutUnderlyingString(id nsLocalizedString, NSString *underlyingString) {
    
    ///   Swaps out the underlying string of an `__NSLocalizedString` instance
    ///     Notes:
    ///     - `__NSLocalizedString` Is a private subclass for NSMutableString, which I've seen used for pluralized localized strings. When you use it as a format string, magic things happen and you get the correctly pluralized version.
    ///     - If a pluralized string is retrieved from the bundle multiple times, it always seems to return the same, mutable `__NSLocalizedString` instance. (That's why we copy the instance here before modifying it.)
    
    nsLocalizedString = [nsLocalizedString copy];
    
    [nsLocalizedString setValue:underlyingString forKey:@"original"];
    NSMutableDictionary *config = [[nsLocalizedString valueForKeyPath:@"config"] mutableCopy];
    config[@"NSStringLocalizedFormatKey"] = underlyingString;
    [nsLocalizedString setValue:config forKey:@"config"];
    
    return nsLocalizedString;
}

+ (void)swizzleNSBundle {
        
    /// Swizzle
    swizzleMethodOnClassAndSubclasses([NSBundle class], @{ @"framework": @"AppKit" }, @selector(localizedStringForKey:value:table:), InterceptorFactory_Begin(NSString *, (NSString *key, NSString *value, NSString *table))
        
        /// Call og
        NSString *result = OGImpl(key, value, table);
        
        BOOL isOurBundle = [m_self isEqual:NSBundle.mainBundle]; /// The system loads tons of strings from other bundles such as `AppKit`
        if (isOurBundle) {
            
            /// Add secret message
            NSString *annotatedString = [self annotateString: result withKey: key table: table];
            
            /// Handle pluralized strings
            if ([result isKindOfClass:NSClassFromString(@"__NSLocalizedString")]) {
                result = nsLocalizedStringBySwappingOutUnderlyingString(result, annotatedString);
            } else {
                result = annotatedString;
            }

            
            /// Log
            DDLogDebug(@"LocalizedStringAnnotation: Annotated: \"%@\": \"%@\" (table: %@)", key, result, table);
        }
        
        /// Return
        return result;
    InterceptorFactory_End());
    
    swizzleMethodOnClassAndSubclasses([NSBundle class], @{ @"framework": @"AppKit" }, @selector(localizedAttributedStringForKey:value:table:), InterceptorFactory_Begin(NSAttributedString *, (NSString *key, NSString *value, NSString *table))
        
        /// [Sep 2025] Don't think we need this.
        ///     Our code never uses `localizedAttributedStringForKey:value:table:` – only available in macOS 12.0+
        
        /// Call og
        NSAttributedString *result = OGImpl(key, value, table);
        
        BOOL isOurBundle = [m_self isEqual:NSBundle.mainBundle];
        if (isOurBundle) {
            
            /// Add secret message
            result = [self annotateAttributedString: result withKey: key table: table];
            
            /// Handle pluralized strings
            if ([result isKindOfClass:NSClassFromString(@"__NSLocalizedString")]) {
                assert(false); /// Don't know how to handle this.
            }
            
            /// Log
            DDLogDebug(@"LocalizedStringAnnotation: Annotated: \"%@\": \"%@\" (table: %@)", key, result, table);
        }
        
        /// Return
        return result;
    InterceptorFactory_End());
    
    

}

@end


