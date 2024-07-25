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

@implementation LocalizedStringAnnotation

@end

@implementation NSBundle (MFAnnotation)

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
            NSString *secretMessage = stringf(@"mf-secret-localization-key:%@", key);
            result = [result stringByAppendingStringAsSecretMessage:secretMessage];
            
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
            NSString *secretMessage = stringf(@"mf-secret-localization-key:%@", key);
            result = [result attributedStringByAppendingStringAsSecretMessage:secretMessage];
            
            /// Log
            DDLogDebug(@"LocalizedStringAnnotation: Annotated: \"%@\": \"%@\" (%@)", key, result, table);
        }
        
        /// Return
        return result;
    }));
    
    
}

@end


