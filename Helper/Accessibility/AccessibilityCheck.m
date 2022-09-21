//
// --------------------------------------------------------------------------
// AccessibilityCheck.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

#import "AccessibilityCheck.h"

#import <AppKit/AppKit.h>
#import "SharedMessagePort.h"
#import "MessagePort_Helper.h"
#import "DeviceManager.h"
#import "Config.h"
#import "Scroll.h"
#import "ButtonInputReceiver.h"
#import "Constants.h"
#import "ModifiedDrag.h"
#import "ModifierManager.h"
#import "Mac_Mouse_Fix_Helper-Swift.h"
#import "PointerFreeze.h"

#import "SharedUtility.h"

#import <signal.h>

@implementation AccessibilityCheck

NSTimer *_openMainAppTimer;

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
        DDLogWarn(@"SIGTERM handler caught weird signal: %d", signal_number);
    }
}

/// Testing

CGEventRef _Nullable testCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void * __nullable userInfo) {
    
    if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) {
        return NULL;
    }
    
    IOHIDDeviceRef device = CGEventGetSendingDevice(event);
    NSString *deviceName = (__bridge NSString *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductKey));
    DDLogDebug(@"Sending Device Test: %@", deviceName);
    
    /// CGEvent bridging test
    ///     Conclusion: objc version of cgevent has no properties, no ivars and no interesting methods
    ///     Also see code built on this: [SharedUtility dumpClassInfo];
    
    id objcEvent = (__bridge id)event;
    
    DDLogDebug(@"objcEvent: %@", [objcEvent description]);
    
    /// Return
    return event;
}

/// Load

+ (void)load {
    
    ///
    /// Testing & Debug
    ///
    
//    [GlobalDefaults applyDoubleClickThreshold];
//    PointerConfig.customTableBasedAccelCurve;
//    CFMachPortRef testTap = [TransformationUtility createEventTapWithLocation:kCGSessionEventTap mask:CGEventMaskBit(kCGEventMouseMoved) | CGEventMaskBit(kCGEventLeftMouseDragged) | CGEventMaskBit(kCGEventScrollWheel) | CGEventMaskBit(kCGEventLeftMouseDown) /* | CGEventMaskBit()*/ option:kCGEventTapOptionDefault placement:kCGTailAppendEventTap callback: testCallback];
//    CGEventTapEnable(testTap, true);
    
    
    ///
    /// Setup termination handler
    ///
    
    struct sigaction action = {
        .sa_flags = SA_SIGINFO,
        .sa_mask = 0,
        .sa_sigaction = signal_handler,
    };
    int rt = sigaction(SIGTERM, &action, NULL);
    if (rt < 0) {
        DDLogError(@"Error setting up sigterm handler: %d", rt);
    }
    
    /// Set up CocoaLumberjack
    [SharedUtility setupBasicCocoaLumberjackLogging];
    DDLogInfo(@"Mac Mosue Fix begins logging excessively");
    
    ///
    /// __Pre-check init__
    ///
    
    [PrefixSwift initGlobalStuff];
    [MessagePort_Helper load_Manual];
    
    ///
    /// Do the accessibility check
    ///
    Boolean accessibilityEnabled = [self check];
    if (!accessibilityEnabled) {
        
        DDLogInfo(@"Accessibility Access Disabled");
        
        /// Send 'accessibility is disabled' message to mainApp
        ///  Notes:
        ///  - I think we only send this once, because the mainApp will ask for this information if it needs it afterwards by sending 'check accessibility' messages to the helper.
        ///  - Why the 0.5s delay?
        [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(sendAccessibilityMessageToMainApp) userInfo:NULL repeats:NO];
        
        /// Check accessibility every 0.5s. Once the accessibility is enabled, restart the helper and notify the mainApp.
        _openMainAppTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(openMainAppAndRestart) userInfo:NULL repeats:YES];
            
    } else {
        
        ///
        /// __Post-check init__
        ///
        /// Using `load_Manual` instead of normal load, because creating an eventTap crashes the program, if we don't have accessibilty access (I think - I don't really remember)
        /// TODO: Look into using `+ initialize` instead of `+ load`. The way we have things set up there are like a bajillion entry points to the program (one for every `+ load` function) which is kinda sucky. Might be better to have just one entry point to the program and then start everything that needs to be started with `+ start` functions and let `+ initialize` do the rest
        [ButtonInputReceiver load_Manual];
        [DeviceManager load_Manual];
        [Scroll load_Manual];
        [Config load_Manual];
        [ModifiedDrag load_Manual];
        [ModifierManager load_Manual];
        
        [ScreenDrawer.shared load_Manual];
        [PointerFreeze load_Manual];
        
        [MenuBarItem load_Manual];
        
        /// Send 'started' message to mainApp
        ///     Note: We could improve responsivity of the enableToggle in mainApp by sending the message before doing all the initialization. But only slightly.
        [SharedMessagePort sendMessage:@"helperEnabled" withPayload:nil expectingReply:NO];
        
        ///
        /// License init
        ///
        /// Note:
        /// - It would make sense to do this before the accessibility check, but calling this before the Post-check init crashes because of some stupid stuff. The stupid stuff is I I think the [Trial load_Manual] calls some other stuff that writes the isLicensed state to config and then when the config is commited that tries to updates the scroll module but it isn't initialized, yet so it crashes. If we structured things better we could do this before Post-check init but it's not important enough.
        /// - If the helper is started because the user flipped the switch (not because the computer just started or something), then `triggeredByUser` should probably be `YES`. But it's currently unused anyways.
        
        [TrialCounter load_Manual];
        
        [LicenseConfig getOnComplete:^(LicenseConfig * _Nonnull licenseConfig) {
            [License runCheckAndReactWithLicenseConfig:licenseConfig triggeredByUser:NO];
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
//            [License licenseStateWithLicenseConfig:licenseConfig completionHandler:^(MFLicenseReturn license, NSError * _Nullable error) {
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
//        [Licensing licensingStateWithCompletionHandler:^(MFLicenseReturn licensing, NSError *error) {
//            DDLogDebug(@"License check result - state: %d, currentDay: %d, trialDays: %d, error: %@", licensing.state, licensing.daysOfUse, licensing.trialDays, error);
//        }];
    }
}

+ (Boolean)check {
    CFMutableDictionaryRef options = CFDictionaryCreateMutable(kCFAllocatorDefault, 1, NULL, NULL);
    CFDictionaryAddValue(options, kAXTrustedCheckOptionPrompt, kCFBooleanFalse);
    Boolean result = AXIsProcessTrustedWithOptions(options);
    CFRelease(options);
    return result;
}


/// Timer Callbacks

+ (void)sendAccessibilityMessageToMainApp {
    DDLogInfo(@"Sending accessibilty disabled message to main app");
    [SharedMessagePort sendMessage:@"accessibilityDisabled" withPayload:nil expectingReply:NO];
}

+ (void)openMainAppAndRestart {
    
    if ([self check]) {
        
        /// Open mainApp
        ///     Edit: What? Why are we calling `[self openMainAppAndRestart]` again here? Doesn't this cause an infinite loop? We'll change this to call `[HelperUtility openMainApp]`.
        [HelperUtility openMainApp];
        
        /// Close helperApp (Will be restarted immediately by launchd)
        [NSApp terminate:nil];
        
        /// Testing
//        [self load]; /// To make button capture notification work
//        [_openMainAppTimer invalidate];
    }
}


@end
