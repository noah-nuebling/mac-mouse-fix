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

+ (NSString *)annotationStringWithKey:(NSString *)key table:(NSString *_Nullable)table {
    
    /// Notes:
    ///     - We keep the format string short to stay under the 512 character XCUITest limit. (Update: We removed the limit by getting the raw AXUIElement)
    ///     - Pattern recognition would break if key or table name contain `:`
    ///     - If table is nill the formatted string would include literal "(null)", so we map to empty string.
    ///     - I've seen our' current secretMessage encoding break the UI text a little bit:
    ///         - Markdown __underscore emphasis__ is not parsed anymore - (we had the same issue with chinese - the `__` syntax  requires spaces to work while `**` does not. ZeroWidthSpace is not enough. We should just switch over to using `**`)
    ///         - Markdown parsing normally removes anything over a double linebreak. But not when the secretMessage is in the blank space.
    ///         - Pluralized localizedStrings break from our annotations it seems. Update: Fixed.
    
    NSString *annotation = stringf(@"mfkey:%@:%@:", key, table ?: @"");
    NSString *secretMessage = [annotation encodedAsSecretMessage];
    return secretMessage;
    
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

void doBreak(NSString *context) {
    
}

+ (void)swizzleNSBundle {
        
    /// Swizzle
    swizzleMethodOnClassAndSubclasses([NSBundle class], @{ @"framework": @"AppKit" }, @selector(localizedStringForKey:value:table:), MakeInterceptorFactory(NSString *, (NSString *key, NSString *value, NSString *table), {
        
        /// Call og
        NSString *result = OGImpl(key, value, table);
        
        BOOL isOurBundle = [m_self isEqual:NSBundle.mainBundle]; /// The system loads tons of strings from other bundles such as `AppKit`
        if (isOurBundle) {
            
            /// Add secret message
            NSString *annotation = [self annotationStringWithKey:key table:table];
            NSString *annotatedString = [annotation stringByAppendingString:result]; /// We prepend the annotation because XCUITest will seemingly cut of the string at 512 chars. By putting the annotation first it should be before the cutoff. (Update: Removed the 512 character cutoff.)
            
            /// Handle pluralized strings
            if ([result isKindOfClass:NSClassFromString(@"__NSLocalizedString")]) {
                result = nsLocalizedStringBySwappingOutUnderlyingString(result, annotatedString);
            } else {
                result = annotatedString;
            }
            
            /// TEST
            doBreak(result);
            
            /// Log
            DDLogDebug(@"LocalizedStringAnnotation: Annotated: \"%@\": \"%@\" (table: %@)", key, result, table);
        }
        
        /// Return
        return result;
    }));
    
    swizzleMethodOnClassAndSubclasses([NSBundle class], @{ @"framework": @"AppKit" }, @selector(localizedAttributedStringForKey:value:table:), MakeInterceptorFactory(NSAttributedString *, (NSString *key, NSString *value, NSString *table), {
        
        /// Call og
        NSAttributedString *result = OGImpl(key, value, table);
        
        BOOL isOurBundle = [m_self isEqual:NSBundle.mainBundle];
        if (isOurBundle) {
            
            /// Add secret message
            NSString *annotation = [self annotationStringWithKey:key table:table];
            result = [[annotation attributed] attributedStringByAppending:result];
            
            /// Handle pluralized strings
            if ([result isKindOfClass:NSClassFromString(@"__NSLocalizedString")]) {
                assert(false); /// Don't know how to handle this.
            }
            
            /// Log
            DDLogDebug(@"LocalizedStringAnnotation: Annotated: \"%@\": \"%@\" (table: %@)", key, result, table);
        }
        
        /// Return
        return result;
    }));
    
    

}

@end


