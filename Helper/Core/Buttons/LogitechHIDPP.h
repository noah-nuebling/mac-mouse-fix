//
// --------------------------------------------------------------------------
// LogitechHIDPP.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <IOKit/hid/IOHIDManager.h>

NS_ASSUME_NONNULL_BEGIN

/// Diverts the side buttons of Logitech HID++ 2.0 mice (feature 0x1B04 REPROG_CONTROLS_V4) and re-posts them as
/// ordinary otherMouseDown/Up CGEvents at the time of the physical press.
///     Without this, many Logitech mice (MX Anywhere 3, M650, M750, Lift, ...) only send buttons 4/5 on release,
///     because the firmware waits to see whether the button is chorded with the scroll wheel for horizontal scrolling.
///     That breaks hold, click-and-drag and click-and-scroll for those buttons.
@interface LogitechHIDPP : NSObject

+ (void)load_Manual;

/// Undiverts all buttons without waiting for replies. Call before the helper exits, otherwise the buttons stay
/// diverted (and dead) until the mouse reconnects.
+ (void)restoreDevices;

/// Returns the HID++ device that a CGEvent posted by this module came from, or NULL if the event wasn't posted by us.
+ (IOHIDDeviceRef _Nullable)sendingDeviceForEvent:(CGEventRef)event;

@end

NS_ASSUME_NONNULL_END
