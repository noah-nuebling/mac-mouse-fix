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

/// Register/unregister the helper as a User Agent with launchd so it runs in the background - also launches/terminates helper
+ (void)enableHelperAsUserAgent:(BOOL)enable {
    
    // Repair/generate launchdPlist so that the following code works for sure
    [self repairLaunchdPlist];
    
    // If an old version of Mac Mouse Fix is still running and stuff, clean that up to prevent issues
    [self runPreviousVersionCleanup];
    
    /**
         Sometimes there's a weird bug where the main app won't recognize the helper as enabled even though it is. The code down below for enabling will then fail, when the user tries to check the enable checkbox.
         So we're removing the helper from launchd before trying to enable to hopefully fix this. Edit: seems to fix it!
         I'm pretty sure that if we didn't check for `launchdPathIsBundlePath` in `strangeHelperIsRegisteredWithLaunchd` this issue wouldn't have occured and we wouldn't need this workaround. But I'm not sure anymore why we do that so it's not smart to remove it.
         Edit: I think the specific issue I saw only happens when there are two instances of MMF open at the same time.
     */
    if (enable) {
        [self removeHelperFromLaunchd];
        
        // Any Mac Mouse Fix Helper processes that were started by launchd should have been quit by now. But if there are Helpers which weren't started by launchd they will still be running which causes problems. Terminate them now.
        [self terminateOtherHelperInstances];
    }
    
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
            DDLogInfo(@"launchctl terminated with stdout/stderr: %@, error: %@", [NSString.alloc initWithData:pipe.fileHandleForReading.readDataToEndOfFile encoding:NSUTF8StringEncoding], error);
        };
        [task launchAndReturnError:&error];
        
    } else { // Fallback on earlier versions
        NSString *OnOffArgumentOld = (enable) ? @"load": @"unload";
        [NSTask launchedTaskWithLaunchPath: kMFLaunchctlPath arguments: @[OnOffArgumentOld, Objects.launchdPlistURL.path]]; // Can't clean up here easily cause there's no termination handler
    }
}
+ (void)cleanup { // TODO: Make this a c function to signify private nature of it
    [NSFileManager.defaultManager removeItemAtURL:Objects.launchdPlistURL error:NULL];
}

+ (void)repairLaunchdPlist {
    
    @autoreleasepool {
        
        DDLogInfo(@"repairing User Agent Config File");
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
            //DDLogInfo(@"objectForKey: %@", OBJForKey);
            //DDLogInfo(@"helperExecutablePath: %@", helperExecutablePath);
            //DDLogInfo(@"OBJ == Path: %d", OBJForKey isEqualToString: helperExecutablePath);
        }
        
        DDLogInfo(@"launchdPlistExists %hhd, launchdPlistIsCorrect: %hhd", launchdPlist_exists,launchdPlist_executablePathIsCorrect);
        // The config file doesn't exist, or the executable path within it is not correct
        if ((launchdPlist_exists == FALSE) || (launchdPlist_executablePathIsCorrect == FALSE)) {
            DDLogInfo(@"repairing file...");
            
            // Check if "User/Library/LaunchAgents" folder exists, if not, create it
            NSString *launchAgentsFolderPath = [launchAgentPlistPath stringByDeletingLastPathComponent];
            BOOL launchAgentsFolderExists = [fileManager fileExistsAtPath: launchAgentsFolderPath isDirectory: nil];
            if (launchAgentsFolderExists == FALSE) {
                DDLogInfo(@"LaunchAgentsFolder doesn't exist");
                NSError *error;
                [fileManager createDirectoryAtPath:launchAgentsFolderPath withIntermediateDirectories:FALSE attributes:nil error:&error];
                if (error == nil) {
                    DDLogInfo(@"LaunchAgents Folder Created");
                } else {
                    DDLogInfo(@"Error while creating LaunchAgents Folder: %@", error);
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
                DDLogInfo(@"repairUserAgentConfigFile() -- Data Serialization Error: %@", error);
            }
        } else {
            DDLogInfo(@"nothing to repair");
        }
    }
    
}

+ (NSString *)helperInfoFromLaunchd {
    
    // Using NSTask to ask launchd about helper status
    NSURL *launchctlURL = [NSURL fileURLWithPath: kMFLaunchctlPath];
    NSString * launchctlOutput = [SharedUtility launchCTL:launchctlURL withArguments:@[@"list", kMFLaunchdHelperIdentifier] error:nil];
    return launchctlOutput;
}

+ (BOOL)helperIsActive {
    
    // Get info from launchd
    
    NSString *launchctlOutput = [self helperInfoFromLaunchd];
    
    // Analyze info
    
    // Check if label exists. This should always be found if the helper is registered with launchd. Or equavalently, if the output isn't "Could not find service "mouse.fix.helper" in domain for port"
    NSString *labelSearchString = stringf(@"\"Label\" = \"%@\";", kMFLaunchdHelperIdentifier);
    BOOL labelFound = [launchctlOutput rangeOfString: labelSearchString].location != NSNotFound;
    
    // Check exit status. Not sure if useful
    BOOL exitStatusIsZero = [launchctlOutput rangeOfString: @"\"LastExitStatus\" = 0;"].location != NSNotFound;
    
    if (self.strangeHelperIsRegisteredWithLaunchd) {
        DDLogInfo(@"Found helper running somewhere else.");
        return NO;
    }
    
    if (labelFound && exitStatusIsZero) { // Why check for exit status here?
        DDLogInfo(@"MOUSE REMAPOR FOUNDD AND ACTIVE");
        return YES;
    } else {
        DDLogInfo(@"Helper is not active");
        return NO;
    }
    
}

#pragma mark - Clean up legacy stuff

+ (void)runPreviousVersionCleanup {
    
    DDLogDebug(@"Cleaning up stuff from previous versions");
    
    if (self.strangeHelperIsRegisteredWithLaunchd) {
        [self removeHelperFromLaunchd];
    }
    
    [self removeLegacyLaunchdPlist];
    // ^ Could also do this in the if block but users have been having some weirdd issues after upgrading to the app version and I don't know why. I feel like this might make things slightly more robust.
}

/// Check if helper is registered with launchd from some other location
+ (BOOL)strangeHelperIsRegisteredWithLaunchd {
    
    NSString *launchdPath = [self helperExecutablePathFromLaunchd];
    BOOL launchdPathExists = launchdPath.length != 0;
    
    BOOL launchdPathIsBundlePath = [Objects.helperBundle.executablePath isEqual:launchdPath];
    
    if (!launchdPathIsBundlePath && launchdPathExists) {
        
        DDLogDebug(@"Strange helper: found at: %@ \nbundleExecutable at: %@", launchdPath, Objects.helperBundle.executablePath);
        return YES;
    }
    
    DDLogDebug(@"Strange Helper: not found");
    
    return NO;
}

+ (void)terminateOtherHelperInstances {
    /// Terminate any other running instances of the app
    /// Only call this after after removing the Helper from launchd
    /// This only works to terminate instances of the Helper which weren't started by launchd.
    /// Launchd-started instances will immediately be restarted after they are terminated
    /// This is almost an exact copy from Mac Mouse Fix Accomplice
    
    NSLog(@"Terminating other Helper instances");
    
    NSArray<NSRunningApplication *> *instances = [NSRunningApplication runningApplicationsWithBundleIdentifier:kMFBundleIDHelper];
    
    NSLog(@"%lu other running Helper instances found", (unsigned long)instances.count);
        
    for (NSRunningApplication *instance in instances) {
        [instance terminate]; // Consider using forceTerminate instead
    }
}

/// Remove currently running helper from launchd
/// From my testing this does the same as the `bootout` command, but it doesn't rely on a valid launchd.plist file to exist in the library, so it should be more robust.
+ (void)removeHelperFromLaunchd {
    
    DDLogDebug(@"Removing Helper from launchd");
    
    NSURL *launchctlURL = [NSURL fileURLWithPath:kMFLaunchctlPath];
    NSError *err;
    [SharedUtility launchCTL:launchctlURL withArguments:@[@"remove", kMFLaunchdHelperIdentifier] error:&err];
    if (err != nil) {
        DDLogInfo(@"Error removing Helper from launchd: %@", err);
    }
}

/// Remove legacy launchd plist file if it exists
/// The launchd plist file used to be at `~/Library/LaunchAgents/com.nuebling.mousefix.helper.plist` when the app was still a prefpane
/// Now, with the app version, it's moved to `~/Library/LaunchAgents/com.nuebling.mac-mouse-fix.helper.plist`
/// Having the old version still can lead to the old helper being started at startup, and I think other conflicts, too.
+ (void)removeLegacyLaunchdPlist {
    
    DDLogDebug(@"Removing legacy launchd plist");
    
    // Find user library
    NSArray<NSString *> *libraryPaths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    assert(libraryPaths.count == 1);
    NSMutableString *libraryPath = libraryPaths.firstObject.mutableCopy;
    NSString *legacyLaunchdPlistPath = [libraryPath stringByAppendingPathComponent:@"LaunchAgents/com.nuebling.mousefix.helper.plist"];
    NSError *err;
    // Remove old file
    if ([NSFileManager.defaultManager fileExistsAtPath:legacyLaunchdPlistPath]) {
        [NSFileManager.defaultManager removeItemAtPath:legacyLaunchdPlistPath error:&err];
        if (err) {
            DDLogInfo(@"Error while removing legacy launchd plist file: %@", err);
        }
    } else  {
        DDLogInfo(@"No legacy launchd plist file found at: %@", legacyLaunchdPlistPath);
    }
}

+ (NSString *)helperExecutablePathFromLaunchd {
    
    // Using NSTask to ask launchd about helper status
    NSString * launchctlOutput = [self helperInfoFromLaunchd];
    
    NSString *executablePathRegEx = @"(?<=\"Program\" = \").*(?=\";)";
    //    NSRegularExpression executablePathRegEx =
    NSRange executablePathRange = [launchctlOutput rangeOfString:executablePathRegEx options:NSRegularExpressionSearch];
    if (executablePathRange.location == NSNotFound) return @"";
    NSString *executablePath = [launchctlOutput substringWithRange:executablePathRange];
    
    return executablePath;
}

// Example output of the `launchctl list mouse.fix.helper` command

/*
 {
     "StandardOutPath" = "/dev/null";
     "LimitLoadToSessionType" = "Aqua";
     "StandardErrorPath" = "/dev/null";
     "MachServices" = {
         "com.nuebling.mac-mouse-fix.helper" = mach-port-object;
     };
     "Label" = "mouse.fix.helper";
     "OnDemand" = false;
     "LastExitStatus" = 0;
     "PID" = 709;
     "Program" = "/Applications/Mac Mouse Fix.app/Contents/Library/LoginItems/Mac Mouse Fix Helper.app/Contents/MacOS/Mac Mouse Fix Helper";
     "PerJobMachServices" = {
         "com.apple.tsm.portname" = mach-port-object;
         "com.apple.axserver" = mach-port-object;
     };
 };
 */

// Old stuff

/*
 //    NSString *prefPaneSearchString = @"/PreferencePanes/Mouse Fix.prefPane/Contents/Library/LoginItems/Mouse Fix Helper.app/Contents/MacOS/Mouse Fix Helper";
 */

@end
