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

#if IS_HELPER
    #import "GlobalEventTapThread.h"
#endif

NS_ASSUME_NONNULL_BEGIN

/// RunLoop
static inline CFRunLoopRef configRunLoop(void) CF_RETURNS_NOT_RETAINED {
    #if IS_HELPER
        return GlobalEventTapThread.runLoop;
    #elif IS_MAIN_APP
        return CFRunLoopGetMain();
    #endif
}

@interface Config : NSObject


/// Singleton
+ (Config *)shared;

/// Main storage
@property (strong, nonatomic) NSMutableDictionary *config; /// [Aug 2025] This could just be an ivar instead of a property  (Except if we wanna support KVO)

/// Load
+ (void)load_Manual;

/// Load from file
- (void)loadConfigFromFile;

/// Read and write
NSObject * _Nullable config(NSString *keyPath);
void setConfig(NSString *keyPath, NSObject *value);
void removeFromConfig(NSString *keyPath);
void commitConfig(void);

/// React
+ (void)loadFileAndUpdateStates;

/// Repair
#if IS_MAIN_APP
    //- (void) repairIncompleteAppOverrideForBundleID: (NSString *)bundleID
    //                               relevantKeyPaths: (NSArray <NSString *> *)keyPathsToDefaultValues;
    - (void) cleanConfig;
#endif

/// Overrides
#if IS_HELPER
    - (BOOL)loadOverridesForAppUnderMousePointerWithEvent:(CGEventRef)event;
    @property (strong, nonatomic, readonly) NSMutableDictionary *configWithAppOverridesApplied; /// [Aug 2025] This could just be an ivar
#endif

@end

NS_ASSUME_NONNULL_END
