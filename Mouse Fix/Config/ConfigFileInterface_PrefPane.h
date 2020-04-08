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
typedef enum {
    kMFConfigProblemNone = 0,
    kMFConfigProblemIncompleteAppOverride = 1
} ConfigProblem;
@property (class,retain) NSMutableDictionary *config;
+ (NSURL *)configURL;
+ (void)writeConfigToFileAndNotifyHelper;
+ (void)loadConfigFromFile;
+ (void)repairConfigWithProblem:(ConfigProblem)problem info:(id _Nullable)info;
+ (void)cleanConfig;
@end

NS_ASSUME_NONNULL_END
