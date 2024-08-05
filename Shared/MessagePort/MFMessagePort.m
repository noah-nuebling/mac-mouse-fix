//
// --------------------------------------------------------------------------
// MFMessagePort.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "MFMessagePort.h"
#import <Cocoa/Cocoa.h>
#import "Constants.h"
#import "SharedUtility.h"
#import "Locator.h"
#import "HelperServices.h"
#import "Locator.h"
#import "Logging.h"

#if IS_MAIN_APP
#import "Mac_Mouse_Fix-Swift.h"
#import "KeyCaptureView.h"
#import "Alerts.h"
#endif

#if IS_HELPER
#import "Mac_Mouse_Fix_Helper-Swift.h"
#import "AccessibilityCheck.h"
#import "KeyCaptureMode.h"
#endif

/// This class is used to communicate between the MainApp and the Helper.
///     More or less works like a function call across processes.
/// Notes:
/// - Can't be named MessagePort because there's already a class in Foundation with that name
/// - This is a wrapper around CFMessagePort, which itself is a wrapper around mach ports. This was one of the first things we wrote for Mac Mouse Fix. Don't remember why we didn't use the higher level NSMachPort or directly use the low level mach_port C APIs.
///
/// Discussion / confusion:
///     We used to do use `load` instead of `initialize` but that lead to issues when restarting the app if it's translocated:
///     If the app detects that it is translocated, it will restart itself at the untranslocated location,  after removing the quarantine flags from itself. It starts a copy of itself while it's still running, and only then does it terminate itself. If the message port is already 'claimed' by the translocated instances when it starts the     untranslocated copy, then the untranslocated copy can't 'claim' the message port for itself, which leads to things like the accessiblity screen not working.
///     I hope that moving using `initialize` instead of `load` if `IS_MAIN_APP` should fix this and work just fine for everything else. I don't know why we used load to begin with.
///     Edit: I don't remember why we moved to `load_Manual` now, but it works fine
///
/// Event older Notes:
///     Notes from mainApp:
///         On Catalina, creating the local Port returns NULL and throws a permission denied error. Trying to schedule it with the runloop yields a crash.
///         But even if you just skip the runloop scheduling it still works somehow!

///     Notes from Helper:
///         CFMessagePortCreateRunLoopSource() used to crash when another instance of MMF Helper was already running.
///         It would log this: `*** CFMessagePort: bootstrap_register(): failed 1100 (0x44c) 'Permission denied', port = 0x1b03, name = 'com.nuebling.mac-mouse-fix.helper'`
///         I think the reason for this message is that the existing instance would already 'occupy' the kMFBundleIDHelper name.
///         Checking if `localPort != nil` should detect this case

@implementation MFMessagePort

+ (void)load_Manual {
    
    #pragma mark - Init
    
    /// Set up a local port for listening for incoming messages
    
    /// Validate
    assert(runningMainApp() || runningHelper());
    
    /// Log
    DDLogInfo(@"Initializing MessagePort...");
    
    /// Create port
    CFStringRef messagePortName = (__bridge CFStringRef)(runningMainApp() ? kMFBundleIDApp : kMFBundleIDHelper);
    CFMessagePortRef localPort = CFMessagePortCreateLocal(kCFAllocatorDefault, messagePortName, didReceiveMessage, nil, NULL);

    /// Log
    DDLogInfo(@"Created localPort: %@", localPort);
    
    /// Validate
    if (localPort == nil) {
        
        if (runningMainApp()) {
            DDLogInfo(@"Failed to create a local message port. It will probably work anyway for some reason");
        } else {
            DDLogError(@"Failed to create a local message port. This might be because there is another instance of %@ already running. Crashing the app.", kMFHelperName);
            @throw [NSException exceptionWithName:@"NoMessagePortException" reason:@"Couldn't create a local CFMessagePort. Can't function properly without local CFMessagePort" userInfo:nil];
        }
        
        return;
    }
        
    /// Add message port to main runLoop
    CFRunLoopSourceRef runLoopSource = CFMessagePortCreateRunLoopSource(kCFAllocatorDefault, localPort, 0);
    CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, kCFRunLoopCommonModes);
    CFRelease(runLoopSource);
}

static CFDataRef _Nullable didReceiveMessage(CFMessagePortRef port, SInt32 messageID, CFDataRef data, void *info) {
    
    #pragma mark Receive messages
    
    /// Validate
    assert(runningMainApp() || runningHelper());
    
    /// Decode message
    NSDictionary *messageDict = [NSKeyedUnarchiver unarchiveObjectWithData:(__bridge NSData *)data];
    NSString *message = messageDict[kMFMessageKeyMessage];
    NSObject *payload = messageDict[kMFMessageKeyPayload];
    
    /// Log
    DDLogInfo(@"Received Message: %@ with payload: %@", message, payload);
    
    /// Process message
    __block NSObject *response = nil;
    const NSDictionary<NSString *, void (^)(void)> *commandMap;
    
#if IS_MAIN_APP
 
     commandMap = @{
    
        @"addModeFeedback": ^{
            [MainAppState.shared.buttonTabController handleAddModeFeedbackWithPayload:(NSDictionary *)payload];
        },
        @"keyCaptureModeFeedback": ^{
            [KeyCaptureView handleKeyCaptureModeFeedbackWithPayload:(NSDictionary *)payload isSystemDefinedEvent:NO];
        },
        @"keyCaptureModeFeedbackWithSystemEvent": ^{
            [KeyCaptureView handleKeyCaptureModeFeedbackWithPayload:(NSDictionary *)payload isSystemDefinedEvent:YES];
        },
        @"helperEnabledWithNoAccessibility": ^{
            
            BOOL isStrange = false;
            if (@available(macOS 13, *)) {
                isStrange = [MessagePortUtility.shared checkHelperStrangenessReactWithPayload:payload];
            }
            if (!isStrange) {
                [AuthorizeAccessibilityView add];
            }
        },
        @"helperEnabled": ^{
            
            BOOL isStrange = false;
            if (@available(macOS 13, *)) {
                isStrange = [MessagePortUtility.shared checkHelperStrangenessReactWithPayload:payload];
            }
            
            if (!isStrange) { /// Helper matches mainApp instance.
                
                /// Bring mainApp for foreground
                /// In some places like when the accessibilitySheet is dismissed, we have other methods for bringing mainApp to the foreground that might be unnecessary now that we're doing this. Edit: We stopped the accessibiility enabling code from activating the app.
                [NSApp activateIgnoringOtherApps:YES];
                
                /// Dismiss accessibilitySheet
                ///     This is unnecessary under Ventura since `activateIgnoringOtherApps` will trigger `ResizingTabWindowController.windowDidBecomeMain()` which will also call `[AuthorizeAccessibilityView remove]`. But it's better to be safe and explicit about this.
                [AuthorizeAccessibilityView remove];
                
                /// Notify rest of the app
                [EnabledState.shared reactToDidBecomeEnabled];
            }
            
        },
        @"helperDisabled": ^{
            [EnabledState.shared reactToDidBecomeDisabled];
        },
        @"configFileChanged": ^{
            [Config loadFileAndUpdateStates];
        },
        @"showNextToastOrSheetWithSection": ^{
            BOOL moreToastsToGo = [ToastAndSheetTests showNextTestWithSection:(id)payload]; /// If this is true, we haven't ran out of test-toasts for this section, yet.
            response = @(moreToastsToGo);
        },
        @"didShowAllToastsAndSheets": ^{
            BOOL didShowAll = [ToastAndSheetTests didShowAllToastsAndSheets];
            response = @(didShowAll);
        }
    };

#elif IS_HELPER
    
    commandMap = @{
        @"configFileChanged": ^{
            [Config loadFileAndUpdateStates];
        },
        @"terminate": ^{
//            [NSApp.delegate applicationWillTerminate:[[NSNotification alloc] init]]; /// This creates an infinite loop or something? The statement below is never executed.
            [NSApp terminate:NULL];
        },
        @"checkAccessibility": ^{
            BOOL isTrusted = [AccessibilityCheck checkAccessibilityAndUpdateSystemSettings];
            response = @(isTrusted);
        },
        @"enableAddMode": ^{
            BOOL success = [Remap enableAddMode];
            response = @(success);
        },
        @"disableAddMode": ^{
            BOOL success = [Remap disableAddMode];
            response = @(success);
        },
        @"enableKeyCaptureMode": ^{
            [KeyCaptureMode enable];
        },
        @"disableKeyCaptureMode": ^{
            [KeyCaptureMode disable];
        },
        @"getActiveDeviceInfo": ^{
            
            Device *dev = HelperState.shared.activeDevice;
            if (dev != NULL) {
                
                response = @{
                    @"name": dev.name == nil ? @"" : dev.name,
                    @"manufacturer": dev.manufacturer == nil ? @"" : dev.manufacturer,
                    @"nOfButtons": @(dev.nOfButtons),
                };
            }
        },
        @"updateActiveDeviceWithEventSenderID": ^{
            /// We can't just pass over the CGEvent from the mainApp because the senderID isn't stored when serializing CGEvents
            uint64_t senderID = [(NSNumber *)payload unsignedIntegerValue];
            [HelperState.shared updateActiveDeviceWithEventSenderID:senderID];
        },
        @"getBundleVersion": ^{
            response = @(Locator.bundleVersion);
        },
    };
    
#else
    abort();
#endif
    
    /// Execute command
    void (^command)(void) = commandMap[message];
    if (command != nil) {
        command();
    } else {
        DDLogInfo(@"Unknown message received: %@", message);
    }
    
    /// Return response
    if (response != nil) {
         return (__bridge_retained CFDataRef)[NSKeyedArchiver archivedDataWithRootObject:response];
    } else {
        return NULL;
    }
}

+ (NSObject *_Nullable)sendMessage:(NSString * _Nonnull)message withPayload:(NSObject<NSCoding> * _Nullable)payload toRemotePort:(NSString *)remotePortName waitForReply:(BOOL)waitForReply {
    
    #pragma mark Send messages
    
    /// Get remote port
    /// Note: We can't just create the port once and cache it, trying to send with that port will yield ``kCFMessagePortIsInvalid``
    CFMessagePortRef remotePort = CFMessagePortCreateRemote(kCFAllocatorDefault, (__bridge CFStringRef)remotePortName);

    /// Validate
    if (remotePort == NULL) {
        DDLogInfo(@"Can't send message \'%@\', because there is no CFMessagePort", message);
        return nil;
    }
    
    /// Setup callback when port is invalidated
    ///     Not sure why we're doing this.
    CFMessagePortSetInvalidationCallBack(remotePort, invalidationCallback);

    /// Create message dict
    NSDictionary *messageDict;
    if (payload) {
        messageDict = @{
            kMFMessageKeyMessage: message,
            kMFMessageKeyPayload: payload,
        };
    } else {
        messageDict = @{
            kMFMessageKeyMessage: message,
        };
    }
    
    /// Log
    DDLogInfo(@"Sending message: %@ with payload: %@ from bundle: %@ via message port", message, payload, NSBundle.mainBundle.bundleIdentifier);
    
    /// Send message
    SInt32 messageID = 0x420666; /// Arbitrary
    CFDataRef messageData = (__bridge CFDataRef)[NSKeyedArchiver archivedDataWithRootObject:messageDict];
    CFTimeInterval sendTimeout = 0.0;
    CFTimeInterval recieveTimeout = 0.0;
    CFStringRef replyMode = NULL;
    CFDataRef responseData = NULL;
    if (waitForReply) {
        sendTimeout = 0.0;
        recieveTimeout = 1.0;
        replyMode = kCFRunLoopDefaultMode;
    }
    SInt32 status = CFMessagePortSendRequest(remotePort, messageID, messageData, sendTimeout, recieveTimeout, replyMode, &responseData);
    
    /// Release port
    CFRelease(remotePort);
    
    /// Handle errors
    if (status != 0) {
        DDLogError(@"Non-zero CFMessagePortSendRequest status: %d", status);
        return nil;
    }
    
    /// Decode response
    NSObject *response = nil;
    if (responseData != NULL && waitForReply) {
        response = [NSKeyedUnarchiver unarchiveObjectWithData:(__bridge NSData *)responseData];
    }
    
    /// Return response
    return response;
}

///
/// Helper stuff
///

+ (NSObject *_Nullable)sendMessage:(NSString *)message withPayload:(NSObject<NSCoding> *)payload waitForReply:(BOOL)replyExpected {
        
    /// Convenience wrapper
    ///     Automatically sends the message to the helper if the mainApp is the sender, and sends to the mainApp if the helper is the sender.
    
    /// Validate
    assert(runningMainApp() || runningHelper());
    
    /// Get remote port name
    NSString *remotePortName = runningMainApp() ? kMFBundleIDHelper : kMFBundleIDApp;
    
    /// Call core
    NSObject *response = [self sendMessage:message withPayload:payload toRemotePort:remotePortName waitForReply:replyExpected];
    
    /// Return
    return response;
}

void invalidationCallback(CFMessagePortRef ms, void *info) {
    /// Log state
    DDLogInfo(@"Remote MessagePort invalidated in %@", runningHelper() ? @"Helper" : @"MainApp");
}

@end
