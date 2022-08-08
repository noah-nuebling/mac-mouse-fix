//
// --------------------------------------------------------------------------
// TouchSimulator.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import "MFHIDEventImports.h"

NS_ASSUME_NONNULL_BEGIN

@interface TouchSimulator : NSObject

typedef enum {
    kMFDockSwipeTypeHorizontal = 1, /// Swipe between pages
    kMFDockSwipeTypeVertical = 2, /// Mission Control & App Expose
    kMFDockSwipeTypePinch = 3, /// Show Desktop & Launchpad
} MFDockSwipeType;

+ (void)postNavigationSwipeEventWithDirection:(IOHIDSwipeMask)dir;

+ (void)postSmartZoomEvent;
+ (void)postRotationEventWithRotation:(double)rotation phase:(IOHIDEventPhaseBits)phase;
+ (void)postMagnificationEventWithMagnification:(double)magnification phase:(IOHIDEventPhaseBits)phase;
+ (void)postDockSwipeEventWithDelta:(double)d type:(MFDockSwipeType)type phase:(IOHIDEventPhaseBits)phase;


@end

NS_ASSUME_NONNULL_END
