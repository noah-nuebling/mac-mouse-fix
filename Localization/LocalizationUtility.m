//
// --------------------------------------------------------------------------
// LocalizationUtility.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2023
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

#import "LocalizationUtility.h"

@implementation LocalizationUtility

+ (double)informationDensityOfCurrentLanguage {
    NSString *languageCode = [NSLocale.currentLocale objectForKey:NSLocaleLanguageCode];
    return [self informationDensityOfLanguage:languageCode];
}

+ (double)informationDensityOfLanguage:(NSString *)languageCode {
    
    /// At the time of writing, this is used to determine how long toast notifications should stay visible. The time is supposed to be proportional to the information content of the message which is equal to the number of characters in the message times the information density of the language that the message is written in.
    /// To determine the information density I just compare a few UI text based on how many characters they have vs the same message in English.
    
    NSDictionary *map = @{
        @"de": @0.8, /// German
        @"en": @1.0, /// English
        @"ko": @1.75, /// Korean
        @"zh": @3.5, /// Chinese
    };
    
    NSNumber *resultNS = map[languageCode];
    double result = resultNS == nil ? 1.0 : resultNS.doubleValue; /// Default to 1.0
    
    return result;
}

@end
