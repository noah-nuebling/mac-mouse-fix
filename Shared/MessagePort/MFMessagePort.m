//
// --------------------------------------------------------------------------
// MFMessagePort.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// This class is used to communicate between the MainApp and the Helper.
///     More or less works like a function call across processes.
/// Notes:
/// - Can't be named MessagePort because there's already a class in Foundation with that name
/// - This is a wrapper around CFMessagePort, which itself is a wrapper around mach ports. This was one of the first things we wrote for Mac Mouse Fix. Don't remember why we didn't use the higher level NSMachPort or directly use the low level mach_port C APIs. 
///
/// TODO:
///     Make this secure.
///     Ideas: ([Since Dec 2024]])
///         1. Switch from CFMessagePort to NSMachPort
///             - then get the **audit token** from the mach message, then use `SecTaskCreateWithAuditToken()` and `SecTaskCopySigningIdentifier()` to get the 'signingID' of the message sender.
///                 (I speculate that) the 'signingID' is NULL if the app isn't signed, and otherwise is the bundleID. BundleID's are unique among signed apps I think. If these assumptions are true this should let us confidently identify the message sender as "not a hacker".
///             - Given the sender's **PID** we could also check that the relative path between us and the helper matches our expectations. This might not add additional protection against hackers, but it would also solve the "Strange Helper" issues (Although IIRC I don't see those anymore since macOS 15 Sequoia)
///         2. Use NSSecureCoding to unarchive our objects.
///             - Might be a bit annoying / verbose to deal with on the receiving end.
///             - Not sure how much this would help (NSSecureCoding only enforces that you specify which classes may be decoded from the archive – but theres probably lots of other things about the message we should validate to actually make things secure. Discussed this more in MFDataClass implementation.)
///     Also see:
///         - Dennis Babkin blog about mach messaging in macOS, with "Security Considerations" section:
///             https://dennisbabkin.com/blog/?t=interprocess-communication-using-mach-messages-for-macos

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
    CFMessagePortRef localPort = CFMessagePortCreateLocal(kCFAllocatorDefault, messagePortName, didReceiveMessage, NULL, NULL);

    /// Log
    DDLogInfo(@"Created localPort: %@", localPort);
    
    /// Validate
    if (localPort == NULL) {
        
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

NSString *CFMessagePortSendRequest_ErrorCode_ToString(SInt32 errorCode) {
    
    auto map = @{
        @(kCFMessagePortSuccess)             : @"Success",
        @(kCFMessagePortSendTimeout)         : @"SendTimeout",
        @(kCFMessagePortReceiveTimeout)      : @"ReceiveTimeout",
        @(kCFMessagePortIsInvalid)           : @"IsInvalid",
        @(kCFMessagePortTransportError)      : @"TransportError",
        @(kCFMessagePortBecameInvalidError)  : @"BecameInvalidError",
    };
    
    return map[@(errorCode)] ?: stringf(@"(%d)", errorCode);
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
    NSObject *response = nil;
    
    /// Handle commands
    ///     Note: [Jul 2025] We're using NSString to identify the commands. I think this is what `SInt32 messageID` is for, but it's nice to be able to debug-print the strings. To replicate that with `SInt32 messageID`, we might wanna use a `FOR_EACH` macro or `X-MACRO` ... or just keep using strings, it works fine.
    
    #define xxx(message_) else if ([message_ isEqual: message])
    
#if IS_MAIN_APP
    
    if ((0)) {}
    xxx(@"addModeFeedback") {
        [MainAppState.shared.buttonTabController handleAddModeFeedbackWithPayload:(NSDictionary *)payload];
    }
    xxx(@"keyCaptureModeFeedback") {
        [KeyCaptureView handleKeyCaptureModeFeedbackWithPayload:(NSDictionary *)payload isSystemDefinedEvent:NO];
    }
    xxx(@"keyCaptureModeFeedbackWithSystemEvent") {
        [KeyCaptureView handleKeyCaptureModeFeedbackWithPayload:(NSDictionary *)payload isSystemDefinedEvent:YES];
    }
    xxx(@"helperEnabledWithNoAccessibility") {
        
        BOOL isStrange = NO;
        if (isavailable(13.0, 15.0)) { if (@available(macOS 13.0, *)) {
            isStrange = [MessagePortUtility.shared checkHelperStrangenessReactWithPayload:payload];
        }}
        if (!isStrange) {
            [AuthorizeAccessibilityView add];
        }
    }
    xxx(@"helperEnabled") {
        
        BOOL isStrange = NO;
        if (isavailable(13.0, 15.0)) { if (@available(macOS 13.0, *)) {
            isStrange = [MessagePortUtility.shared checkHelperStrangenessReactWithPayload:payload];
        }}
        
        if (!isStrange) { /// Helper matches mainApp instance.
            
            /// Bring mainApp for foreground
            /// Notes:
            /// - In some places like when the accessibilitySheet is dismissed, we have other methods for bringing mainApp to the foreground that might be unnecessary now that we're doing this. Edit: We stopped the accessibility enabling code from activating the app.
            /// - (September 2024) activateIgnoringOtherApps: is deprecated under macOS 15.0 Sequoia. (But it still seems to work based on my superficial testing before 3.0.3 release.) TODO: Use new cooperative activation APIs instead. (Article: https://developer.apple.com/documentation/appkit/nsapplication/passing_control_from_one_app_to_another_with_cooperative_activation?language=objc)
            
            [NSApp activateIgnoringOtherApps:YES];
            
            /// Dismiss accessibilitySheet
            ///     This is unnecessary under Ventura since `activateIgnoringOtherApps` will trigger `ResizingTabWindowController.windowDidBecomeMain()` which will also call `[AuthorizeAccessibilityView remove]`. But it's better to be safe and explicit about this.
            [AuthorizeAccessibilityView remove];
            
            /// Notify rest of the app
            [EnabledState.shared reactToDidBecomeEnabled];
        }
        
    }
    xxx(@"helperDisabled") {
        [EnabledState.shared reactToDidBecomeDisabled];
    }
    xxx(@"configFileChanged") {
        [Config loadFileAndUpdateStates];
    }
    xxx(@"showNextToastOrSheetWithSection") {
        BOOL moreToastsToGo = [ToastAndSheetTests showNextTestWithSection:(id)payload]; /// If this is true, we haven't ran out of test-toasts for this section, yet.
        response = @(moreToastsToGo);
    }
    xxx(@"didShowAllToastsAndSheets") {
        BOOL didShowAll = [ToastAndSheetTests didShowAllToastsAndSheets];
        response = @(didShowAll);
    }
    xxx(@"showCaptureToast") {
        NSSet<NSNumber *> *before = ((NSDictionary *)payload)[@"before"];
        NSSet<NSNumber *> *after  = ((NSDictionary *)payload)[@"after"];
        [ToastAndSheetTests showCaptureToastBefore: before after: after];
    }
    else {
        DDLogInfo(@"Unknown message received: %@", message);
    }

#elif IS_HELPER
    
    if ((0)) ;
    xxx(@"configFileChanged") {
        [Config loadFileAndUpdateStates];
    }
    xxx(@"terminate") {
//            [NSApp.delegate applicationWillTerminate:[[NSNotification alloc] init]]; /// This creates an infinite loop or something? The statement below is never executed.
        [NSApp terminate:NULL];
    }
    xxx(@"checkAccessibility") {
        BOOL isTrusted = [AccessibilityCheck checkAccessibilityAndUpdateSystemSettings];
        response = @(isTrusted);
    }
    xxx(@"enableAddMode") {
        BOOL success = [Remap enableAddMode];
        response = @(success);
    }
    xxx(@"disableAddMode") {
        BOOL success = [Remap disableAddMode];
        response = @(success);
    }
    xxx(@"enableKeyCaptureMode") {
        [KeyCaptureMode enable];
    }
    xxx(@"disableKeyCaptureMode") {
        [KeyCaptureMode disable];
    }
    xxx(@"getActiveDeviceInfo") {
        
        Device *dev = HelperState.shared.activeDevice;
        if (dev != NULL) {
            
            response = @{
                @"name": dev.name == nil ? @"" : dev.name,
                @"manufacturer": dev.manufacturer == nil ? @"" : dev.manufacturer,
                @"nOfButtons": @(dev.nOfButtons),
            };
        }
    }
    xxx(@"updateActiveDeviceWithEventSenderID") {
        /// We can't just pass over the CGEvent from the mainApp because the senderID isn't stored when serializing CGEvents
        uint64_t senderID = [(NSNumber *)payload unsignedIntegerValue];
        [HelperState.shared updateActiveDeviceWithEventSenderID:senderID];
    }
    xxx(@"getBundleVersion") {
        response = @(Locator.bundleVersion);
    }
    else {
        DDLogInfo(@"Unknown message received: %@", message);
    }
    
#else
    abort();
#endif
    
    #undef xxx
    
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
            kMFMessageKeyPayload: (id _Nonnull)payload,
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
    ///     Should we retry on timeout? [Oct 2025]
    if (status != 0) {
        DDLogError(@"Non-zero CFMessagePortSendRequest return: %@", CFMessagePortSendRequest_ErrorCode_ToString(status));
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
