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


@implementation MessagePort_App


#pragma mark - local (incoming messages)


+ (void)load {
    
    if (self == [MessagePort_App class]) {
        CFMessagePortRef localPort =
        CFMessagePortCreateLocal(kCFAllocatorDefault,
                             CFSTR("com.nuebling.mousefix.port"),
                             didReceiveMessage,
                             nil,
                             NULL);
        
        // setting the name here instead of when creating the port creates some super weird behavior, too.
//        CFMessagePortSetName(localPort, CFSTR("com.nuebling.mousefix.port"));
        
        // on Catalina, creating the local Port returns NULL and throws a permission denied error. Trying to schedule it with the runloop yields a crash.
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
            // Couldn't set up message port. But it'll probably work anyways for some reason.
        }
    }
}

static CFDataRef didReceiveMessage(CFMessagePortRef port, SInt32 messageID, CFDataRef data, void *info) {
    
    NSDictionary *messageDict = [NSKeyedUnarchiver unarchiveObjectWithData:(__bridge NSData *)data];
    
    NSString *message = messageDict[kMFMessageKeyMessage];
    NSObject *payload = messageDict[kMFMessageKeyPayload];
    
    NSLog(@"Main App Received Message: %@ with payload: %@", message, payload);
    
    if ([message isEqualToString:@"accessibilityDisabled"]) {
        [AuthorizeAccessibilityView add];
        [(AppDelegate *)NSApp.delegate stopRemoveAccOverlayTimer]; // If App delegate is about to remove the acc overlay, stop that
    } else if ([message isEqualToString:@"addModeFeedback"]) {
        [AddWindowController handleReceivedAddModeFeedbackFromHelperWithPayload:(NSDictionary *)payload];
    }
    
    NSData *response = NULL;
    return (__bridge CFDataRef)response;
}

@end
