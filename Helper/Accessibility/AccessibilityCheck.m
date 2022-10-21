//
// --------------------------------------------------------------------------
// AccessibilityCheck.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "AccessibilityCheck.h"

#import <AppKit/AppKit.h>
#import "SharedMessagePort.h"
#import "MessagePort_Helper.h"
#import "DeviceManager.h"
#import "ConfigFileInterface_Helper.h"
#import "ScrollControl.h"
#import "ButtonInputReceiver.h"
#import "Constants.h"
#import "ModifiedDrag.h"
#import "ModifierManager.h"
#import "SharedUtility.h"

#import <os/log.h>

@implementation AccessibilityCheck

NSTimer *_openMainAppTimer;

+ (void)load {
    
//    os_log_t MFLog = os_log_create(kMFBundleIDHelper.UTF8String, "status");
//    os_log(MFLog, "Mac Mouse Fix Helper begins logging excessively...");
    
    [MessagePort_Helper load_Manual];
    
    Boolean accessibilityEnabled = [self checkAccessibilityAndUpdateSystemSettings];
    
    if (!accessibilityEnabled) {
        
        NSLog(@"Accessibility Access Disabled");
        
        [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(sendAccessibilityMessageToMainApp) userInfo:NULL repeats:NO];
        
        _openMainAppTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(openMainApp) userInfo:NULL repeats:YES];
            
    } else {
        
        // Using load_Manual instead of normal load, because creating an eventTap crashes the program, if we don't have accessibilty access (I think - I don't really remember)
        // TODO: Look into using `+ initialize` instead of `+ load`. The way we have things set up there are like a bajillion entry points to the program (one for every `+ load` function) which is kinda sucky. Might be better to have just one entry point to the program and then start everything that needs to be started with `+ start` functions and let `+ initialize` do the rest
        [DeviceManager load_Manual];
        [ConfigFileInterface_Helper load_Manual];
        [ScrollControl load_Manual];
        [ModifiedDrag load_Manual];
        [ModifierManager load_Manual];
        
        [ButtonInputReceiver load_Manual]; // TODO: Check if this is necessary. I think that not having this caused a crash when accessibility permissions were denied.
        
        [SharedMessagePort sendMessage:@"helperEnabled" withPayload:nil expectingReply:NO];
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
    ///     This also makes the helper show up in System Settings and shows the macOS user prompt.
    ///     But it seems that only works once after the helper has been launched.
    Boolean isTrusted = AXIsProcessTrustedWithOptions(options);
    
//    /// Workaround for macOS bug
//    ///     If there's still and old version of the helper in System Settings, the user won't be able to trust the new helper. So we remove the old helper from System Settings and add the new one again.
//
//    if (!isTrusted) {
//
//        /// Remove existing helper from System Settings
//        ///     This will make the system unresponsive if there is still an old helper running that's already tapped into the button event stream!
//        [SharedUtility launchCLT:[NSURL fileURLWithPath:kMFTccutilPath] withArgs:@[@"reset", @"Accessibility", kMFBundleIDHelper]];
//
//        /// Add the new helper
//        ///     I think adding the helper via`AXIsProcessTrustedWithOptions` can only be done once after the app has started up, so we need to restart the helper.
//        isTrusted = AXIsProcessTrustedWithOptions(options);
//    }
    
    /// Release & return
    CFRelease(options);
    return isTrusted;
}


/// Timer Callbacks

+ (void)sendAccessibilityMessageToMainApp {
    NSLog(@"Sending accessibilty disabled message to main app");
    [SharedMessagePort sendMessage:@"accessibilityDisabled" withPayload:nil expectingReply:NO];
}

+ (void)openMainApp {
    
    if ([self checkAccessibilityAndUpdateSystemSettings]) {
        
        /// Open app
        NSArray<NSRunningApplication *> *apps = [NSRunningApplication runningApplicationsWithBundleIdentifier:kMFBundleIDApp];
        for (NSRunningApplication *app in apps) {
            [app activateWithOptions:NSApplicationActivateIgnoringOtherApps];
        }
        /// Close this app (Will be restarted immediately by launchd)
        [NSApp terminate:NULL];
//        [self load]; // TESTING - to make button capture notification work
//        [_openMainAppTimer invalidate]; // TESTING
    }
}


@end
