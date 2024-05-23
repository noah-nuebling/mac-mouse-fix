//
// --------------------------------------------------------------------------
// CoolSUVersionComparator.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "CoolSUComparator.h"

@implementation CoolSUComparator {
    SUStandardVersionComparator *defaultComparator;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        defaultComparator = [SUStandardVersionComparator defaultComparator];
    }
    return self;
}

- (NSComparisonResult)compareVersion:(nonnull NSString *)versionA withBuildNumber:(NSObject *)buildNumberAObj 
                           toVersion:(nonnull NSString *)versionB withBuildNumber:(NSObject *)buildNumberBObj {
    
    /// This method compares versions, and uses build numbers to disambiguate, if the two versions are considered the same (e.g. `3.0.0` and `3.0.0 Beta 2` are considered the same.)
    
    /// Compare version numbers
    
    NSComparisonResult versionComparison = [self compareVersion:versionA toVersion:versionB];
    if (versionComparison == NSOrderedAscending) return NSOrderedAscending;
    else if (versionComparison == NSOrderedDescending) return NSOrderedDescending;
        
    /// If version numbers are the same (e.g. in the case `3.0.0` vs `3.0.0 Beta 2`), then compare build numbers instead.
    
    assert([buildNumberAObj respondsToSelector:@selector(integerValue)]);
    assert([buildNumberBObj respondsToSelector:@selector(integerValue)]);
    
    NSInteger buildNumberA = [(id)buildNumberAObj integerValue];
    NSInteger buildNumberB = [(id)buildNumberBObj integerValue];
    
    return [@(buildNumberA) compare:@(buildNumberB)];
    
}

- (NSComparisonResult)compareVersion:(nonnull NSString *)versionA toVersion:(nonnull NSString *)versionB {
    
    /// Custom app-version comparator 
    ///     for the `bestValidUpdateInAppcast:forUpdater:` method in our `SparkleUpdaterController`.
    ///
    /// Why are we implementing a custom comparator?
    /// - At the time of writing, (using Sparkle 1.26.0), the `SUStandardVersionComparater` considers `2.0.0abcd` greater than `2.0.0`. And wrongly considers `2.0.0 Beta 1` greater than `2.0.0`.
    /// - It correctly consideres`2.0.0 Beta 1` greater than. `2.0.0 Alpha 1` - it seems that the strings following the `2.0.0` are compared alphabetically?
    ///
    /// What does this comparator do?
    /// - In contrast to `SUStandardVersionComparater`, this comparator only looks at the numbers and periods of the version name, everything else is ignored. Therefore version `2.0.0` and `2.0.0 Beta 1` will be considered as the same version. You can then further differentiate between `2.0.0` and `2.0.0 Beta 1` by using the build number.
    ///
    /// ---
    
    /// Cut off everything after the numbers-and-periods section of the version number
    
    NSCharacterSet *badChars = [[NSCharacterSet characterSetWithCharactersInString:@"1234567890."] invertedSet];
    NSRange aRange = [versionA rangeOfCharacterFromSet:badChars];
    NSRange bRange = [versionB rangeOfCharacterFromSet:badChars];
    
    if (aRange.location != NSNotFound) {
        versionA = [versionA substringToIndex:aRange.location];
    }
    if (bRange.location != NSNotFound) {
        versionB = [versionB substringToIndex:bRange.location];
    }
    
    /// Use default comparator
    NSComparisonResult result = [defaultComparator compareVersion:versionA toVersion:versionB];
    
    /// Return
    return result;
}

@end
