//
// --------------------------------------------------------------------------
// AppExclusions.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// Per-app 'kill switches'.
///     Lets the user turn off individual Mac Mouse Fix features for specific apps (e.g. smooth scrolling in games, which want the scroll events macOS normally sends.)
///     The apps are stored in the config under `AppExclusions`. See `AppsTabController.swift` in the mainApp for the editing UI.

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, MFAppExclusionFeatures) {
    kMFAppExclusionFeaturesNone                 = 0,
    kMFAppExclusionFeaturesSmoothScroll         = 1 << 0, /// Smoothness and speed. The app gets the original scroll events (with Reverse Direction still applied). See Scroll.m
    kMFAppExclusionFeaturesReverseDirection     = 1 << 1,
    kMFAppExclusionFeaturesScrollModifiers      = 1 << 2, /// Keyboard modifier scroll actions (zoom, horizontal scroll, etc.)
    kMFAppExclusionFeaturesButtons              = 1 << 3,
};

@interface AppExclusions : NSObject

/// Re-read the exclusions from the config. Call this whenever the config changes.
+ (void)reload;

/// The features that the user turned off for the app under the mouse pointer.
///     Notes:
///     - This looks up the window under the pointer, which isn't free – so don't call it on every event. Call it once per scroll swipe / button press.
///     - Returns `kMFAppExclusionFeaturesNone` immediately, if the user hasn't excluded any apps.
+ (MFAppExclusionFeatures)excludedFeaturesForAppUnderPointerWithEvent:(CGEventRef _Nullable)event;

@end

NS_ASSUME_NONNULL_END
