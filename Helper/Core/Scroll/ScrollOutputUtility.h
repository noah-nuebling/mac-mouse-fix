//
// --------------------------------------------------------------------------
// ScrollOutputUtility.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@interface ScrollOutputUtility : NSObject

/// Volume — CoreAudio scalar, smooth continuous control
+ (float)getSystemVolume;
+ (void)setSystemVolume:(float)volume;

/// Brightness — built-in via DisplayServices, external via DDC/IOAVService
/// Routes to the display under the mouse pointer automatically
+ (float)getDisplayBrightness;
+ (void)setDisplayBrightness:(float)brightness;   /// absolute (used by scroll)
+ (void)adjustBrightnessByDelta:(float)delta;     /// relative (used by drag)
+ (void)adjustBrightnessByDelta:(float)delta forDisplayID:(CGDirectDisplayID)displayID; /// relative with explicit display
+ (CGDirectDisplayID)displayUnderMouse;

@end

NS_ASSUME_NONNULL_END
