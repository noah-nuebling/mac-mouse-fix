//
// --------------------------------------------------------------------------
// BundleServices.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "BundleServices.h"
#import "Constants.h"

@implementation BundleServices

NSBundle *_helperBundle;
+ (NSBundle *)helperBundle {
    return _helperBundle;
}
NSBundle *_mainAppBundle;
+ (NSBundle *)mainAppBundle {
    return _mainAppBundle;
}

+ (void)initialize {
    NSBundle *thisBundle = [NSBundle bundleForClass:self.class];
    
    if ([thisBundle.bundleIdentifier isEqualToString:kMFBundleIDApp]) {
        NSString *helperPath = [thisBundle.bundleURL URLByAppendingPathComponent:kMFRelativeHelperAppPath].path;
        _mainAppBundle = thisBundle;
        _helperBundle = [NSBundle bundleWithPath:helperPath];
        
    } else if ([thisBundle.bundleIdentifier isEqualToString:kMFBundleIDHelper]) {
        NSString *mainAppPath = [thisBundle.bundleURL URLByAppendingPathComponent:kMFRelativeMainAppPathFromHelper].path;
        _mainAppBundle = [NSBundle bundleWithPath:mainAppPath];
        _helperBundle = thisBundle;
    }
}
@end
