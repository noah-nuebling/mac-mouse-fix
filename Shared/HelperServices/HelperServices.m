//
// --------------------------------------------------------------------------
// HelperServices.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <AppKit/AppKit.h>
#import "HelperServices.h"
#import "Constants.h"
#import "Objects.h"
#import "SharedUtility.h"

@implementation HelperServices

// Register/unregister the helper as a User Agent with launchd so it runs in the background - also launches/terminates helper
+ (void)enableHelperAsUserAgent:(BOOL)enable {
    
    // Repair/generate launchdPlist so that the following code works for sure
    [self repairLaunchdPlist];
    
    // Prepare strings for NSTask
    
    // Path for the executable of the launchctl command-line-tool, which we use to control launchd
    
    // Prepare arguments for the launchctl command-line-tool
    if (@available(macOS 10.13, *)) {
        NSTask *task = [[NSTask alloc] init];
        task.executableURL = [NSURL fileURLWithPath: kMFLaunchctlPath];
        NSString *GUIDomainArgument = [NSString stringWithFormat:@"gui/%d", geteuid()];
        NSString *OnOffArgument = (enable) ? @"bootstrap": @"bootout";
        NSString *launchdPlistPathArgument = Objects.launchdPlistURL.path;
        task.arguments = @[OnOffArgument, GUIDomainArgument, launchdPlistPathArgument];
        NSPipe *pipe = NSPipe.pipe;
        task.standardError = pipe;
        task.standardOutput = pipe;
        NSError *error;
        task.terminationHandler = ^(NSTask *task) {
            if (enable == NO) { // Cleanup (delete launchdPlist) file after were done // We can't clean up immediately cause then launchctl will fail
                [self cleanup];
            }
            NSLog(@"launchctl terminated with stdout/stderr: %@, error: %@", [NSString.alloc initWithData:pipe.fileHandleForReading.readDataToEndOfFile encoding:NSUTF8StringEncoding], error);
        };
        [task launchAndReturnError:&error];
        
    } else { // Fallback on earlier versions
        NSString *OnOffArgumentOld = (enable) ? @"load": @"unload";
        [NSTask launchedTaskWithLaunchPath: kMFLaunchctlPath arguments: @[OnOffArgumentOld, Objects.launchdPlistURL.path]]; // Can't clean up here easily cause there's no termination handler
    }
}
+ (void)cleanup {
    [NSFileManager.defaultManager removeItemAtURL:Objects.launchdPlistURL error:NULL];
}

+ (void)repairLaunchdPlist {
    
    @autoreleasepool {
        
        NSLog(@"repairing User Agent Config File");
        // What this does:
        
        // Get path of executable of helper app
        // Check if the "User/Library/LaunchAgents/mouse.fix.helper.plist" (< This specific path is deprecated) UserAgent Config file  (aka launchdPlist)
        //      exists, if the Launch Agents Folder exists, and if the exectuable path within the plist file is correct
        // If not:
        // Create correct file based on "default_launchd.plist" and helperExecutablePath
        // Write correct file to "User/Library/LaunchAgents"
        
        // Get helper executable path
        NSBundle *helperBundle = Objects.helperBundle;
        NSBundle *mainAppBundle = Objects.mainAppBundle;
        NSString *helperExecutablePath = helperBundle.executablePath;
        
        // Get path to launch agent config file (aka launchdPlist)
        NSString *launchAgentPlistPath = Objects.launchdPlistURL.path;
        
        // Check if file exists
        NSFileManager *fileManager = [[NSFileManager alloc] init];
        BOOL launchdPlist_exists = [fileManager fileExistsAtPath: launchAgentPlistPath isDirectory: nil];
        BOOL launchdPlist_executablePathIsCorrect = TRUE;
        if (launchdPlist_exists == TRUE) {
            
            // Load data from launch agent config file into a dictionary
            NSData *launchdPlist_data = [NSData dataWithContentsOfFile:launchAgentPlistPath];
            NSDictionary *launchdPlist_dict = [NSPropertyListSerialization propertyListWithData:launchdPlist_data options:NSPropertyListImmutable format:0 error:nil];
            
            // Check if the executable path inside the config file is correct, if not, set flag to false
            NSString *helperExecutablePathFromFile = [launchdPlist_dict objectForKey: @"Program"];
            if ( [helperExecutablePath isEqualToString: helperExecutablePathFromFile] == FALSE ) {
                launchdPlist_executablePathIsCorrect = FALSE;
            }
            //NSLog(@"objectForKey: %@", OBJForKey);
            //NSLog(@"helperExecutablePath: %@", helperExecutablePath);
            //NSLog(@"OBJ == Path: %d", OBJForKey isEqualToString: helperExecutablePath);
        }
        
        NSLog(@"launchdPlistExists %hhd, launchdPlistIsCorrect: %hhd", launchdPlist_exists,launchdPlist_executablePathIsCorrect);
        // The config file doesn't exist, or the executable path within it is not correct
        if ((launchdPlist_exists == FALSE) || (launchdPlist_executablePathIsCorrect == FALSE)) {
            NSLog(@"repairing file...");
            
            // Check if "User/Library/LaunchAgents" folder exists, if not, create it
            NSString *launchAgentsFolderPath = [launchAgentPlistPath stringByDeletingLastPathComponent];
            BOOL launchAgentsFolderExists = [fileManager fileExistsAtPath: launchAgentsFolderPath isDirectory: nil];
            if (launchAgentsFolderExists == FALSE) {
                NSLog(@"LaunchAgentsFolder doesn't exist");
                NSError *error;
                [fileManager createDirectoryAtPath:launchAgentsFolderPath withIntermediateDirectories:FALSE attributes:nil error:&error];
                if (error == nil) {
                    NSLog(@"LaunchAgents Folder Created");
                } else {
                    NSLog(@"Error while creating LaunchAgents Folder: %@", error);
                }
            }
            
            NSError *error;
            
            // Read contents of default_launchd.plist (aka default-launch-agent-config-file or defaultLAConfigFile) into a dictionary
            
            NSString *defaultLaunchdPlist_path = [mainAppBundle pathForResource:@"default_launchd" ofType:@"plist"];
            NSData *defaultlaunchdPlist_data = [NSData dataWithContentsOfFile:defaultLaunchdPlist_path];
            // TODO: This just crashed the app with "Exception: "data parameter is nil". It says that that launchdPlistExists = NO.
            // I was running Mac Mouse Fix Helper standalone for debugging, not embedded in the main app
            NSMutableDictionary *newlaunchdPlist_dict = [NSPropertyListSerialization propertyListWithData:defaultlaunchdPlist_data options:NSPropertyListMutableContainersAndLeaves format:nil error:&error];
            
            // Set the executable path to the correct value
            [newlaunchdPlist_dict setValue: helperExecutablePath forKey:@"Program"];
            
            // Write the dict to launchdPlist
            NSData *newLaunchdPlist_data = [NSPropertyListSerialization dataWithPropertyList:newlaunchdPlist_dict format:NSPropertyListXMLFormat_v1_0 options:0 error:&error];
            NSAssert(error == nil, @"Should not have encountered an error");
            [newLaunchdPlist_data writeToFile:launchAgentPlistPath atomically:YES];
            if (error != nil) {
                NSLog(@"repairUserAgentConfigFile() -- Data Serialization Error: %@", error);
            }
        } else {
            NSLog(@"nothing to repair");
        }
    }
    
}

+ (BOOL)helperIsActive {
    
    // Using NSTask to ask launchd about helper status
    
    NSString *launchctlPath = kMFLaunchctlPath;
    NSString *listArgument = @"list";
    
    NSPipe * launchctlOutput;
    
    if (@available(macOS 10.13, *)) { // macOS version 10.13+
        NSURL *launchctlURL = [NSURL fileURLWithPath: launchctlPath];
        
        NSTask *task = [[NSTask alloc] init];
        [task setExecutableURL: launchctlURL];
        [task setArguments: @[listArgument, kMFLaunchdHelperIdentifier] ];
        launchctlOutput = [NSPipe pipe];
        [task setStandardOutput: launchctlOutput];
        
        [task launchAndReturnError:nil];
    } else { // Fallback on earlier versions
        NSTask *task = [[NSTask alloc] init];
        [task setLaunchPath: launchctlPath];
        [task setArguments: @[listArgument, kMFLaunchdHelperIdentifier] ];
        launchctlOutput = [NSPipe pipe];
        [task setStandardOutput: launchctlOutput];
        
        [task launch];
    }
    
    NSFileHandle *launchctlOutput_fileHandle = [launchctlOutput fileHandleForReading];
    NSData *launchctlOutput_data = [launchctlOutput_fileHandle readDataToEndOfFile];
    NSString *launchctlOutput_string = [[NSString alloc] initWithData:launchctlOutput_data encoding:NSUTF8StringEncoding];
    
    NSString *labelSearchString = fstring(@"\"Label\" = \"%@\";", kMFLaunchdHelperIdentifier);
    NSString *prefPaneSearchString = @"/PreferencePanes/Mouse Fix.prefPane/Contents/Library/LoginItems/Mouse Fix Helper.app/Contents/MacOS/Mouse Fix Helper";
    
    BOOL labelFound = [launchctlOutput_string rangeOfString: labelSearchString].location != NSNotFound;
    BOOL exitStatusIsZero = [launchctlOutput_string rangeOfString: @"\"LastExitStatus\" = 0;"].location != NSNotFound; // Not sure if useful
    BOOL isInPrefpane = [launchctlOutput_string rangeOfString:prefPaneSearchString].location != NSNotFound;
    
    if (labelFound && isInPrefpane) { // Prefpane helper is running
        NSLog(@"Found helper running in prefpane. Removing it from launchd and closing it.");
         // Just kill helper. Doing this here is not the cleanest solution, but it should be fine.
        [self enableHelperAsUserAgent:NO];
    }
    
    if (labelFound && exitStatusIsZero && !isInPrefpane) { // Why check for exit status here?
        NSLog(@"MOUSE REMAPOR FOUNDD AND ACTIVE");
        return TRUE;
    } else {
        NSLog(@"Helper is not active");
        return FALSE;
    }
    
}

@end
