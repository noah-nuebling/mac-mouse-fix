//
// --------------------------------------------------------------------------
// SharedMessagePort.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

#import "SharedMessagePort.h"
#import <Cocoa/Cocoa.h>
#import "Constants.h"
#import "SharedUtility.h"
#import "Locator.h"
#import "HelperServices.h"

#if IS_MAIN_APP
#import "Mac_Mouse_Fix-Swift.h"
#import "KeyCaptureView.h"
#endif

#if IS_HELPER
#import "Mac_Mouse_Fix_Helper-Swift.h"
#import "AccessibilityCheck.h"
#endif

@implementation SharedMessagePort

#pragma mark - Receiving messages



#pragma mark Setup port

+ (void)load_Manual {
    
    
#if IS_MAIN_APP
    
    /// We used to do this in `load` but that lead to issues when restarting the app if it's translocated
    /// If the app detects that it is translocated, it will restart itself at the untranslocated location,  after removing the quarantine flags from itself. It starts a copy of itself while it's still running, and only then does it terminate itself. If the message port is already 'claimed' by the translocated instances when it starts the untranslocated copy, then the untranslocated copy can't 'claim' the message port for itself, which leads to things like the accessiblity screen not working.
    /// I hope thinik moving using `initialize' instead of `load` within `MessagePort_App` should fix this and work just fine for everything else. I don't know why we used load to begin with.
    /// Edit: I don't remember why we moved to load_Manual now, but it works fine
    
    if (self == [SharedMessagePort class]) { /// This shouldn't be necessary, now that we're not using initialize anymore
        
        DDLogInfo(@"Initializing MessagePort...");
        
        CFMessagePortRef localPort =
        CFMessagePortCreateLocal(kCFAllocatorDefault,
                             (__bridge CFStringRef)kMFBundleIDApp,
                             didReceiveMessage,
                             nil,
                             NULL);
        
        // Setting the name here instead of when creating the port creates some super weird behavior, too.
//        CFMessagePortSetName(localPort, CFSTR("com.nuebling.mousefix.port"));
        
        // On Catalina, creating the local Port returns NULL and throws a permission denied error. Trying to schedule it with the runloop yields a crash.
        // But even if you just skip the runloop scheduling it still works somehow!
        if (localPort != NULL) {
            // Could set up message port. Scheduling with run loop.
            CFRunLoopSourceRef runLoopSource =
                CFMessagePortCreateRunLoopSource(kCFAllocatorDefault, localPort, 0);
            
            CFRunLoopAddSource(CFRunLoopGetMain(),
                               runLoopSource,
                               kCFRunLoopCommonModes);
            CFRelease(runLoopSource);
        } else {
            DDLogInfo(@"Failed to create a local message port. It will probably work anyway for some reason");
        }
    }
    
#endif
    
#if IS_HELPER
    
    /// I'm not sure this is supposed to be load_Manual instead of load
    
    DDLogInfo(@"Initializing MessagePort...");
    
    CFMessagePortRef localPort =
    CFMessagePortCreateLocal(NULL,
                             (__bridge CFStringRef)kMFBundleIDHelper,
                             didReceiveMessage,
                             nil,
                             nil);
    
    DDLogInfo(@"localPort: %@ (MessagePortReceiver)", localPort);
    
    if (localPort != NULL) {
        /// CFMessagePortCreateRunLoopSource() used to crash when another instance of MMF Helper was already running.
        /// It would log this: `*** CFMessagePort: bootstrap_register(): failed 1100 (0x44c) 'Permission denied', port = 0x1b03, name = 'com.nuebling.mac-mouse-fix.helper'`
        /// I think the reason for this messate is that the existing instance would already 'occupy' the kMFBundleIDHelper name.
        /// Checking if `localPort != nil` should detect this case
    
        CFRunLoopSourceRef runLoopSource =
            CFMessagePortCreateRunLoopSource(kCFAllocatorDefault, localPort, 0);
        
        CFRunLoopAddSource(CFRunLoopGetCurrent(),
                           runLoopSource,
                           kCFRunLoopCommonModes);
        
        CFRelease(runLoopSource);
    } else {
        DDLogError(@"Failed to create a local message port. This might be because there is another instance of %@ already running. Crashing the app.", kMFHelperName);
        @throw [NSException exceptionWithName:@"NoMessagePortException" reason:@"Couldn't create a local CFMessagePort. Can't function properly without local CFMessagePort" userInfo:nil];
    }
    
#endif
}

#pragma mark Handle incoming messages

static CFDataRef _Nullable didReceiveMessage(CFMessagePortRef port, SInt32 messageID, CFDataRef data, void *info) {
    
    
#if IS_MAIN_APP
    
    NSDictionary *messageDict = [NSKeyedUnarchiver unarchiveObjectWithData:(__bridge NSData *)data];
    
    NSString *message = messageDict[kMFMessageKeyMessage];
    NSObject *payload = messageDict[kMFMessageKeyPayload];
    NSInteger helperVersion = [messageDict[kMFMessageKeyBundleVersion] integerValue];
    
    NSInteger appVersion = Locator.bundleVersion;
    
    if (appVersion != helperVersion) {
        
        DDLogError(@"Main App Received Message From Strange Helper: %@ with payload: %@, helperVersion: %ld, appVersion: %ld. Killing the strange helper.", message, payload, helperVersion, appVersion);
        
        /// Kill the strange helper
        ///
        /// Notes:
        /// - Not sure if just using `enableHelperAsUserAgent:` is enough. Does this call `launchctl remove`? Does it kill strange helpers that weren't started by launchd? That might be necessary in some situations.
        /// - In Ventura 13.0, SMAppService has strange bugs where it will always start an old version of MMF until you delete the old version, empty the trash, then restart computer and then try again. Was hoping this would be fixed but it's still there after the 13.0 Beta.
        ///     -> We should probably give the user instructions on how to fix things, when this situation occurs.
        
        [HelperServices enableHelperAsUserAgent:NO onComplete:nil];
        
        return NULL;
    }
    
    DDLogInfo(@"Main App Received Message: %@ with payload: %@", message, payload);
    
    if ([message isEqualToString:@"accessibilityDisabled"]) {
        [(ResizingTabWindowController *)MainAppState.shared.window.windowController handleAccessibilityDisabledMessage]; /// If App delegate is about to remove the acc overlay, stop that
    } else if ([message isEqualToString:@"addModeFeedback"]) {
        [MainAppState.shared.buttonTabController handleReceivedAddModeFeedbackFromHelperWithPayload:(NSDictionary *)payload];
    } else if ([message isEqualToString:@"keyCaptureModeFeedback"]) {
        [KeyCaptureView handleKeyCaptureModeFeedbackWithPayload:(NSDictionary *)payload isSystemDefinedEvent:NO];
    } else if ([message isEqualToString:@"keyCaptureModeFeedbackWithSystemEvent"]) {
        [KeyCaptureView handleKeyCaptureModeFeedbackWithPayload:(NSDictionary *)payload isSystemDefinedEvent:YES];
    } else if ([message isEqualToString:@"helperEnabled"]) {
        //        [AppDelegate handleHelperEnabledMessage]; /// Old MMF2 stuff
        [EnabledState.shared reactToDidBecomeEnabled];
    } else if ([message isEqualToString:@"helperDisabled"]) {
        [EnabledState.shared reactToDidBecomeDisabled];
    } else if ([message isEqualToString:@"configFileChanged"]) {
        [Config handleConfigFileChange];
    }
    
    return NULL;
    
#endif
    
#if IS_HELPER
    
    NSDictionary *messageDict = [NSKeyedUnarchiver unarchiveObjectWithData:(__bridge NSData *)data];
    
    NSString *message = messageDict[kMFMessageKeyMessage];
    NSObject *payload = messageDict[kMFMessageKeyPayload];
    NSInteger appVersion = [messageDict[kMFMessageKeyBundleVersion] integerValue];
    
    NSInteger helperVersion = Locator.bundleVersion;
    
    if (appVersion != helperVersion) {
        DDLogError(@"Helper Received Message From Strange Main App: %@ with payload: %@, appVersion: %ld, helperVersion: %ld", message, payload, appVersion, helperVersion);
        return NULL;
    }
    
    NSObject *response = nil;
    
    DDLogInfo(@"Helper Received Message: %@ with payload: %@", message, payload);
    
    if ([message isEqualToString:@"configFileChanged"]) {
        [Config handleConfigFileChange];
    } else if ([message isEqualToString:@"terminate"]) {
//        [NSApp.delegate applicationWillTerminate:[[NSNotification alloc] init]]; /// This creates an infinite loop or something? The statement below is never executed.
        [NSApp terminate:NULL];
    } else if ([message isEqualToString:@"checkAccessibility"]) {
        BOOL isTrusted = [AccessibilityCheck checkAccessibilityAndUpdateSystemSettings];
        if (!isTrusted) {
            [SharedMessagePort sendMessage:@"accessibilityDisabled" withPayload:nil expectingReply:NO];
        }
    } else if ([message isEqualToString:@"enableAddMode"]) {
        [TransformationManager enableAddMode];
    } else if ([message isEqualToString:@"disableAddMode"]) {
        [TransformationManager disableAddMode];
    } else if ([message isEqualToString:@"enableKeyCaptureMode"]) {
        [TransformationManager enableKeyCaptureMode];
    } else if ([message isEqualToString:@"disableKeyCaptureMode"]) {
        [TransformationManager disableKeyCaptureMode];
    } else if ([message isEqualToString:@"getActiveDeviceInfo"]) {
        Device *dev = HelperState.activeDevice;
        if (dev != NULL) {
            
            response = @{
                @"name": dev.name == nil ? @"" : dev.name,
                @"manufacturer": dev.manufacturer == nil ? @"" : dev.manufacturer,
                @"nOfButtons": @(dev.nOfButtons),
            };
        }
    } else if ([message isEqualToString:@"updateActiveDeviceWithEventSenderID"]) {
        
        /// We can't just pass over the CGEvent from the mainApp because the senderID isn't stored when serializing CGEvents
        
        uint64_t senderID = [(NSNumber *)payload unsignedIntegerValue];
        [HelperState updateActiveDeviceWithEventSenderID:senderID];
        
    } else if ([message isEqualToString:@"isActive"]) {
        response = @(YES);
    } else {
        DDLogInfo(@"Unknown message received: %@", message);
    }
    
    if (response != nil) {
         return (__bridge_retained CFDataRef)[NSKeyedArchiver archivedDataWithRootObject:response];
     }

     return NULL;
    
#endif
    
    
}

#pragma mark - Sending messages

static CFMessagePortRef _Nullable createRemotePort() {

    /// Note: We can't just create the port once and cache it, trying to send with that port will yield ``kCFMessagePortIsInvalid``.
    
    NSString *remotePortName;
    if (SharedUtility.runningMainApp) {
        remotePortName = kMFBundleIDHelper;
    } else if (SharedUtility.runningHelper) {
        remotePortName = kMFBundleIDApp;
    }

    CFMessagePortRef remotePort = CFMessagePortCreateRemote(kCFAllocatorDefault, (__bridge CFStringRef)remotePortName);
    
    if (remotePort != NULL) {
        CFMessagePortSetInvalidationCallBack(remotePort, invalidationCallback);
    }

    return remotePort;
}

+ (NSObject *_Nullable)sendMessage:(NSString * _Nonnull)message withPayload:(NSObject <NSCoding> * _Nullable)payload expectingReply:(BOOL)replyExpected { // TODO: Consider renaming last arg to `expectingReturn`
    
    CFMessagePortRef remotePort = createRemotePort();
    if (remotePort == NULL) {
        
        DDLogInfo(@"Can't send message \'%@\', because there is no CFMessagePort", message);
        return nil;
    }

    NSDictionary *messageDict;
    if (payload) {
        messageDict = @{
            kMFMessageKeyMessage: message,
            kMFMessageKeyPayload: payload, /// This crashes if payload is nil for some reason
            kMFMessageKeyBundleVersion: @(Locator.bundleVersion),
        };
    } else {
        messageDict = @{
            kMFMessageKeyMessage: message,
            kMFMessageKeyBundleVersion: @(Locator.bundleVersion),
        };
    }
    
    DDLogInfo(@"Sending message: %@ with payload: %@ from bundle: %@ via message port", message, payload, NSBundle.mainBundle.bundleIdentifier);
    
    SInt32 messageID = 0x420666; /// Arbitrary
    CFDataRef messageData = (__bridge CFDataRef)[NSKeyedArchiver archivedDataWithRootObject:messageDict];
    CFTimeInterval sendTimeout = 0.0;
    CFTimeInterval recieveTimeout = 0.0;
    CFStringRef replyMode = NULL;
    CFDataRef returnData = NULL;
    if (replyExpected) {
//        sendTimeout = 1.0;
        recieveTimeout = 1.0;
        replyMode = kCFRunLoopDefaultMode;
    }

    SInt32 status = CFMessagePortSendRequest(remotePort, messageID, messageData, sendTimeout, recieveTimeout, replyMode, &returnData);
    CFRelease(remotePort);
    
    if (status != 0) {
        DDLogError(@"Non-zero CFMessagePortSendRequest status: %d", status);
        return nil;
    }
    
    NSObject *returnObject = nil;
    if (returnData != NULL && replyExpected /*&& status == 0*/) {
        returnObject = [NSKeyedUnarchiver unarchiveObjectWithData:(__bridge NSData *)returnData];
    }
    
    return returnObject;
}

void invalidationCallback(CFMessagePortRef ms, void *info) {
    
    DDLogInfo(@"SharedMessagePort invalidated in %@", SharedUtility.runningHelper ? @"Helper" : @"MainApp");
}

//+ (CFDataRef _Nullable)sendMessage:(NSString *_Nonnull)message expectingReply:(BOOL)expectingReply {
//
//    DDLogInfo(@"Sending message: %@ via message port from bundle: %@", message, NSBundle.mainBundle);
//
//    CFMessagePortRef remotePort = CFMessagePortCreateRemote(kCFAllocatorDefault, CFSTR("com.nuebling.mousefix.helper.port"));
//    if (remotePort == NULL) {
//        DDLogInfo(@"There is no CFMessagePort");
//        return nil;
//    }
//
//    SInt32 messageID = 0x420666; // Arbitrary
//    CFDataRef messageData = (__bridge CFDataRef)[message dataUsingEncoding:kUnicodeUTF8Format];
//    CFTimeInterval sendTimeout = 0.0;
//    CFTimeInterval receiveTimeout = 0.0;
//    CFStringRef replyMode = NULL;
//    CFDataRef returnData;
//    if (expectingReply) {
//        receiveTimeout = 0.1; // 1.0
//        replyMode = kCFRunLoopDefaultMode;
//    }
//    SInt32 status = CFMessagePortSendRequest(remotePort, messageID, messageData, sendTimeout, receiveTimeout, replyMode, &returnData);
//    if (status != 0) {
//        DDLogInfo(@"Non-zero CFMessagePortSendRequest status: %d", status);
//    }
//    CFRelease(remotePort);
//
//    return returnData;
//}

@end
