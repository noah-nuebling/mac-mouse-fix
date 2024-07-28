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
    ///     - Would breaks if key or table name contain `:`
    ///     - If table is nill the formatted string would include literal "(null)", so we map to empty string.
    
    NSString *annotation = stringf(@"mfkey:%@:%@:", key, table ?: @"");
    NSString *secretMessage = [annotation encodedAsSecretMessage];
    return secretMessage;
    
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
        
        BOOL isOurBundle = [m_self isEqual:NSBundle.mainBundle];
        if (isOurBundle) {
            
            /// Add secret message
            NSString *annotation = [self annotationStringWithKey:key table:table];
            result = [annotation stringByAppendingString:result]; /// We prepend the annotation because XCUITest will seemingly cut of the string at 512 chars. By putting the annotation first it should be before the cutoff.
            
            /// Log
            DDLogDebug(@"LocalizedStringAnnotation: Annotated: \"%@\": \"%@\" (%@)", key, result, table);
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
            NSString *annotation = [self annotationStringWithKey:key table:table ?: @"Localizable"];
            result = [[annotation attributed] attributedStringByAppending:result];
            
            /// Log
            DDLogDebug(@"LocalizedStringAnnotation: Annotated: \"%@\": \"%@\" (%@)", key, result, table);
        }
        
        /// Return
        return result;
    }));
    
    

}

@end


