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
#import "HelperServices.h"

#import <os/log.h>

@implementation AccessibilityCheck

NSTimer *_openMainAppTimer;

+ (void)load {
    
    /// This is the main entry point of the app
    
    ///
    /// Check command line args.
    ///     If there are args, just process them and then exit.
    
    NSMutableArray<NSString *> *args = NSProcessInfo.processInfo.arguments.mutableCopy;
    [args removeObjectAtIndex:0]; /// First argument is just the executable path or sth, we can ignore that.
    
    if (args.count > 0) {
        
        /// Log
        NSLog(@"Started helper with command line args: %@", args);
        
        ///
        /// Process args
        if ([args[0] isEqual:@"forceUpdateAccessibilitySettings"]) {
            
            ///
            /// Force update accessibility settings
            ///
            
            /// This is a workaround
            ///     for an Apple bug in Ventura (maybe previous versions too?) where the accessibility toggle for MMF Helper won't work after an update.
            ///     This bug occured between 2.2.0 and 2.2.1 when I moved the app from a Development Signature to a proper Developer Program Signature.
            ///     Bug also maybe occurs for 3.0.0 Beta 4. Not sure why. Maybe it's a different bug that just looks similar.
            /// See
            /// - https://github.com/noah-nuebling/mac-mouse-fix/issues/415
            /// - https://github.com/noah-nuebling/mac-mouse-fix/issues/412
            /// - https://github.com/noah-nuebling/mac-mouse-fix/discussions/101 (Accessibility Guide)
            
            /// Why do this in such a weird way?
            /// - We need to launch a new helper instance instead of just using the normal helper instance because `AXIsProcessTrustedWithOptions` will only add the helper to System Settings __once__ after launch. Subsequent calls don't do anything.`AXIsProcessTrustedWithOptions` is also the __only__ way to check if we already have accessibility access. And we need to check if we already have access __before__ deciding to reset the access, because we don't want to reset access if it has already been granted. So therefore we need to do the intial check and the forced system settings update in two different instances of the helper. You would think normally relaunching the helper would solve this but...
            /// - We can't just relaunch the helper normally through launchd because launchd permits at most 1 start per 10 seconds. So if the helper's just been enabled and there's no accessibility access you have to wait 10 seconds until the helper can be restarted through launchd.
            
            /// Log
            
            NSLog(@"Force update system settings");
            
            /// Remove existing helper from System Settings
            /// - If an old helper exists, the user won't be able to enable the new helper!
            /// - This will make the system unresponsive if there is still an old helper running that's already tapped into the button event stream!
            [SharedUtility launchCLT:[NSURL fileURLWithPath:kMFTccutilPath] withArguments:@[@"reset", @"Accessibility", kMFBundleIDHelper] error:nil];
            
            /// Add self to System Settings
            [self checkAccessibilityAndUpdateSystemSettings];
        }
        
        /// Close helper
        exit(0);
    }
    
    ///
    /// No command line args - start normally
    ///
    
    [MessagePort_Helper load_Manual];
    
    Boolean isTrusted = [self checkAccessibilityAndUpdateSystemSettings];
    
    if (!isTrusted) {
        
        /// Log
        NSLog(@"Accessibility Access Disabled");
        
        /// Workaround for macOS bug
        ///     If there's still and old version of the helper in System Settings, the user won't be able to trust the new helper. So we remove the old helper from System Settings and add the new one again.

        [HelperServices launchHelperInstanceWithMessage:@"forceUpdateAccessibilitySettings"];
        
        [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(sendAccessibilityMessageToMainApp) userInfo:NULL repeats:NO];
        
        _openMainAppTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(openMainApp) userInfo:NULL repeats:YES];
            
    } else {
        
        /// Using `load_Manual` instead of normal load, because creating an eventTap crashes the program, if we don't have accessibilty access (I think - I don't really remember)
        /// TODO: Look into using `+ initialize` instead of `+ load`. The way we have things set up there are like a bajillion entry points to the program (one for every `+ load` function) which is kinda sucky. Might be better to have just one entry point to the program and then start everything that needs to be started with `+ start` functions and let `+ initialize` do the rest
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
    ///     This also makes the helper show up in System Settings and shows the macOS user prompt (if we don't suppress the prompt)
    ///     But it seems making the helper show up in System Settings only works the first time calling this func after the helper has been launched.
    Boolean isTrusted = AXIsProcessTrustedWithOptions(options);
    
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
