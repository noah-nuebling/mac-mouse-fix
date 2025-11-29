//
// --------------------------------------------------------------------------
// Uninstaller.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "FileMonitor.h"
#import "HelperServices.h"
#import "Locator.h"
#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#import "Constants.h"
#import "SharedUtility.h"
#import "MFMessagePort.h"
#import "Logging.h"

@implementation FileMonitor

+ (void)load {
    [self setupFSMonitor];
}

+ (void)setupFSMonitor {
    setStreamToCurrentInstallLoc();
}

FSEventStreamRef _stream;
static void setStreamToCurrentInstallLoc() {
    
    /// Note: This stuff doesn't work after the app has been moved because NSBundle BundleForClass:self reports the old location
    
    if (_stream != NULL) {
        FSEventStreamStop(_stream);
        FSEventStreamInvalidate(_stream);
    }
    /// Start monitor
    /// Notes:
    /// - Need to monitor the enclosing folder for callbacks to work
    /// - The mainApp url shouldn't ever be nil except if we're running the helper standalone for debugging. Maybe we should just crash here?
    
    NSURL *mainApp = Locator.mainAppBundle.bundleURL;
    
    if (mainApp != nil) {
        
        NSURL *enclosing = [mainApp URLByDeletingLastPathComponent];
        
        _stream = FSEventStreamCreate(kCFAllocatorDefault, Handle_FSCallback, NULL, (__bridge CFArrayRef) @[enclosing.path], kFSEventStreamEventIdSinceNow, 1, kFSEventStreamCreateFlagIgnoreSelf ^ kFSEventStreamCreateFlagUseCFTypes);
        FSEventStreamScheduleWithRunLoop(_stream, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
        FSEventStreamStart(_stream);
        
        DDLogInfo(@"Set file monitoring to: %@ App location accoring to NSWorkspace: %@", enclosing.path, [NSWorkspace.sharedWorkspace URLForApplicationWithBundleIdentifier:kMFBundleIDApp].path);
    }
}

void Handle_FSCallback(ConstFSEventStreamRef streamRef, void *clientCallBackInfo, size_t numEvents, void *eventPaths, const FSEventStreamEventFlags *eventFlags, const FSEventStreamEventId *eventIds) {
    
    DDLogInfo(@"File system even in Mac Mouse Fix install folder");
    
    NSURL *installedBundleURLFromWorkspace = [NSWorkspace.sharedWorkspace URLForApplicationWithBundleIdentifier:kMFBundleIDApp];
    
    if (installedBundleURLFromWorkspace == nil) {
        DDLogInfo(@"Mac Mouse Fix cannot be found on the system anymore");
        uninstallCompletely();
    } else {
        NSURL *helperURL = Locator.helperBundle.bundleURL;
        NSURL *helperURLOld = NSBundle.mainBundle.bundleURL;
        BOOL isInOldLocation = [helperURL isEqualTo:helperURLOld];
        if (isInOldLocation) {
            DDLogInfo(@"... Mac Mouse Fix can still be found in its original location. Not doing anything");
            return;
        }
        DDLogInfo(@"Mac Mouse Fix Helper was launched at: %@ but is now at: %@", helperURLOld, helperURL);
        NSBundle *appBundle = Locator.mainAppBundle;
        BOOL isInTrash = [appBundle.bundleURL.URLByDeletingLastPathComponent.lastPathComponent isEqualToString:trashFolderName()];
        BOOL isRemoved = appBundle == nil;
        BOOL workspaceURLIsInTrash = [installedBundleURLFromWorkspace.URLByDeletingLastPathComponent.lastPathComponent isEqualToString:trashFolderName()];
        if (workspaceURLIsInTrash) {
            DDLogInfo(@"Workspace found Mac Mouse Fix in the trash. This probably means that Mac Mouse Fix has just been moved to the trash and that this is the only version of Mac Mouse Fix on the system.");
            uninstallCompletely();
        } else if (!workspaceURLIsInTrash && (isInTrash || isRemoved)) {
            DDLogInfo(@"Mac Mouse Fix has been deleted but is still installed at: %@", installedBundleURLFromWorkspace);
            disableHelper();
        } else {
            DDLogInfo(@"Mac Mouse Fix has been relocated to %@", appBundle.bundleURL.path);
            handleRelocation();
        }
    }
}

void handleRelocation(void) {
    
    /// Log
    
    DDLogInfo(@"Handle Mac Mouse Fix relocation...");
    
    /// We want to close the helper
    ///  If we let the helper running after relocation:
    ///      - If the helper closes (crashes) it won't be restarted automatically by launchd
    ///      - Just like the functions for getting current app bundles failed (we fixed it with hax bascially), there might be other stuff that behaves badly after relocation
    /// It's even better when we can automatically restart the helper. So the user doesn't notice anything and things just keep working.
    
    /// Sol 1: Restart the helper
    ///     - We used to be able to restart the helper  using the Accomplice. This won't work under Ventura using the new ServiceManagement APIs, since only the main app can enable/disable the helper now (At least in the Ventura Beta), so we're moving to a policy of just disabling the helper instead.
    ///     - We might also be able to start the mainApp in some sort of invisible stealth mode and have it restart the helper in the background like the accomplice used to do, but I'm not sure. It would be the optimal UX to restart the Helper
    ///     - Since restarting the Helper was the last thing the Accomplice was used for in MMF 3 (we already moved updating to Sparkle), this change made the Accomplice obsolete. And we deleted it in commit 1eedee69c3e36f0dbbe19480997d98b77668854f
    
//    DDLogInfo(@"Asking Accomplice to restart Helper ... But accomplice has been removed in MMF 3");
//    NSURL *accompliceURL = [Locator.mainAppBundle.bundleURL URLByAppendingPathComponent:kMFRelativeAccomplicePath];
//    NSArray *args = @[kMFAccompliceModeReloadHelper];
//    [SharedUtility launchCLT:accompliceURL withArgs:args];
    
    /// Sol 2: Disable the helper
    ///     `enableHelperAsUserAgent:NO` won't do anything under the macOS Ventura Beta, so we're also calling `disableHelper()`
    ///     The Helper also seems to be restarted under Ventura when it crashes even after being relocated, but I think it'll stop working when you restart the computer after the relocation.
    ///     It would be ideal if we used `[HelperServices disableHelperFromHelper]` here so that we have one unified method for this, but it doesn't work properly when called from here under macOS 12 for some reason.
    ///     Under macOS 13 Beta I think the Apple APIs are just broken after relocating. -> Wait until Ventura matures more before spnding more time on this.
    ///     TODO: ...
    ///         - Maybe move to using disableHelperFromHelper
    ///         - Make this work under Ventura
    
    if (@available(macOS 13.0, *)) {
        /// If we disable the Helper, it won't be able to be restarted until the whole computer is restarted, so it's better to do nothing. (Under Ventura Beta 7).
//        [HelperServices disableHelperFromHelper];
    } else {
        [MFMessagePort sendMessage:@"helperDisabled" withPayload:nil waitForReply:NO];
        [HelperServices enableHelperAsUserAgent:NO onComplete:nil];
        disableHelper();
    }
}
void uninstallCompletely(void) {
    
    DDLogInfo(@"Uninstalling Mac Mouse Fix completely...");
    removeResidue();
    disableHelper();
}
void removeResidue(void) {
    
    /// Log
    DDLogInfo(@"Removing Mac Mouse Fix resdiue");
    
    /// Delete Application Support Folder
    [NSFileManager.defaultManager trashItemAtURL:Locator.MFApplicationSupportFolderURL resultingItemURL:nil error:nil];
    
    /// Delete launchd plist
    [NSFileManager.defaultManager trashItemAtURL:Locator.launchdPlistURL resultingItemURL:nil error:nil];
    
    /// Delete logging folder // TODO: Test if this works
    DDFileLogger *fileLogger = [[DDFileLogger alloc] init];
    NSString *logsDirectoryPath = fileLogger.logFileManager.logsDirectory;
    NSURL *logsDirectoryURL = [NSURL fileURLWithPath:logsDirectoryPath isDirectory:YES];
    [NSFileManager.defaultManager trashItemAtURL:logsDirectoryURL resultingItemURL:nil error:nil];
}
void disableHelper(void) {
    /// Kill this process
    
    /// Log
    DDLogInfo(@"Removing helper from launchd (Byeeeee)");
    
    /// Remove from launchd
    /// This kills the helper as well
    /// The launchd.plist file will still be in the library and under Ventura the SM API still has the Helper registered -> Result: If we don't remove this residue, the system will try to start the helper on next login. Idk how to remove the SM residue? I think I read it's automatic when you delete an app.
    [SharedUtility launchCLT:[NSURL fileURLWithPath:kMFLaunchctlPath] withArgs:@[@"remove", kMFLaunchdHelperIdentifier]];
    [SharedUtility launchCLT:[NSURL fileURLWithPath:kMFLaunchctlPath] withArgs:@[@"remove", kMFLaunchdHelperIdentifierSM]];
}

/// Util

static NSString *trashFolderName() {
    NSURL *trashURL = [NSFileManager.defaultManager URLForDirectory:NSTrashDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:nil];
    return trashURL.path.lastPathComponent;
}

@end
