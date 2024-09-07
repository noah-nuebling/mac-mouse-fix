//
// --------------------------------------------------------------------------
// LocalizationUtility.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2023
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "LocalizationUtility.h"

@implementation LocalizationUtility

+ (double)informationDensityOfCurrentLanguage {
    NSString *languageCode = [NSLocale.currentLocale objectForKey:NSLocaleLanguageCode];
    return [self informationDensityOfLanguage:languageCode];
}

+ (double)informationDensityOfLanguage:(NSString *)languageCode {
    
    /// Notes:
    /// - This returns the average amount of information per character in a given language relative to English.
    /// - At the time of writing, this is used to determine how long toast notifications should stay visible. The time is supposed to be proportional to the information content of the message, which we calculate using the infromationDensity.
    /// - To find the information density constants, I just compared a few UI texts based on how many characters they have vs the same message in English.
    ///     Update: After adding Arabic, Catalan, Czech, etc, we used a more systematic, LLM-based approach to determine the information density.
    ///           This approach is documented in `InformationDensity.md`
    /// - These languageCodes and their order is taken from `Mouse Fix.xcodeproj/project.pbxproj` and should probably be kept in sync.
    /// - Reflection: Most densities hover around 1.0, and so encoding them here doesn't really make a difference for the user experience. The outliers are: Korean, Japanese, Chinese (as of 07.09.2024)
    
    NSDictionary *map = @{
        @"en": @1.0,   // English
        @"de": @0.9,   // German                || Pre LLM value: 0.8
        @"zh": @2.8,   // Chinese (Simplifed)   || Pre LLM value: 3.5 (Why was this so much higher than post-LLM?)
        @"ko": @1.6,   // Korean                || Pre LLM value: 1.75
        @"vi": @1.0,   // Vietnamese            || Pre LLM value: 0.75
        @"ar": @1.1,   // Arabic
        @"ca": @0.9,   // Catalan
        @"cs": @1.0,   // Czech
        @"nl": @1.0,   // Dutch
        @"fr": @0.8,   // French
        @"el": @0.9,   // Greek
        @"he": @1.2,   // Hebrew
        @"hu": @0.9,   // Hungarian
        @"it": @0.9,   // Italian
        @"ja": @1.8,   // Japanese
        @"pl": @0.9,   // Polish
        @"pt": @0.9,   // Portuguese (Brazilian)
        @"ro": @0.9,   // Romanian
        @"ru": @0.9,   // Russian
        @"es": @0.9,   // Spanish
        @"sv": @1.0,   // Swedish
        @"tr": @0.9,   // Turkish
        @"uk": @0.9,   // Ukrainian
        @"th": @1.2,   // Thai
        @"id": @0.9,   // Indonesian
        @"hi": @0.9,   // Hindi
    };
    
    NSNumber *resultNS = map[languageCode];
    assert(resultNS != nil);
    double result = resultNS == nil ? 1.0 : resultNS.doubleValue; /// Default to 1.0
    
    return result;
}

@end
