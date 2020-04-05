//
// --------------------------------------------------------------------------
// Utility_HelperApp.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
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

// TODO: Consider returning a mutable dict to avoid constantly using `- mutableCopy`. Maybe even alter `dst` in place and return nothing (And rename to `applyOverridesFrom:to:`).
/// Copy all leaves (elements which aren't dictionaries) from `src` to `dst`. Return the result. (`dst` itself isn't altered)
/// Recursively search for leaves in `src`. For each srcLeaf found, create / replace a leaf in `dst` at a keyPath identical to the keyPath of srcLeaf and with the value of srcLeaf.
/// Has and exact copy in Utility_PrefPane
+ (NSDictionary *)dictionaryWithOverridesAppliedFrom:(NSDictionary *)src to: (NSDictionary *)dst {
    NSMutableDictionary *dstMutable = [dst mutableCopy];
    for (NSString *key in src) {
        NSObject *dstVal = [dst valueForKey:key];
        NSObject *srcVal = [src valueForKey:key];
        if ([srcVal isKindOfClass:[NSDictionary class]] || [srcVal isKindOfClass:[NSMutableDictionary class]]) { // Not sure if checking for mutable dict and dict is necessary
            // Nested dictionary found. Recursing.
            NSDictionary *recursionResult = [self dictionaryWithOverridesAppliedFrom:(NSDictionary *)srcVal to:(NSDictionary *)dstVal];
            [dstMutable setValue:recursionResult forKey:key];
        } else {
            // Leaf found
            [dstMutable setValue:srcVal forKey:key];
        }
    }
    return dstMutable;
}

@end
