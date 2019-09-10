
//
//  HelperInterface.m
//  Mouse Fix
//
//  Created by Noah Nübling on 29.08.19.
//  Copyright © 2019 Noah Nuebling. All rights reserved.
//

#import "HelperServices.h"
#import "PrefPaneDelegate.h"

@implementation HelperServices

+ (NSBundle *)helperBundle {
    NSBundle *prefPaneBundle = [NSBundle bundleForClass: [PrefPaneDelegate class]];
    NSString *prefPaneBundlePath = [prefPaneBundle bundlePath];
    NSString *helperBundlePath = [prefPaneBundlePath stringByAppendingPathComponent: @"Contents/Library/LoginItems/Mouse Fix Helper.app"];
    return [NSBundle bundleWithPath:helperBundlePath];
}

+ (BOOL) helperIsRunning {
    if ([NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.nuebling.mousefix.helper"].count == 0) {
        return NO;
    } else {
        return YES;
    }
}

//+ (BOOL)helperIsActive {
//
//    // using NSTask to ask launchd about mouse.fix.helper status
//
//    NSString *launchctlPath = @"/bin/launchctl";
//    NSString *listArgument = @"list";
//    NSString *launchdHelperIdentifier = @"mouse.fix.helper";
//
//    NSPipe * launchctlOutput;
//
//    // macOS version 10.13+
//
//    if (@available(macOS 10.13, *)) {
//        NSURL *launchctlURL = [NSURL fileURLWithPath: launchctlPath];
//
//        NSTask *task = [[NSTask alloc] init];
//        [task setExecutableURL: launchctlURL];
//        [task setArguments: @[listArgument, launchdHelperIdentifier] ];
//        launchctlOutput = [NSPipe pipe];
//        [task setStandardOutput: launchctlOutput];
//
//        [task launchAndReturnError:nil];
//
//    } else {
//
//        // Fallback on earlier versions
//
//        NSTask *task = [[NSTask alloc] init];
//        [task setLaunchPath: launchctlPath];
//        [task setArguments: @[listArgument, launchdHelperIdentifier] ];
//        launchctlOutput = [NSPipe pipe];
//        [task setStandardOutput: launchctlOutput];
//
//        [task launch];
//
//    }
//
//
//    NSFileHandle * launchctlOutput_fileHandle = [launchctlOutput fileHandleForReading];
//    NSData * launchctlOutput_data = [launchctlOutput_fileHandle readDataToEndOfFile];
//    NSString * launchctlOutput_string = [[NSString alloc] initWithData:launchctlOutput_data encoding:NSUTF8StringEncoding];
//    if (
//        [launchctlOutput_string rangeOfString: @"\"Label\" = \"mouse.fix.helper\";"].location != NSNotFound &&
//        [launchctlOutput_string rangeOfString: @"\"LastExitStatus\" = 0;"].location != NSNotFound
//        )
//    {
//        NSLog(@"MOUSE REMAPOR FOUNDD AND ACTIVE");
//        return TRUE;
//    }
//    else {
//        return FALSE;
//    }
//
//}



@end
