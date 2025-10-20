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
#import "Constants.h"

NSString *_MFLocalizedString(NSString *key) {
    
    /// `annotation-discussion`
    ///     We override the default swizzling-based annotation (See `enableAutomaticAnnotation`) and then do the annotation manually, (using `temporarilyDisableAutomaticAnnotation:` and `stringByAnnotatingString:` – see below) because the annotation needs to happen *after* the `english_string` fallback logic.
    ///     Simplification ideas:
    ///         - We cannot move all this logic into `_MFLocalizedString` because localized strings loaded by IB don't call `_MFLocalizedString` (only our source-code does) – we need swizzling for that.
    ///         - We could   move all this logic into the swizzle of `localizedStringForKey:value:table:` – that would simplify things.
    ///             Reasons why we don't do this: I'm a bit uncomfortable swizzling in production code? Is it slow? Does our implementation have bugs? Also it would make the recent refactor to MFLocalizedString kinda pointless. (We could've just stuck with NSLocalizedString). So maybe sunk-cost-fallacy. [Oct 2025]
    
    [LocalizedStringAnnotation temporarilyDisableAutomaticAnnotation: YES]; /// Turn off the swizzling-based annotation see `annotation-discussion` above.
    NSString *result = [NSBundle.mainBundle localizedStringForKey: key value: @"" table: nil];
    [LocalizedStringAnnotation temporarilyDisableAutomaticAnnotation: NO];
        
    /// Fall back to english string if localization is not available. (By default, it falls back to the string-key)
    ///     Improvement idea: Fall-back to closest available language instead of falling back to English:
    ///         - IIRC, in our Python scripts are doing this using Babel, but this feels good enough – just keep the UI as usable as possible when translations are missing – English is likely understood by most people [Oct 2025]
    ///         - See research / usage elsehwere of private `[NSLocale preferredLocale]` – it and related APIs might be used to implement this.
    ///     Also see
    ///         - `LocalizedStringAnnotation.m` where we customized `NSLocalizedString` through swizzling (now that we have `MFLocalizedString` swizzling is probably not be necessary anymore) [Oct 2025]
    ///         - Other solutions to the fallback problem: https://stackoverflow.com/questions/3263859/localizing-strings-in-ios-default-fallback-language
    ///     Note on IB:
    ///         IB-defined strings already seem to fall back to English – It's only NSLocalizedString that falls back to the string-key. [Oct 2025]
    ///             If we did want to apply custom fallback logic for IB we could use the swizzle of `localizedStringForKey:value:table:`. [Oct 2025]
    
    {
        auto english_string = ^NSString *(void) {
            NSBundle *englishBundle = [NSBundle bundleWithPath: [NSBundle.mainBundle pathForResource: @"en" ofType: @"lproj"] ?: @""]; /** Could cache this [Oct 2025] */
            assert(englishBundle);
            NSString *result = [englishBundle localizedStringForKey: key value: @"" table: nil];
            result = result ?: @"<missing string>"; /** Just to be safe – don't think this can ever happen [Oct 2025] */
            return result;
        };
        
        if ([result rangeOfString: kMFThanksPattern options: NSRegularExpressionSearch].location != NSNotFound)
            goto endof_fallbacks; /// Don't fall back for `thanks.[...]` strings cause when localizers leave those blank, we simply wanna omit those from the randomizer (See AboutTabController.swift) [Oct 2025]
        
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
                NSDictionary *english_config    = [english_string() valueForKey: @"config"]; /// `NSLocalizableString._developmentLanguageString` seems to exist – could use that perhaps. [Oct 2025]
                for (NSString *kp in emptystring_keypaths) {
                    [new_config setObject: [english_config objectForCoolKeyPath: kp] forCoolKeyPath: kp];
                }
                [result setValue: new_config forKey: @"config"];
            }
        }
    }
    endof_fallbacks: {}
    
    /// Manually annotate the string – see `annotation-discussion` above
    if ([NSProcessInfo.processInfo.arguments containsObject: @"-MF_ANNOTATE_LOCALIZED_STRINGS"]) {
        result = [LocalizedStringAnnotation stringByAnnotatingString: result withKey: key table: nil];
    }
    
    /// Return
    return result;
}
