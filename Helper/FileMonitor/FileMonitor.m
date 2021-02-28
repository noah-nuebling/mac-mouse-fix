//
// --------------------------------------------------------------------------
// Uninstaller.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "FileMonitor.h"
#import "HelperServices.h"
#import "Objects.h"
#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#import "Constants.h"
#import "SharedUtil.h"

@implementation FileMonitor

+ (void)load {
    [self setupFSMonitor];
}

+ (void)setupFSMonitor {
    setStreamToCurrentInstallLoc();
}

FSEventStreamRef _stream;
static void setStreamToCurrentInstallLoc() {
    
    // v This stuff doesn't work after the app has been moved because NSBundle BundleForClass:self reports the old location
    
    if (_stream != NULL) {
        FSEventStreamStop(_stream);
        FSEventStreamInvalidate(_stream);
    }
    // v Need to monitor the enclosing folder for callbacks to work
    NSURL *mainAppURL = [Objects.mainAppBundle.bundleURL URLByDeletingLastPathComponent];
    _stream = FSEventStreamCreate(kCFAllocatorDefault, Handle_FSCallback, NULL, (__bridge CFArrayRef) @[mainAppURL.path], kFSEventStreamEventIdSinceNow, 1, kFSEventStreamCreateFlagIgnoreSelf ^ kFSEventStreamCreateFlagUseCFTypes);
    FSEventStreamScheduleWithRunLoop(_stream, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
    FSEventStreamStart(_stream);
    
    NSLog(@"Set file monitoring to: %@ App location accoring to NSWorkspace: %@", mainAppURL.path, [NSWorkspace.sharedWorkspace URLForApplicationWithBundleIdentifier:kMFBundleIDApp].path);
}

void Handle_FSCallback(ConstFSEventStreamRef streamRef, void *clientCallBackInfo, size_t numEvents, void *eventPaths, const FSEventStreamEventFlags *eventFlags, const FSEventStreamEventId *eventIds) {
    
    NSLog(@"File system even in Mac Mouse Fix install folder");
    
    NSURL *installedBundleURLFromWorkspace = [NSWorkspace.sharedWorkspace URLForApplicationWithBundleIdentifier:kMFBundleIDApp];
    
    if (installedBundleURLFromWorkspace == nil) {
        NSLog(@"Mac Mouse Fix cannot be found on the system anymore");
        uninstallCompletely();
    } else {
        NSURL *helperURL = Objects.helperBundle.bundleURL;
        NSURL *helperURLOld = NSBundle.mainBundle.bundleURL;
        BOOL isInOldLocation = [helperURL isEqualTo:helperURLOld];
        if (isInOldLocation) {
            NSLog(@"... File system event was probably unrelated to Mac Mouse Fix");
            return;
        }
        NSLog(@"Mac Mouse Fix Helper was launched at: %@ but is now at: %@", helperURLOld, helperURL);
        NSBundle *appBundle = Objects.mainAppBundle;
        BOOL isInTrash = [appBundle.bundleURL.URLByDeletingLastPathComponent.lastPathComponent isEqualToString:trashFolderName()];
        BOOL isRemoved = appBundle == nil;
        BOOL workspaceURLIsInTrash = [installedBundleURLFromWorkspace.URLByDeletingLastPathComponent.lastPathComponent isEqualToString:trashFolderName()];
        if (workspaceURLIsInTrash) {
            NSLog(@"Workspace found Mac Mouse Fix in the trash. This probably means that Mac Mouse Fix has just been moved to the trash and that this is the only version of Mac Mouse Fix on the system.");
            uninstallCompletely();
        } else if (!workspaceURLIsInTrash && (isInTrash || isRemoved)) {
            NSLog(@"Mac Mouse Fix has been deleted but is still installed at: %@", installedBundleURLFromWorkspace);
            disableHelper();
        } else {
            NSLog(@"Mac Mouse Fix has been relocated to %@", appBundle.bundleURL.path);
            handleRelocation();
        }
    }
}

void handleRelocation() {
    NSLog(@"Handle Mac Mouse Fix relocation...");
    
//    [HelperServices enableHelperAsUserAgent:YES];
//    setStreamToCurrentInstallLoc(); // Remove - this is not needed if we can restart/close the helper which we want to do
//    [NSApp terminate:nil];
    
    // We want to close the helper
    //  If we let the helper running after relocation:
    //      - If the helper closes (crashes) it won't be restarted automatically by launchd
    //      - Just like the functions for getting current app bundles failed (we fixed it with hax bascially), there might be other stuff that behaves badly after relocation
    // Unfortunately, I can't find a way to make launchd restart the helper from within the helper
    // We have to use a separate executable to restart the helper
    
    NSLog(@"Asking Accomplice to restart Helper");
    NSURL *accompliceURL = [Objects.mainAppBundle.bundleURL URLByAppendingPathComponent:kMFRelativeAccomplicePath];
    NSArray *args = @[kMFAccompliceModeReloadHelper];
    [SharedUtil launchCLT:accompliceURL withArgs:args];
}
void uninstallCompletely() {
    NSLog(@"Uninstalling Mac Mouse Fix completely...");
    removeResidue();
    disableHelper();
}
void removeResidue() {
    NSLog(@"Removing Mac Mouse Fix resdiue");
    // Delete Application Support Folder
    [NSFileManager.defaultManager trashItemAtURL:Objects.MFApplicationSupportFolderURL resultingItemURL:nil error:nil];
    // Delete launchd plist
    [NSFileManager.defaultManager trashItemAtURL:Objects.launchdPlistURL resultingItemURL:nil error:nil];
}
void disableHelper() { // Kill this process
    NSLog(@"Removing helper from launchd (Byeeeee)");
    // Remove from launchd
    [SharedUtil launchCLT:[NSURL fileURLWithPath:kMFLaunchctlPath] withArgs:@[@"remove", kMFLaunchdHelperIdentifier]]; // This kills as well I think
    // Kill self
//    [NSApp terminate:nil];
}

// Util

static NSString *trashFolderName() {
    NSURL *trashURL = [NSFileManager.defaultManager URLForDirectory:NSTrashDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:nil];
    return trashURL.path.lastPathComponent;
}

@end
