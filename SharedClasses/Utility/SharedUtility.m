//
// --------------------------------------------------------------------------
// SharedUtility.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "SharedUtility.h"

@implementation SharedUtility

+ (void)printInfoOnCaller {
    NSLog(@"PRINTING INFO ON CALLING FUNCTION: %@", [[NSThread callStackSymbols] objectAtIndex:2]);
}
+ (void)printStackTrace {
    NSLog(@"PRINTING STACK TRACE: %@", [NSThread callStackSymbols]);
}

// TODO: Consider returning a mutable dict to avoid constantly using `- mutableCopy`. Maybe even alter `dst` in place and return nothing (And rename to `applyOverridesFrom:to:`).
/// Copy all leaves (elements which aren't dictionaries) from `src` to `dst`. Return the result. (`dst` itself isn't altered)
/// Recursively search for leaves in `src`. For each srcLeaf found, create / replace a leaf in `dst` at a keyPath identical to the keyPath of srcLeaf and with the value of srcLeaf.
+ (NSDictionary *)dictionaryWithOverridesAppliedFrom:(NSDictionary *)src to: (NSDictionary *)dst {
    NSMutableDictionary *dstMutable = [dst mutableCopy];
    if (dstMutable == nil) {
        dstMutable = [NSMutableDictionary dictionary];
    }
    for (id<NSCopying> key in src) {
        NSObject *dstVal = dst[key];
        NSObject *srcVal = src[key];
        if ([srcVal isKindOfClass:[NSDictionary class]] || [srcVal isKindOfClass:[NSMutableDictionary class]]) { // Not sure if checking for mutable dict AND dict is necessary
            // Nested dictionary found. Recursing.
            NSDictionary *recursionResult = [self dictionaryWithOverridesAppliedFrom:(NSDictionary *)srcVal to:(NSDictionary *)dstVal];
            dstMutable[key] = recursionResult;
        } else {
            // Leaf found
            dstMutable[key] = srcVal;
        }
    }
    return dstMutable;
}

@end
