//
//  KVPair.m
//  CustomImplForLocalizationScreenshotTest
//
//  Created by Noah Nübling on 12.07.24.
//

#import "KVPair.h"

@implementation KVPair
@synthesize key, value;

+ (KVPair *)pairWithKey:(id)key value:(id)value {
    KVPair *pair = [[KVPair alloc] init];
    pair.key = key;
    pair.value = value;
    return pair;
}

- (NSString *)description {
    
    NSString *keyDescription = [key description];
    NSString *valueDescription = [value description];
    
    BOOL valueDescriptionIsMultiline = [valueDescription containsString:@"\n"];
    
    if (valueDescriptionIsMultiline) {
        return [NSString stringWithFormat:@"%@:\n%@", keyDescription, valueDescription];
    } else {
        return [NSString stringWithFormat:@"%@: %@", keyDescription, valueDescription];
    }
    
}

@end
