#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CocoaLumberjack_CocoaLumberjack_SWIFTPM_MODULE_BUNDLER_FINDER : NSObject
@end

@implementation CocoaLumberjack_CocoaLumberjack_SWIFTPM_MODULE_BUNDLER_FINDER
@end

NSBundle* CocoaLumberjack_CocoaLumberjack_SWIFTPM_MODULE_BUNDLE() {
    NSString *bundleName = @"CocoaLumberjack_CocoaLumberjack";

    NSArray<NSURL*> *candidates = @[
        NSBundle.mainBundle.resourceURL,
        [NSBundle bundleForClass:[CocoaLumberjack_CocoaLumberjack_SWIFTPM_MODULE_BUNDLER_FINDER class]].resourceURL,
        NSBundle.mainBundle.bundleURL
    ];

    for (NSURL* candidate in candidates) {
        NSURL *bundlePath = [candidate URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.bundle", bundleName]];

        NSBundle *bundle = [NSBundle bundleWithURL:bundlePath];
        if (bundle != nil) {
            return bundle;
        }
    }

    @throw [[NSException alloc] initWithName:@"SwiftPMResourcesAccessor" reason:[NSString stringWithFormat:@"unable to find bundle named %@", bundleName] userInfo:nil];
}

NS_ASSUME_NONNULL_END