//
// --------------------------------------------------------------------------
// LogitechButtonDiverter.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Makes the side buttons of newer Logitech mice (MX Anywhere 3/3S, MX Master 3/3S, M650, Lift, ...) behave like normal
/// mouse buttons – including the "held down" state that Click and Drag / Click and Scroll need.
/// See the discussion at the top of LogitechButtonDiverter.m.
@interface LogitechButtonDiverter : NSObject

/// Start watching for Logitech HID++ interfaces and divert the configured buttons on every mouse that shows up.
/// Call once from the Helper, after DeviceManager is set up.
+ (void)load_Manual;

/// Hand every diverted button back to the mouse firmware. Call right before the Helper exits.
/// Safe to call from any thread, including the termination signal handler. Doesn't wait for the mouse to answer.
+ (void)restoreNativeBehavior;

@end

NS_ASSUME_NONNULL_END
