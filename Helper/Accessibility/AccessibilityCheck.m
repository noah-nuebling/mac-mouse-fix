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
    
    id objcEvent = (__bridge id)event;
    
    DDLogDebug(@"objcEvent: %@", [objcEvent description]);
    
    unsigned int nProperties;
    Class eventClass = [objcEvent class];
    objc_property_t *propertyList = class_copyPropertyList(eventClass, &nProperties);
    unsigned int nIvars;
    Ivar *ivarList = class_copyIvarList(eventClass, &nIvars);
    
    unsigned int nMethods;
    Method *methodList = class_copyMethodList(eventClass, &nMethods);
    
    DDLogDebug(@"nProps: %u, nIvars: %d, nMethods: %d", nProperties, nIvars, nMethods);
    
    for (int i = 0; i < nMethods; i++) {
        Method m = methodList[i];
        SEL mSelector = method_getName(m);
        const char *mName = sel_getName(mSelector);
        DDLogDebug(@"objcEventMethodName: %s", mName);
    }
    
    /// Return
    return event;
}

/// Load

+ (void)load {
    
    /// Debug
//    [GlobalDefaults applyDoubleClickThreshold];
//    PointerConfig.customTableBasedAccelCurve;
//    CFMachPortRef testTap = [TransformationUtility createEventTapWithLocation:kCGSessionEventTap mask:CGEventMaskBit(kCGEventMouseMoved) | CGEventMaskBit(kCGEventLeftMouseDragged) | CGEventMaskBit(kCGEventScrollWheel) | CGEventMaskBit(kCGEventLeftMouseDown) /* | CGEventMaskBit()*/ option:kCGEventTapOptionDefault placement:kCGTailAppendEventTap callback: testCallback];
//    CGEventTapEnable(testTap, true);
    
    
    /// Setup termination handler

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
    
    [PrefixSwift initGlobalStuff];
    
    [MessagePort_Helper load_Manual];
    
    Boolean accessibilityEnabled = [self check];
    
    if (!accessibilityEnabled) {
        
        DDLogInfo(@"Accessibility Access Disabled");
        
        [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(sendAccessibilityMessageToMainApp) userInfo:NULL repeats:NO];
        
        _openMainAppTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(openMainApp) userInfo:NULL repeats:YES];
            
    } else {
        
        // Using load_Manual instead of normal load, because creating an eventTap crashes the program, if we don't have accessibilty access (I think - I don't really remember)
        // TODO: Look into using `+ initialize` instead of `+ load`. The way we have things set up there are like a bajillion entry points to the program (one for every `+ load` function) which is kinda sucky. Might be better to have just one entry point to the program and then start everything that needs to be started with `+ start` functions and let `+ initialize` do the rest
        [ButtonInputReceiver load_Manual];
        [DeviceManager load_Manual];
        [Config load_Manual];
        [Scroll load_Manual];
        [ModifiedDrag load_Manual];
        [ModifierManager load_Manual];
        
        [ScreenDrawer.shared load_Manual];
        [PointerFreeze load_Manual];
        
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
