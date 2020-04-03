//
// --------------------------------------------------------------------------
// ConfigFileInterface_PrefPane.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ConfigFileInterface_PrefPane : NSObject
@property (class,retain) NSMutableDictionary *config;
+ (void)writeConfigToFile;
+ (void)loadConfigFromFile;
@end

NS_ASSUME_NONNULL_END
