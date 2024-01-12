//
// --------------------------------------------------------------------------
// Config.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

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
- (void)loadConfigFromFileAndRepair;

/// Read and write
NSObject * _Nullable config(NSString *keyPath);
void setConfig(NSString *keyPath, NSObject *value);
void removeFromConfig(NSString *keyPath);
void commitConfig(void);

/// Repair
typedef enum {
    kMFConfigRepairReasonLoad = 0,
    kMFConfigRepairReasonIncompleteAppOverride = 1
} MFConfigRepairReason;

- (void)repairConfigWithReason:(MFConfigRepairReason)reason info:(id _Nullable)info;
- (void)cleanConfig;

#pragma mark - For Helper

/// Overrides
- (BOOL)loadOverridesForAppUnderMousePointerWithEvent:(CGEventRef)event;
@property (strong, nonatomic, readonly) NSMutableDictionary *configWithAppOverridesApplied;

/// React
+ (void)loadFileAndUpdateStates;


@end

NS_ASSUME_NONNULL_END
