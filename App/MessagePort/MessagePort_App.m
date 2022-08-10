//
// --------------------------------------------------------------------------
// MessagePort_App.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "MessagePort_App.h"
#import "AuthorizeAccessibilityView.h"
#import <Foundation/Foundation.h>
#import "AppDelegate.h"
#import "Constants.h"
#import "RemapTableController.h"
#import "AddWindowController.h"
#import "KeyCaptureView.h"
#import "WannabePrefixHeader.h"
#import "Mac_Mouse_Fix-Swift.h"

@implementation MessagePort_App


#pragma mark - local (incoming messages)

/// We used to do this in `load` but that lead to issues when restarting the app if it's translocated
/// If the app detects that it is translocated, it will restart itself at the untranslocated location,  after removing the quarantine flags from itself. It starts a copy of itself while it's still running, and only then does it terminate itself. If the message port is already 'claimed' by the translocated instances when it starts the untranslocated copy, then the untranslocated copy can't 'claim' the message port for itself, which leads to things like the accessiblity screen not working.
/// I hope thinik moving using `initialize' instead of `load` within `MessagePort_App` should fix this and work just fine for everything else. I don't know why we used load to begin with.
/// Edit: I don't remember why we moved to load_Manual now, but it works fine

+ (void)load_Manual {
    
    if (self == [MessagePort_App class]) { // This shouldn't be necessary, now that we're not using initialize anymore
        
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
}

static CFDataRef didReceiveMessage(CFMessagePortRef port, SInt32 messageID, CFDataRef data, void *info) {
    
    NSDictionary *messageDict = [NSKeyedUnarchiver unarchiveObjectWithData:(__bridge NSData *)data];
    
    NSString *message = messageDict[kMFMessageKeyMessage];
    NSObject *payload = messageDict[kMFMessageKeyPayload];
    
    DDLogInfo(@"Main App Received Message: %@ with payload: %@", message, payload);
    
    if ([message isEqualToString:@"accessibilityDisabled"]) {
        [(ResizingTabWindowController *)MainAppState.shared.window.windowController handleAccessibilityDisabledMessage]; /// If App delegate is about to remove the acc overlay, stop that
    } else if ([message isEqualToString:@"addModeFeedback"]) {
        [AddWindowController handleReceivedAddModeFeedbackFromHelperWithPayload:(NSDictionary *)payload];
    } else if ([message isEqualToString:@"keyCaptureModeFeedback"]) {
        [KeyCaptureView handleKeyCaptureModeFeedbackWithPayload:(NSDictionary *)payload isSystemDefinedEvent:NO];
    } else if ([message isEqualToString:@"keyCaptureModeFeedbackWithSystemEvent"]) {
        [KeyCaptureView handleKeyCaptureModeFeedbackWithPayload:(NSDictionary *)payload isSystemDefinedEvent:YES];
    } else if ([message isEqualToString:@"helperEnabled"]) {
        [AppDelegate handleHelperEnabledMessage];
        [EnabledState.shared reactToDidBecomeEnabled];
    }
    
    NSData *response = NULL;
    return (__bridge CFDataRef)response;
}

@end
