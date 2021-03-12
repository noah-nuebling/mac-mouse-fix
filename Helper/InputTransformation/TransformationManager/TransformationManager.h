//
// --------------------------------------------------------------------------
// TransformationManager.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import "ButtonInputReceiver.h"

NS_ASSUME_NONNULL_BEGIN

@interface TransformationManager : NSObject
+ (void)updateWithRemapsTableFromConfig;
+ (NSDictionary *)remaps;
+ (void)enableAddMode;
+ (void)DisableAddMode;
@end

NS_ASSUME_NONNULL_END
