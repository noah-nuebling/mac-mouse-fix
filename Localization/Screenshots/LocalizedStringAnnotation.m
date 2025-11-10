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
#import "MFLoop.h"

mfdata_cls_m(StringAnnotation)

@implementation StringAnnotation (SwiftCompat)
    - (NSString *)  key { return self->key; }
    - (NSString *)  table { return self->table; }
    - (NSRange)     rangeInString { return self->rangeInString; }
@end

@implementation LocalizedStringAnnotation


+ (NSArray<StringAnnotation *> *) extractAnnotationsFromString: (NSString *)string {
    
    auto secretMessages = string.secretMessages; /// Extract this for optimization, so we don't call it over and over [Nov 2025]
    
    auto result = [NSMutableArray new];
    
    auto stack = [NSMutableArray new];
    
    loopc(i, secretMessages.count) {
        
        NSError *err = nil;
        auto regex = [NSRegularExpression regularExpressionWithPattern: @"<mfkey:(.+):(.*)>" options: 0 error: &err];
        if (err) assert(false);
        
        auto startSequenceMatches = [regex matchesInString: secretMessages[i].secretMessage options: 0 range: NSMakeRange(0, secretMessages[i].secretMessage.length)];
        assert(startSequenceMatches.count <= 1);
        
        if (startSequenceMatches.count) { /// startSequence
            assert(startSequenceMatches[0].numberOfRanges == 3);
            
            [stack addObject: @{
                @"key":               [secretMessages[i].secretMessage substringWithRange: [startSequenceMatches[0] rangeAtIndex: 1]],
                @"table":             [secretMessages[i].secretMessage substringWithRange: [startSequenceMatches[0] rangeAtIndex: 2]],
                @"startSequenceEnd":  @(NSMaxRange(secretMessages[i].rangeInString))
            }];
            
        }
        else { /// endSequence
            assert([secretMessages[i].secretMessage isEqual: @"</mfkey>"]);
            assert(stack.count);
            
            NSDictionary *head = [stack lastObject];
            [stack removeLastObject];
            
            auto r0 = [head[@"startSequenceEnd"] unsignedLongValue];
            auto r1 = secretMessages[i].rangeInString.location;
            
            auto x = mfdata_new(StringAnnotation,
                .key = head[@"key"],
                .table = head[@"table"],
                .rangeInString = NSMakeRange(r0,  r1 - r0)
            );
            DDLogDebug(@"rangeInString: %@", NSStringFromRange(x->rangeInString));
            
            [result addObject: x];
        }
    }
    
    return result;
}

+ (NSString *) stringByAnnotatingString: (NSString *)string withKey: (NSString *)key table: (NSString *)table { /// To be used by `MFLocalizedString` [Oct 2025]
    
    NSString *result = string;
    
    NSString *annotatedString = ({
        /// Add secret message
        /// Notes:
        ///     - We keep the format string short to stay under the 512 character XCUITest limit. (Update: We removed the limit by getting the raw AXUIElement)
        ///     - Pattern recognition would break if key or table name contain `:`
        ///     - I've seen our' current secretMessage encoding break the UI text a little bit:
        ///         - Markdown __underscore emphasis__ is not parsed anymore - (we had the same issue with chinese - the `__` syntax  requires spaces to work while `**` does not. ZeroWidthSpace is not enough. We should just switch over to using `**`)
        ///         - Markdown parsing normally removes anything over a double linebreak. But not when the secretMessage is in the blank space.
        ///         - Pluralized localizedStrings break from our annotations it seems. Update: Fixed.
        
        NSString *prefix = [stringf(@"<mfkey:%@:%@>", key, (table ?: @"")) encodedAsSecretMessage];
        NSString *suffix = [stringf(@"</mfkey>") encodedAsSecretMessage];
        stringf(@"%@%@%@", prefix, result, suffix);
    });
    
    
    if ([result isKindOfClass: NSClassFromString(@"__NSLocalizedString")]) { /// Handle pluralized strings
    
        ///   Swap out the underlying string of the `__NSLocalizedString` instance
        ///     Notes:
        ///     - `__NSLocalizedString` Is a private subclass for NSMutableString, which I've seen used for pluralized localized strings. When you use it as a format string, magic things happen and you get the correctly pluralized version.
        ///     - If a pluralized string is retrieved from the bundle multiple times, it always seems to return the same, mutable `__NSLocalizedString` instance. (That's why we copy the instance here before modifying it.)
        
        result = [result copy];
        
        [result setValue: annotatedString forKey: @"original"];
        
        NSMutableDictionary *config = [[result valueForKeyPath: @"config"] mutableCopy];
        config[@"NSStringLocalizedFormatKey"] = annotatedString;
        [result setValue: config forKey: @"config"];
        
    } else {
        result = annotatedString;
    }
    
    DDLogDebug(@"LocalizedStringAnnotation: Annotated: \"%@\": \"%@\" (table: %@)", key, result, table);
    
    return result;
}

static __thread bool _annotationIsTemporarilyDisabled = false; /// `__thread` in case this is ever called from outside the mainThread. (Which I don't think happens) [Oct 2025]
+ (void) temporarilyDisableAutomaticAnnotation: (bool)disable { /// To be used by `MFLocalizedString` [Oct 2025]
    _annotationIsTemporarilyDisabled = disable;
}

+ (void)enableAutomaticAnnotation {
        
    /// Swizzle
    swizzleMethod([NSBundle class], @selector(localizedStringForKey:value:table:), InterceptorFactory_Begin(NSString *, (NSString *key, NSString *value, NSString *table))
        
        /// Note:
        ///     Used to also swizzle `localizedAttributedStringForKey:value:table:`, but our code never uses that method  – only available in macOS 12.0+
        
        NSString *result = OGImpl(key, value, table);
        
        if (_annotationIsTemporarilyDisabled) return result;
        if (![m_self isEqual: NSBundle.mainBundle]) return result; /// The system loads tons of strings from other bundles such as `AppKit`
        
        result = [self stringByAnnotatingString: result withKey: key table: table];
        
        return result;
        
    InterceptorFactory_End());
}

@end


