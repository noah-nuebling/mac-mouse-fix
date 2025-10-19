//
// --------------------------------------------------------------------------
// Localization.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2025
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "Localization.h"
#import "MFLoop.h"
#import "SharedMacros.h"
#import "UndeprecateSimpleUnboxing.h"
#import "NSDictionary+Additions.h"
#import "LocalizedStringAnnotation.h"

static bool _annotationEnabled = false;
void MFLocalizedString_EnableStringAnnotation(void) { _annotationEnabled = true; } /// Previously we used to call` [LocalizedStringAnnotation swizzleNSBundle]` instead of this. [Oct 2025]

NSString *_MFLocalizedString(NSString *key) {

    NSString *result = [NSBundle.mainBundle localizedStringForKey: key value: @"" table: nil];
        
    /// Fall back to english string if localization is not available. (By default, it falls back to the string-key)
    ///     Improvement idea: Fall-back to closest available language instead of falling back to English:
    ///         - IIRC, in our Python scripts are doing this using Babel, but this feels good enough – just keep the UI as usable as possible when translations are missing – English is likely understood by most people [Oct 2025]
    ///         - See research / usage elsehwere of private `[NSLocale preferredLocale]` – it and related APIs might be used to implement this.
    ///     Also see
    ///         - `LocalizedStringAnnotation.m` where we customized `NSLocalizedString` through swizzling (now that we have `MFLocalizedString` swizzling is probably not be necessary anymore) [Oct 2025]
    ///         - Other solutions to the fallback problem: https://stackoverflow.com/questions/3263859/localizing-strings-in-ios-default-fallback-language
    ///     Note on IB:
    ///         IB-defined strings already seem to fall back to English – It's only NSLocalizedString that falls back to the string-key. [Oct 2025]
    
    {
        auto english_string = ^NSString *(void) {
            NSBundle *englishBundle = [NSBundle bundleWithPath: [NSBundle.mainBundle pathForResource: @"en" ofType: @"lproj"] ?: @""]; /** Could cache this [Oct 2025] */
            assert(englishBundle);
            NSString *result = [englishBundle localizedStringForKey: key value: @"" table: nil];
            result = result ?: @"<missing string>"; /** Just to be safe – don't think this can ever happen [Oct 2025] */
            return result;
        };
        
        if ([result isEqual: key]) {
            result = english_string();
        }
        else if ([result isKindOfClass: NSClassFromString(@"__NSLocalizedString")]) {
            
            /// Do separate fallback for each pluralization [Oct 2025]
           
            NSDictionary *config = [result valueForKey: @"config"];
            auto emptystring_keypaths = [NSMutableArray new];
            [config iterateCoolKeyPaths: ^(NSString * _Nonnull keyPath, id  _Nonnull object) {
                if ([object isEqual: @""]) [emptystring_keypaths addObject: keyPath];
            }];
            if (emptystring_keypaths.count) {  /// Replace emptystrings with the english string at the same keypath – this should cause fallback to English for each of the pluralizations - we currently only have one set of pluralizable strings - the `capture-toast` strings - and it works there [Oct 2025]
                NSMutableDictionary *new_config = [config mutableCopy];
                NSDictionary *english_config    = [english_string() valueForKey: @"config"];
                for (NSString *kp in emptystring_keypaths) {
                    [new_config setObject: [english_config objectForCoolKeyPath: kp] forCoolKeyPath: kp];
                }
                [result setValue: new_config forKey: @"config"];
            }
        }
    }
    
    /// Add secret message
    if (_annotationEnabled)
    {
        NSString *annotatedString = [LocalizedStringAnnotation annotateString: result withKey: key table: nil];
        
        if ([result isKindOfClass:NSClassFromString(@"__NSLocalizedString")])   result = nsLocalizedStringBySwappingOutUnderlyingString(result, annotatedString); /// Handle pluralized strings
        else                                                                    result = annotatedString;
        
        DDLogDebug(@"LocalizedStringAnnotation: Annotated: \"%@\": \"%@\"", key, result);
            
     }

    
    return result;
}
