//
//  Mouse_Remap.m
//  Mouse Remap
//
//  Created by Noah Nübling on 09.08.18.
//  Copyright © 2018 Noah Nuebling Enterprises Ltd. All rights reserved.
//

//#import <ServiceManagement/ServiceManagement.h>
#import <ServiceManagement/SMLoginItem.h>
#import "Mouse_Remap.h"

@implementation Mouse_Remap

/*
+ (void)startHelper {
    NSURL *helperURL = [[[NSBundle mainBundle] bundleURL] URLByAppendingPathComponent:@"Contents/Library/LoginItems/YourHelper.app" isDirectory:YES];
    OSStatus status = LSRegisterURL((CFURLRef)helperURL, YES);
    if (status != noErr) {
        NSLog(@"Failed to LSRegisterURL '%@': %jd", helperURL, (intmax_t)status);
    }
    
    
    Boolean success = SMLoginItemSetEnabled(CFSTR("com.yourcompany.helper-CFBundleIdentifier-here"), YES);
    if (!success) {
        NSLog(@"Failed to start Helper");
    }
}

*/

- (void) startHelper {
    
    // get file URL for helper
    CFURLRef helperURL = (__bridge CFURLRef) [[[NSBundle bundleForClass: [Mouse_Remap class]] bundleURL] URLByAppendingPathComponent:@"Contents/Library/LoginItems/Mouse Remap Helper.app" isDirectory: false];
    
    // Launch Helper
    LSOpenCFURLRef(helperURL, nil);
    
}

- (void) terminateHelper {

    // get NSRunningApplication object for helper App
    NSArray<NSRunningApplication *> *helperApp_NSRunningApplicationArray = [NSRunningApplication runningApplicationsWithBundleIdentifier:(@"com.uebler.nuebler.Mouse-Remap-Helper")];
    
    // terminate helper if it's already running
    if (helperApp_NSRunningApplicationArray != nil && [helperApp_NSRunningApplicationArray count] != 0) {
        [helperApp_NSRunningApplicationArray[0] terminate];
    }
}


- (void)enableHelper: (BOOL) enable {
    
    // registering/unregistering the helper as a User Agent with launchd
    
    
    /* preparing string for NSTask */
    
    
    
    // path for the executable of a command-line-tool that can interface with launchd //
    
    NSString *launchctlPath = @"/bin/launchctl";
    
    
    
    // arguments for the command line tool //
    
    // set to "bootstrap" if we want to enable mouse remap helper, and to "bootout" if we want to disable it
    NSString *OnOffArgument = (enable) ? @"bootstrap": @"bootout";
    // specifies that the target domain is the current users "gui" domain
    NSString *GUIDomainArgument = [NSString stringWithFormat:@"gui/%d", geteuid()];
    // path to user agent config file for the mouse remap helper
    NSString *userAgentConfigFilePath = @"/Users/Noah/Library/LaunchAgents/mouse.remap.helper.plist";
    
    
    
    // load/unload helper as a user agent
    // (this launches/terminates the helper immediately, and registers/unregisters the helper to always be run while the user is logged in)
    
    // macOS version 10.13+
    if (@available(macOS 10.13, *)) {
        NSURL *launchctlURL = [NSURL fileURLWithPath: launchctlPath];
        
        [NSTask launchedTaskWithExecutableURL: launchctlURL arguments:@[OnOffArgument, GUIDomainArgument, userAgentConfigFilePath] error: nil terminationHandler: nil];
    } else {
        // Fallback on earlier versions
        
        [NSTask launchedTaskWithLaunchPath: launchctlPath arguments: @[OnOffArgument, GUIDomainArgument, userAgentConfigFilePath] ];
    }
}



- (void)mainViewDidLoad {
    
    
    
    NSLog(@"PREF PANEEE");
    
    [self terminateHelper];
    [self startHelper];
    [self enableHelper: TRUE];
    
}


    


@end
