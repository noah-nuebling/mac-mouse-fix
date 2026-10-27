//
// --------------------------------------------------------------------------
// AppExclusions.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// Notes:
/// - Apps are identified by their bundleID. Many games (e.g. Minecraft) are plain executables without a bundleID, so for those we use the path of the executable instead. (See `runningApplicationDescription()` in HelperUtility.m)
///     The mainApp uses the same logic when the user adds an app – keep the two in sync. (See `AppsTabController.entry(for:)`)
/// - We use the app under the mouse pointer rather than the frontmost app, since that's the app which receives the scroll and click events.
///     If we can't determine the app under the pointer, we fall back to the frontmost app.
/// - Everything here runs on `IOThread` (that's where the config and the eventTaps live), so we don't need any locking.

#import "AppExclusions.h"
#import <AppKit/AppKit.h>
#import "Config.h"
#import "HelperUtility.h"
#import "Logging.h"

#define kMFConfigKeyAppExclusions @"AppExclusions"

@implementation AppExclusions

/// Maps app identifier -> `MFAppExclusionFeatures`
static NSDictionary<NSString *, NSNumber *> *_excludedFeaturesByApp = nil;

+ (void)reload {

    assertRunLoop(IOThread.runLoop);

    NSMutableDictionary *result = [NSMutableDictionary dictionary];

    NSArray *entries = (id)config(kMFConfigKeyAppExclusions); /// Optional key – nil if the user never excluded any apps.
    if ([entries isKindOfClass:[NSArray class]]) {
        for (NSDictionary *entry in entries) {

            if (![entry isKindOfClass:[NSDictionary class]]) { assert(false); continue; }

            NSString *identifier = entry[@"identifier"];
            if (![identifier isKindOfClass:[NSString class]] || identifier.length == 0) { assert(false); continue; }

            MFAppExclusionFeatures features = kMFAppExclusionFeaturesNone;
            if ([entry[@"disableSmoothScrolling"] boolValue])   features |= kMFAppExclusionFeaturesSmoothScroll;
            if ([entry[@"disableReverseDirection"] boolValue])  features |= kMFAppExclusionFeaturesReverseDirection;
            if ([entry[@"disableScrollModifiers"] boolValue])   features |= kMFAppExclusionFeaturesScrollModifiers;
            if ([entry[@"disableButtons"] boolValue])           features |= kMFAppExclusionFeaturesButtons;

            if (features != kMFAppExclusionFeaturesNone) {
                result[identifier] = @(features);
            }
        }
    }

    _excludedFeaturesByApp = result.count > 0 ? result : nil;

    DDLogDebug("AppExclusions: Reloaded: %@", _excludedFeaturesByApp);
}

+ (MFAppExclusionFeatures)excludedFeaturesForAppUnderPointerWithEvent:(CGEventRef)event {

    assertRunLoop(IOThread.runLoop);

    /// Fast path
    if (_excludedFeaturesByApp == nil) return kMFAppExclusionFeaturesNone;

    /// Get app
    NSRunningApplication *app = [HelperUtility appUnderMousePointerWithEvent:event];
    if (app == nil) app = NSWorkspace.sharedWorkspace.frontmostApplication;
    if (app == nil) return kMFAppExclusionFeaturesNone;

    /// Look up features
    NSString *identifier = app.bundleIdentifier ?: app.executableURL.path;
    if (identifier == nil) return kMFAppExclusionFeaturesNone;

    MFAppExclusionFeatures result = [_excludedFeaturesByApp[identifier] unsignedIntegerValue];

    DDLogDebug("AppExclusions: App under pointer: %@, excluded features: %lu", identifier, (unsigned long)result);

    return result;
}

@end
