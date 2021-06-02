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
#import "ConfigInterface_Helper.h"
#import "ScrollControl.h"
#import "ButtonInputReceiver.h"
#import "Constants.h"
#import "ModifiedDrag.h"
#import "ModifierManager.h"

#import "SharedUtility.h"

@implementation AccessibilityCheck

NSTimer *_openMainAppTimer;

+ (void)load {
    
    // Set up CocoaLumberjack
    [SharedUtility setupBasicCocoaLumberjackLogging];
    DDLogInfo(@"Mac Mosue Fix begins logging excessively");
    
    [MessagePort_Helper load_Manual];
    
    Boolean accessibilityEnabled = [self check];
    
    if (!accessibilityEnabled) {
        
        DDLogInfo(@"Accessibility Access Disabled");
        
        [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(sendAccessibilityMessageToMainApp) userInfo:NULL repeats:NO];
        
        _openMainAppTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(openMainApp) userInfo:NULL repeats:YES];
            
    } else {
        
        // Using load_Manual instead of normal load, because creating an eventTap crashes the program, if we don't have accessibilty access (I think - I don't really remember)
        // TODO: Look into using `+ initialize` instead of `+ load`. The way we have things set up there are like a bajillion entry points to the program (one for every `+ load` function) which is kinda sucky. Might be better to have just one entry point to the program and then start everything that needs to be started with `+ start` functions and let `+ initialize` do the rest
        [DeviceManager load_Manual];
        [ConfigInterface_Helper load_Manual];
        [ScrollControl load_Manual];
        [ModifiedDrag load_Manual];
        [ModifierManager load_Manual];
        
        [ButtonInputReceiver load_Manual]; // TODO: Check if this is necessary. I think that not having this caused a crash when accessibility permissions were denied.
        
        [SharedMessagePort sendMessage:@"helperEnabled" withPayload:nil expectingReply:NO];
    }
}
+ (Boolean)check {
    CFMutableDictionaryRef options = CFDictionaryCreateMutable(kCFAllocatorDefault, 1, NULL, NULL);
    CFDictionaryAddValue(options, kAXTrustedCheckOptionPrompt, kCFBooleanFalse);
    Boolean result = AXIsProcessTrustedWithOptions(options);
    CFRelease(options);
    return result;
}


// Timer Callbacks

+ (void)sendAccessibilityMessageToMainApp {
    DDLogInfo(@"Sending accessibilty disabled message to main app");
    [SharedMessagePort sendMessage:@"accessibilityDisabled" withPayload:nil expectingReply:NO];
}

+ (void)openMainApp {
    
    if ([self check]) {
        
        // Open app
        NSArray<NSRunningApplication *> *apps = [NSRunningApplication runningApplicationsWithBundleIdentifier:kMFBundleIDApp];
        for (NSRunningApplication *app in apps) {
            [app activateWithOptions:NSApplicationActivateIgnoringOtherApps];
        }
        // Close this app (Will be restarted immediately by launchd)
        [NSApp terminate:NULL];
//        [self load]; // TESTING - to make button capture notification work
//        [_openMainAppTimer invalidate]; // TESTING
    }
}


@end
