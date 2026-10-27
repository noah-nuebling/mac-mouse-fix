//
// --------------------------------------------------------------------------
// Stubs.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// Stubs for RemapSwizzlerTests. `dictionaryWithOverridesAppliedFrom:to:` is a copy of the one in SharedUtility.m.

#import "Remap.h"
#import "SharedUtility.h"
@implementation Remap
+ (BOOL)addModeIsEnabled { return NO; }
@end
@implementation SharedUtility
+ (id)deepMutableCopyOf:(id)object { return [object mutableCopy]; } /// Only used by the addMode swizzler, which these tests don't cover
+ (NSDictionary *)dictionaryWithOverridesAppliedFrom:(NSDictionary *)src to: (NSDictionary *)dst {
    NSMutableDictionary *dstMutable = [dst mutableCopy];
    if (dstMutable == nil) dstMutable = [NSMutableDictionary dictionary];
    for (id<NSCopying> key in src) {
        NSObject *dstVal = dst[key];
        NSObject *srcVal = src[key];
        if ([srcVal isKindOfClass: [NSDictionary class]]) {
            dstMutable[key] = [self dictionaryWithOverridesAppliedFrom:(NSDictionary *)srcVal to:(NSDictionary *)dstVal];
        } else {
            dstMutable[key] = srcVal;
        }
    }
    return dstMutable;
}
@end
