//
// --------------------------------------------------------------------------
// ConfigFileInterface_Helper.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Config : NSObject

#pragma mark - For both

/// Singleton
+ (Config *)shared;

/// Main storage
@property (strong, nonatomic) NSMutableDictionary *config;

/// Load
+ (void)load_Manual;

/// Load from file
- (void)loadConfigFromFile;

/// Read and write
NSObject *config(NSString *keyPath);
void setConfig(NSString *keyPath, NSObject *value);
void commitConfig(void);

/// Repair
typedef enum {
    kMFConfigProblemNone = 0,
    kMFConfigProblemIncompleteAppOverride = 1
} MFConfigProblem;

- (void)repairConfigWithProblem:(MFConfigProblem)problem info:(id _Nullable)info;
- (void)cleanConfig;

#pragma mark - For Helper

/// Overrides
- (BOOL)loadOverridesForAppUnderMousePointer;
@property (strong, nonatomic, readonly) NSMutableDictionary *configWithAppOverridesApplied;

/// React
+ (void)handleConfigFileChangedMessage;


@end

NS_ASSUME_NONNULL_END
