//
// --------------------------------------------------------------------------
// AccessibilityCheck.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "AccessibilityCheck.h"

#import <AppKit/AppKit.h>
#import "MFMessagePort.h"
#import "DeviceManager.h"
#import "Config.h"
#import "Scroll.h"
#import "ButtonInputReceiver.h"
#import "Constants.h"
#import "ModifiedDrag.h"
#import "Modifiers.h"
#import "SharedUtility.h"
#import "HelperServices.h"
#import "PointerFreeze.h"
#import "Mac_Mouse_Fix_Helper-Swift.h"
#import "LocalizedStringAnnotation.h"

#import "SharedUtility.h"

#import <signal.h>

@implementation AccessibilityCheck

/// Handle Unix signals

static void signal_handler(int signal_number, siginfo_t *signal_info, void *context) {
    
    if (signal_number == SIGTERM) {
        
        /// Deconfigure
        [DeviceManager deconfigureDevices];
        
        /// Terminate app
        ///     I think `NSApplicationMain(argc, argv)` (found in main.m) sets up its own SIGTERM handler which we're overriding here. So we need to manually terminate the app.
        ///     If this leads to further problems around termination, consider simply sending a `willTerminate` message from the Main App before terminating the Helper.
        [NSApp terminate:nil];
    } else {
        NSLog(@"SIGTERM handler caught weird signal: %d", signal_number); /// Can't use CocoaLumberjack here since it might not be set up, yet (I think)
    }
}

/// Load

+ (void)load {
    
    /// This is the main entry point of the app
    
    ///
    /// Check command line args.
    
    NSMutableArray<NSString *> *args = NSProcessInfo.processInfo.arguments.mutableCopy;
    [args removeObjectAtIndex:0]; /// First argument is just the executable path or sth, we can ignore that.
    
    if (args.count > 0) {
        
        /// Log
        NSLog(@"Accessibility Check - Started helper with command line args: %@", args); /// Can't use CocoaLumberjack here since it's not set up, yet
        
        ///
        /// Process args
        if ([args containsObject:@"forceUpdateAccessibilitySettings"]) {
            
            ///
            /// Force update accessibility settings, then exit immediately
            ///
            
            /// This is a workaround
            ///     for an Apple bug in Ventura (maybe previous versions too? Edit: Monterey, too. I think I even saw it on 10.13 and 10.14) where the accessibility toggle for MMF Helper won't work after an update.
            ///     This bug occured between 2.2.0 and 2.2.1 when I moved the app from a Development Signature to a proper Developer Program Signature.
            ///     Bug also maybe occurs for 3.0.0 Beta 4. Not sure why. Maybe because I changed the bundleID between those versions. Or maybe it's a different bug that just looks similar.
            /// See
            /// - https://github.com/noah-nuebling/mac-mouse-fix/issues/415
            /// - https://github.com/noah-nuebling/mac-mouse-fix/issues/412
            /// - https://github.com/noah-nuebling/mac-mouse-fix/discussions/101 (Accessibility Guide)
            
            /// Why do this in such a weird way?
            /// - We need to launch a new helper instance instead of just using the normal helper instance because `AXIsProcessTrustedWithOptions` will only add the helper to System Settings __once__ after launch. Subsequent calls don't do anything.`AXIsProcessTrustedWithOptions` is also the __only__ way to check if we already have accessibility access. And we need to check if we already have access __before__ deciding to reset the access, because we don't want to reset access if it has already been granted. So therefore we need to do the intial check and the forced system settings update in two different instances of the helper. You would think normally relaunching the helper would solve this but...
            /// - We can't just relaunch the helper normally through launchd because launchd permits at most 1 start per 10 seconds. So if the helper's just been enabled and there's no accessibility access you have to wait 10 seconds until the helper can be restarted through launchd.
            /// -> So we start a new instance of the helper independently of launchd and let it update the accessibility settings and then quit immediately.
            
            /// Log
            NSLog(@"Accessibility Check - Force update system settings"); /// Can't use CocoaLumberjack here since it's not set up, yet
            
            /// Remove existing helper from System Settings
            /// - If an old helper exists, the user won't be able to enable the new helper!
            /// - This will make the system unresponsive if there is still an old helper running that's already tapped into the button event stream!
            ///     -> TODO: Disable & kill any helpers before doing this so we don't cause freezes.
            /// - This doesn't work under macOS 10.13 and 10.14 because `tccutil` doesn't take bundleID argument there (bundleID arg was introduced in 10.15 - Src: https://eclecticlight.co/2020/01/28/a-guide-to-catalinas-privacy-protection-4-tccutil/). I don't see a solution. Just make the Accessibility Guide good.
            [SharedUtility launchCLT:[NSURL fileURLWithPath:kMFTccutilPath] withArguments:@[@"reset", @"Accessibility", kMFBundleIDHelper] error:nil];
            
            /// Add self to System Settings
            [self checkAccessibilityAndUpdateSystemSettings];
            
            /// Close helper
            exit(0);
        }
    }
    
    ///
    /// No command line args - start normally
    
    ///
    /// Testing & Debug
    ///


//    [GlobalDefaults applyDoubleClickThreshold];
//    PointerConfig.customTableBasedAccelCurve;
//    CFMachPortRef testTap = [ModificationUtility createEventTapWithLocation:kCGSessionEventTap mask:CGEventMaskBit(kCGEventMouseMoved) | CGEventMaskBit(kCGEventLeftMouseDragged) | CGEventMaskBit(kCGEventScrollWheel) | CGEventMaskBit(kCGEventLeftMouseDown) /* | CGEventMaskBit()*/ option:kCGEventTapOptionDefault placement:kCGTailAppendEventTap callback: testCallback];
//    CGEventTapEnable(testTap, true);
    
    
    /// Setup termination handler
    
    struct sigaction action = {
        .sa_flags = SA_SIGINFO,
        .sa_mask = 0,
        .sa_sigaction = signal_handler,
    };
    int rt = sigaction(SIGTERM, &action, NULL);
    if (rt < 0) {
        NSLog(@"Accessibility Check - Error setting up sigterm handler: %d", rt); /// Can't use CocoaLumberjack here, since it's not set up, yet
    }
    
    /// Set up CocoaLumberjack
    [Logging setUpDDLog];
    DDLogInfo(@"Accessibility Check - Mac Mosue Fix begins logging excessively");
    
    
    /// Validate asserts working properly
    /// Notes:
    /// - Doing this here so CocoaLumberjack is set up already. Not sure if smart decision
    /// - It seems the NDEBUG flag is necessary to disable asserts. We hadn't had the NDEBUG flag set in 3.0.2 which contributed to a crashing issue issue where an assert was false (See: https://github.com/noah-nuebling/mac-mouse-fix/issues/988) I'm not sure when we removed the NDEBUG flag.
    /// - I added the NDEBUG flag back to the Clang Preprocessor Macros now. I also added the NDEBUG flag to the Swift Active Compilation Conditions. Not sure what effect that has, but I think the NDEBUG flag is standard for Swift, as well so it should work fine (Not totally sure though)
    
#if NDEBUG
    DDLogInfo(@"Accessibility Check - Running a Non-Debug build. Asserts are disabled.");
    assert(false);
#endif
    
#if DEBUG
    DDLogInfo(@"Accessibility Check - Running a Debug build. Asserts are enabled.");
#endif
    
    ///
    /// __Pre-check init__
    ///
    
    [MFMessagePort load_Manual];
    
    ///
    /// Do the accessibility check
    ///
    Boolean isTrusted = [self checkAccessibilityAndUpdateSystemSettings];
    
    if (!isTrusted) {
        
        DDLogInfo(@"Accessibility Check - Accessibility Access Disabled");
        
        /// Workaround for macOS bug
        ///     If there's still and old version of the helper in System Settings, the user won't be able to trust the new helper. So we remove the old helper from System Settings and add the new one again.

        [HelperServices launchHelperInstanceWithMessage:@"forceUpdateAccessibilitySettings"];

        /// Notify main app
        NSDictionary *payload = @{
            @"bundleVersion": @(Locator.bundleVersion),
            @"mainAppURL": Locator.mainAppBundle.bundleURL
        };
        [MFMessagePort sendMessage:@"helperEnabledWithNoAccessibility" withPayload:payload waitForReply:NO];
        
        /// Check accessibility every 0.5s
        ///     Not storing the timer in a variable because we don't have to invalidate / release it since the helper will restart anyways
        [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:YES block:^(NSTimer * _Nonnull timer) {
            
            BOOL hasAccessibility = [self checkAccessibilityAndUpdateSystemSettings];
            
            if (hasAccessibility) {
                /// Restart helper
                ///     Use a 0.5s delay so the accessibilitySheet can first animate out before the mainApp's UI activates. Without the delay there is slight visual jank.
                ///     Edit: We refactored the accessibility stuff in 144296c225dbdd9f49598823fb73ad503b2b2e2d and now the delay is not necessary anymore. Maybe has to do with us removing the automatic removing of the accessibilitySheet on a timer
                [HelperServices restartHelperWithDelay:0.0];
            }
        }];
            
    } else {
        
        /// Accessibility is enabled -> Start normally!
        
        ///
        /// Log
        ///
        
        DDLogInfo(@"Accessibility Check - Helper started with accessibility permissions at: URL %@", Locator.currentExecutableURL);
        
        ///
        /// __Post-check init__
        ///

        /// Annotate localized strings
        ///     The swizzle should happen before the system loads any of our localized nib files, or localizedStrings are loaded from the NSBundle in another way. Otherwise we miss some strings in the localizationScreenshots.
        if ([NSProcessInfo.processInfo.arguments containsObject:@"-MF_ANNOTATE_LOCALIZED_STRINGS"]) {
            [LocalizedStringAnnotation swizzleNSBundle];
        }
        
        /// Using `load_Manual` instead of normal load, because creating an eventTap crashes the program, if we don't have accessibilty access (I think - I don't really remember)
        /// TODO: Look into using `+ initialize` instead of `+ load`. The way we have things set up there are like a bajillion entry points to the program (one for every `+ load` function) which is kinda sucky. Might be better to have just one entry point to the program and then start everything that needs to be started with `+ start` functions and let `+ initialize` do the rest
        [ButtonInputReceiver load_Manual];
        [DeviceManager load_Manual];
        [Scroll load_Manual];
        
        /// NOTE: v Moved these 2 down, to prevent crashes introduced by moving SwitchMaster away from ReactiveSwift to simple callbacks.
//        [Config load_Manual];
//        [ModifiedDrag load_Manual];
        [Modifiers load_Manual];
        [ModifiedDrag load_Manual];
        [Config load_Manual];
        
        [SwitchMaster.shared load_Manual];
        
        [ScreenDrawer.shared load_Manual];
        [PointerFreeze load_Manual];
        
        [MenuBarItem load_Manual];
        
        /// Send 'started' message to mainApp
        /// Notes:
        /// - We could improve responsivity of the enableToggle in mainApp by sending the message before doing all the initialization. But only slightly.
        /// - Why are we doing the license init after this? Little weird
        
        NSDictionary *payload = @{
            @"bundleVersion": @(Locator.bundleVersion),
            @"mainAppURL": Locator.mainAppBundle.bundleURL
        };
        [MFMessagePort sendMessage:@"helperEnabled" withPayload:payload waitForReply:NO];
        
        ///
        /// License init
        ///
        /// Note:
        /// - It would make sense to do this before the accessibility check, but calling this before the Post-check init crashes because of some stupid stuff. The stupid stuff is I I think the [Trial load_Manual] calls some other stuff that writes the isLicensed state to config and then when the config is commited that tries to updates the scroll module but it isn't initialized, yet so it crashes. If we structured things better we could do this before Post-check init but it's not important enough.
        /// - If the helper is started because the user flipped the switch (not because the computer just started or something), then `triggeredByUser` should probably be `YES`. But it's currently unused anyways.
        
        [TrialCounter load_Manual];
        
        [LicenseConfig getOnComplete:^(LicenseConfig * _Nonnull licenseConfig) {
            [License checkAndReactWithLicenseConfig:licenseConfig triggeredByUser:NO];
        }];
        
        ///
        /// Debug & testing
        ///
//
//        [SecureStorage set:@"hi.im.groot" value:@"what's your name? Hghhhh?"];
//        NSString *secure = [SecureStorage get:@"hi.im.groot"];
//
//        DDLogDebug(@"Value from secure storage: %@", secure);
//
//        DDLogDebug(@"Entire secure storage: %@", [SecureStorage getAll]);
//
//        [LicenseConfig getOnComplete:^(LicenseConfig * _Nonnull licenseConfig) {
//
//            [License licenseStateWithLicenseConfig:licenseConfig completionHandler:^(MFLicenseAndTrialState license, NSError * _Nullable error) {
//
//                dispatch_async(dispatch_get_main_queue(), ^{
//
//                    [TrialNotificationController.shared openWithLicenseConfig:licenseConfig license:license triggeredByUser:NO];
//                });
//            }];
//        }];
        
    //    [Gumroad checkLicense:license email:email completionHandler:^(BOOL isValidKey, NSDictionary<NSString *,id> * _Nullable serverResponse, NSError * _Nullable error, NSURLResponse * _Nullable urlResponse) {
    //
    //            DDLogDebug(@"License check result - isValidKey: %d, error: %@", isValidKey, error);
    //    }];
//        [Licensing licensingStateWithCompletionHandler:^(MFLicenseAndTrialState licensing, NSError *error) {
//            DDLogDebug(@"License check result - state: %d, currentDay: %d, trialDays: %d, error: %@", licensing.state, licensing.daysOfUse, licensing.trialDays, error);
//        }];
    }
}

+ (Boolean)checkAccessibilityAndUpdateSystemSettings {
    
    /// Check if accessibility is enabled.
    ///     Also adds MMF to the list in System Settings
    
    /// Create options
    /// - Suppresses macOS user prompts with the `kAXTrustedCheckOptionPrompt` parameter.
    /// - Doesn't seem to work right now. Still prompts if MMF wasn't in the System Settings list before hand. Testing under Ventura RC.
    /// - TODO: Simplify by moving to NSDictionary and bridging to CFDictionaryRef
    CFMutableDictionaryRef options = CFDictionaryCreateMutable(kCFAllocatorDefault, 1, NULL, NULL);
    CFDictionaryAddValue(options, kAXTrustedCheckOptionPrompt, kCFBooleanFalse);
    
    /// Call core function
    ///     This also makes the helper show up in System Settings and shows the macOS user prompt (if we don't suppress the prompt)
    ///     But it seems making the helper show up in System Settings only works the first time calling this func after the helper has been launched.
    Boolean isTrusted = AXIsProcessTrustedWithOptions(options);
    
    /// Release & return
    CFRelease(options);
    return isTrusted;
}

@end
