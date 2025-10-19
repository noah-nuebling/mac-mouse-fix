//
// --------------------------------------------------------------------------
// Localization.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2025
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "Localization.h"


NSString *_MFLocalizedString(NSString *key) {

    NSString *result = [NSBundle.mainBundle localizedStringForKey: key value: @"" table: nil];
        
    /// Fall back to english string if localization is not available. (By default, it falls back to the string-key)
    ///     Improvement idea: Fall-back to closest available language instead of falling back to English:
    ///         - IIRC, in our Python scripts are doing this using Babel, but this feels good enough – just keep the UI as usable as possible when translations are missing [Oct 2025]
    ///         - See research / usage elsehwere of private `NSLocale.preferredLocale` – it and related APIs might be used to implement this.
    ///     Also see
    ///         - `LocalizedStringAnnotation.m` where we customized `NSLocalizedString` through swizzling (now that we have `MFLocalizedString` swizzling is probably not be necessary anymore) [Oct 2025]
    ///         - Other solutions to this problem: https://stackoverflow.com/questions/3263859/localizing-strings-in-ios-default-fallback-language
    ///     Note on IB:
    ///         IB-defined strings already seem to fall back to English – It's only NSLocalizedString that falls back to the string-key. [Oct 2025]
    if (
        [result isEqual: key] ||
        ([result containsString: @"%#@"] && ([result class] != NSClassFromString(@"__NSLocalizedString"))) /// Detects non-localized pluralizable strings. [Oct 2025]
    ) {
        NSBundle *englishBundle = [NSBundle bundleWithPath: [NSBundle.mainBundle pathForResource: @"en" ofType: @"lproj"] ?: @""]; /// Could cache this [Oct 2025]
        assert(englishBundle);
        result = [englishBundle localizedStringForKey: key value: @"" table: nil];
        result = result ?: @"<missing string>"; /// Just to be safe – don't think this can ever happen [Oct 2025]
    }
    
    return result;
}
