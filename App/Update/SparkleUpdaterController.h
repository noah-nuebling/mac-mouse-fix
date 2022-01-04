//
// --------------------------------------------------------------------------
// SparkleUpdateDelegate.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import <Sparkle/Sparkle.h>

NS_ASSUME_NONNULL_BEGIN

@interface SparkleUpdaterController : NSObject <SUUpdaterDelegate>

+ (void)enablePrereleaseChannel:(BOOL)pre;

@end

NS_ASSUME_NONNULL_END
