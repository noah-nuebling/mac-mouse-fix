//
// --------------------------------------------------------------------------
// RemapScope.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "RemapScope.h"
#import "Constants.h"

@implementation RemapScope

+ (nullable NSString *)appForRow:(NSDictionary *)row {
    id app = row[kMFRemapsKeyApp];
    if (![app isKindOfClass:NSString.class] || ((NSString *)app).length == 0) return nil;
    return app;
}

+ (BOOL)row:(NSDictionary *)row isInScope:(nullable NSString *)app {
    NSString *rowApp = [self appForRow:row];
    if (app == nil) return rowApp == nil;
    return [app isEqualToString:rowApp];
}

+ (NSArray *)rowsForScope:(nullable NSString *)app inRemaps:(nullable NSArray *)remaps {
    NSArray *all = remaps ?: @[];
    NSIndexSet *indexes = [all indexesOfObjectsPassingTest:^BOOL(NSDictionary *row, NSUInteger idx, BOOL *stop) {
        return [RemapScope row:row isInScope:app];
    }];
    return [all objectsAtIndexes:indexes];
}

+ (NSArray *)remapsReplacingScope:(nullable NSString *)app withRows:(NSArray *)rows inRemaps:(nullable NSArray *)remaps {
    NSArray *all = remaps ?: @[];
    NSIndexSet *otherScopes = [all indexesOfObjectsPassingTest:^BOOL(NSDictionary *row, NSUInteger idx, BOOL *stop) {
        return ![RemapScope row:row isInScope:app];
    }];
    return [[all objectsAtIndexes:otherScopes] arrayByAddingObjectsFromArray:rows];
}

@end
