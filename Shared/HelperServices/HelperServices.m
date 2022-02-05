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
                cleanup();
            }
            DDLogInfo(@"launchctl terminated with stdout/stderr: %@, error: %@", [NSString.alloc initWithData:pipe.fileHandleForReading.readDataToEndOfFile encoding:NSUTF8StringEncoding], error);
        };
        [task launchAndReturnError:&error];
        
    } else { // Fallback on earlier versions
        NSString *OnOffArgumentOld = (enable) ? @"load": @"unload";
        [NSTask launchedTaskWithLaunchPath: kMFLaunchctlPath arguments: @[OnOffArgumentOld, Objects.launchdPlistURL.path]]; // Can't clean up here easily cause there's no termination handler
    }
}
static void cleanup() {
    NSError *error;
    [NSFileManager.defaultManager removeItemAtURL:Objects.launchdPlistURL error:&error];
    if (error != nil) {
        DDLogError(@"Failed to delete launchd.plist file. The helper will likely be re-enabled on startup. Delete the file at \"%@\" to prevent this.", Objects.launchdPlistURL.path);
    }
}

+ (void)repairLaunchdPlist {
    /// What this does:
    
    /// Get path of executable of helper app
    /// Check
    /// - If the "User/Library/LaunchAgents/mouse.fix.helper.plist" useragent config file  (aka launchdPlist) exists
    ///     - This specific path is deprecated, since MMF is an app not a prefpane now
    /// - If the Launch Agents Folder exists
    /// - If the exectuable path within the plist file is correct
    /// If not:
    /// Create correct file based on "default_launchd.plist" and the helpers exectuablePath
    /// Write correct file to "User/Library/LaunchAgents"
    
    @autoreleasepool {
        /// Do we need an autoreleasepool here?
        /// -> No. Remove this.
        /// I just read up on it. You only need to manually use `autoreleasepool`s for optimization and some edge cases
        /// Here's my understanding. In normal scenarios, Cocoa objects are automatically sent autorelease messages when they go out of scope. Then, on the next iteration of the runloop, all objects that were sent autorelease messages will be sent release messges. Which will in turn cause their reference counts to drop, which will cause them to be deallocated when that reaches 0. When you use a manual autoreleasepool, then the autoreleased Cocoa objects will be sent release messages after the autoreleasepool block ends, and not only at the next runloop iteration. That's all it does in this scenario.
        /// When to use autoreleasepool: https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/MemoryMgmt/Articles/mmAutoreleasePools.html
        /// When autoreleased objects are sent release messages: https://stackoverflow.com/questions/673372/when-does-autorelease-actually-cause-a-release-in-cocoa-touch
        
        DDLogInfo(@"Repairing User Agent Config File");
        
        /// Declare error
        NSError *error;
        
        /// Get helper executable path
        NSBundle *helperBundle = Objects.helperBundle;
        NSBundle *mainAppBundle = Objects.mainAppBundle;
        NSString *helperExecutablePath = helperBundle.executablePath;
        
        /// Get path to launch agent config file (aka launchdPlist)
        NSString *launchdPlist_path = Objects.launchdPlistURL.path;
        
        /// Create file manager
        
        NSFileManager *fileManager = [[NSFileManager alloc] init];
        
        /// Check if launchPlist file exists
        
        BOOL launchdPlist_exists = [fileManager fileExistsAtPath: launchdPlist_path isDirectory: nil];
        
        /// Check if executable path is correct
        
        BOOL launchdPlist_executablePathIsCorrect = YES;
        
        if (launchdPlist_exists) {
            
            /// Load data from launch agent config file into a dictionary
            NSData *launchdPlist_data = [NSData dataWithContentsOfFile:launchdPlist_path];
            NSDictionary *launchdPlist_dict = [NSPropertyListSerialization propertyListWithData:launchdPlist_data options:NSPropertyListImmutable format:0 error:nil];
            
            /// Check if the executable path inside the config file is correct, if not, set flag to false
            NSString *helperExecutablePathFromFile = [launchdPlist_dict objectForKey: @"Program"];
            if ( [helperExecutablePath isEqualToString: helperExecutablePathFromFile] == NO ) {
                launchdPlist_executablePathIsCorrect = NO;
            }
            
            /// Debug
//            DDLogDebug(@"objectForKey: %@", OBJForKey);
//            DDLogDebug(@"helperExecutablePath: %@", helperExecutablePath);
//            DDLogDebug(@"OBJ == Path: %d", OBJForKey isEqualToString: helperExecutablePath);
        }
        
        /// Log
        
        DDLogInfo(@"launchdPlistExists %hhd, launchdPlistIsCorrect: %hhd", launchdPlist_exists,launchdPlist_executablePathIsCorrect);
        
        if ((launchdPlist_exists == FALSE) || (launchdPlist_executablePathIsCorrect == FALSE)) {
            /// The config file doesn't exist, or the executable path within it is not correct
            ///  -> Acutally repair stuff
            
            DDLogInfo(@"repairing file...");
            
            /// Check if "User/Library/LaunchAgents" folder exists, if not, create it
            
            NSString *launchAgentsFolderPath = [launchdPlist_path stringByDeletingLastPathComponent];
            
            BOOL launchAgentsFolderExists = [fileManager fileExistsAtPath:launchAgentsFolderPath isDirectory:nil];
            
            if (launchAgentsFolderExists == NO) {
                
                DDLogInfo(@"LaunchAgents folder doesn't exist");
                NSError *error;
                
                /// Create LaunchAgents folder
                
                error = nil;
                [fileManager createDirectoryAtPath:launchAgentsFolderPath withIntermediateDirectories:FALSE attributes:nil error:&error];
                if (error == nil) {
                    DDLogInfo(@"LaunchAgents Folder Created");
                } else if (error.code == NSFileWriteNoPermissionError) {
                    DDLogError(@"Lacking permission to create LaunchAgents folder. Error: %@", error);
                } else {
                    DDLogError(@"Error creating LaunchAgents Folder: %@", error);
                }
            }
            
            /// Repair permissions of LaunchAgents folder if it's not writable
            
            error = makeWritable(launchAgentsFolderPath);
            if (error) {
                DDLogError(@"Failed to make LaunchAgents folder writable. Error: %@", error);
            }
            
            /// Repair the contents of the launchdPlist file

            /// Read contents of default_launchd.plist (aka default-launch-agent-config-file or defaultLAConfigFile) into a dictionary
            
            error = nil;
            
            NSString *defaultLaunchdPlist_path = [mainAppBundle pathForResource:@"default_launchd" ofType:@"plist"];
            NSData *defaultlaunchdPlist_data = [NSData dataWithContentsOfFile:defaultLaunchdPlist_path];
            // TODO: This just crashed the app with "Exception: "data parameter is nil". It says that that launchdPlistExists = NO.
            // I was running Mac Mouse Fix Helper standalone for debugging, not embedded in the main app
            NSMutableDictionary *newlaunchdPlist_dict = [NSPropertyListSerialization propertyListWithData:defaultlaunchdPlist_data options:NSPropertyListMutableContainersAndLeaves format:nil error:&error];
            
            /// Set the executable path to the correct value
            [newlaunchdPlist_dict setValue: helperExecutablePath forKey:@"Program"];
            
            /// Get NSData from newLaunchdPlist dict
            NSData *newLaunchdPlist_data = [NSPropertyListSerialization dataWithPropertyList:newlaunchdPlist_dict format:NSPropertyListXMLFormat_v1_0 options:0 error:&error];
            NSAssert(error == nil, @"Failed to create NSData from new launchdPlist dict");
            
            /// Write new newLaunchdPlist data to file
            [newLaunchdPlist_data writeToFile:launchdPlist_path options:NSDataWritingAtomic error:&error];
            
            if (error != nil) {
                DDLogError(@"repairUserAgentConfigFile() -- Data Serialization Error: %@", error);
            }
        } else {
            DDLogInfo(@"Nothing to repair");
        }
    }
    
}

static NSError *makeWritable(NSString *itemPath) {
    /**
     
     Helper function for + repairLaunchdPlist
     Changes permissions of the item at filePath to allow writing by the user to that item
     
     __Motivation__
     - This is intended to be used by + repairLaunchdPlist to unlock the LaunchAgents folder so we can write our LaunchdPlist into it.
     - For some reason, many users have had troubles enabling Mac Mouse Fix recently. Many of these troubles turned out to be due to the LaunchAgents folder having it's permissions set to 'read only'. This function can be used to fix that.
        - See for example Issue [#54](https://github.com/noah-nuebling/mac-mouse-fix/issues/54)
        - There was also another GH issue where the user orignially figured out that permissions were the problem which prompted me to add better logging. But I'm writing this function much later. So I can't remember which GH Issue that was. Props to that user anyways.
    
     __Notes__
     - I really hope this doesn't break anything. Changing permissions in the file system feels somewhat dangerous.
     - Also it might be a good idea to ask the user if they want the permissions to be changed, but 99.9% of users won't even understand what they are deciding about, and it would be a lot of work to present this in a good way. So I think this should be fine.
     */
    
    /// Get fileManager
    
    NSFileManager *fileManager = NSFileManager.defaultManager;
    
    /// Check if file at filePath is writable
    
    if (![fileManager isWritableFileAtPath:itemPath]) {
        /// File is not writable
        
        /// Log
        
        DDLogWarn(@"File at %@ is not writable. Attempting to change permissions.", itemPath);
        
        /// Declare error
        
        NSError *error;
        
        /// Get file attributes
        
        error = nil;
        NSDictionary *attributes = [fileManager attributesOfItemAtPath:itemPath error:&error];
        if (error) return error;
        
        /// Get old permissions from file attributes
        
        NSUInteger oldPermissions = attributes.filePosixPermissions;
        
        /// Create new permissions
        
        NSUInteger newPermissions = oldPermissions | S_IWUSR;
        /// ^ Add write permission for user. See `man 2 chmod` for more info
            
        /// Set new permissions to file
            
        error = nil;
        [fileManager setAttributes:@{
            NSFilePosixPermissions: @(newPermissions)
        } ofItemAtPath:itemPath error:&error];
        
        if (error) {
            return error;
        }
        
        /// Debug
        
        DDLogInfo(@"Changed permissions of %@ from %@ to %@", itemPath,  [SharedUtility binaryRepresentation:(int)oldPermissions], [SharedUtility binaryRepresentation:(int)newPermissions]);
        /// ^ Binary representation doesn't really help. This is almost impossible to parse visually.
    }
    
    return nil;
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
        DDLogWarn(@"Found helper running somewhere else.");
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
    
    DDLogInfo(@"Cleaning up stuff from previous versions");
    
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
        
        DDLogWarn(@"Strange helper: found at: %@ \nbundleExecutable at: %@", launchdPath, Objects.helperBundle.executablePath);
        return YES;
    }
    
    DDLogInfo(@"Strange Helper: not found");
    
    return NO;
}

+ (void)terminateOtherHelperInstances {
    /// Terminate any other running instances of the app
    /// Only call this after after removing the Helper from launchd
    /// This only works to terminate instances of the Helper which weren't started by launchd.
    /// Launchd-started instances will immediately be restarted after they are terminated
    /// Mac Mouse Fix Accomplice does something similar to this in update()
    
    DDLogInfo(@"Terminating other Helper instances");
    
    NSArray<NSRunningApplication *> *instances = [NSRunningApplication runningApplicationsWithBundleIdentifier:kMFBundleIDHelper];
    
    DDLogInfo(@"%lu other running Helper instances found", (unsigned long)instances.count);
        
    for (NSRunningApplication *instance in instances) {
        [instance terminate]; // Consider using forceTerminate instead
    }
    
}

/// Remove currently running helper from launchd
/// From my testing this does the same as the `bootout` command, but it doesn't rely on a valid launchd.plist file to exist in the library, so it should be more robust.
+ (void)removeHelperFromLaunchd {
    
    DDLogInfo(@"Removing Helper from launchd");
    
    NSURL *launchctlURL = [NSURL fileURLWithPath:kMFLaunchctlPath];
    NSError *err;
    [SharedUtility launchCTL:launchctlURL withArguments:@[@"remove", kMFLaunchdHelperIdentifier] error:&err];
    if (err != nil) {
        DDLogError(@"Error removing Helper from launchd: %@", err);
    }
}

/// Remove legacy launchd plist file if it exists
/// The launchd plist file used to be at `~/Library/LaunchAgents/com.nuebling.mousefix.helper.plist` when the app was still a prefpane
/// Now, with the app version, it's moved to `~/Library/LaunchAgents/com.nuebling.mac-mouse-fix.helper.plist`
/// Having the old version still can lead to the old helper being started at startup, and I think other conflicts, too.
+ (void)removeLegacyLaunchdPlist {
    
    DDLogInfo(@"Removing legacy launchd plist");
    
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
            DDLogError(@"Error while removing legacy launchd plist file: %@", err);
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
