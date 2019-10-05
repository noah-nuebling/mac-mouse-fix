//
// --------------------------------------------------------------------------
// Utility_HelperApp.m
// Created for: Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by: Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "Utility_HelperApp.h"

@implementation Utility_HelperApp

+ (NSString *)binaryRepresentation:(int)value {
    long nibbleCount = sizeof(value) * 2;
    NSMutableString *bitString = [NSMutableString stringWithCapacity:nibbleCount * 5];
    
    for (long index = 4 * nibbleCount - 1; index >= 0; index--)
    {
        [bitString appendFormat:@"%i", value & (1 << index) ? 1 : 0];
        if (index % 4 == 0)
        {
            [bitString appendString:@" "];
        }
    }
    return bitString;
}

+ (NSBundle *)helperBundle {
    return [NSBundle bundleForClass:Utility_HelperApp.class];
}
+ (NSBundle *)prefPaneBundle {
    
    NSURL *prefPaneBundleURL = [self helperBundle].bundleURL;
    for (int i = 0; i < 4; i++) {
        prefPaneBundleURL = [prefPaneBundleURL URLByDeletingLastPathComponent];
    }
    NSBundle *prefPaneBundle = [NSBundle bundleWithURL:prefPaneBundleURL];
    
    NSLog(@"prefPaneBundleURL: %@", prefPaneBundleURL);
    NSLog(@"prefPaneBundle: %@", prefPaneBundle);
    
    return prefPaneBundle;
}

@end
