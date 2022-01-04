//
// --------------------------------------------------------------------------
// AppState.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AppState : NSObject

AppState *appState(void);

// This is set to YES by SparkleUpdaterDelegate, if the app was launched through Sparkle updater.
//  So if this is YES then this is the first launch after an update.
@property BOOL updaterDidRelaunchApplication;

@end

NS_ASSUME_NONNULL_END
