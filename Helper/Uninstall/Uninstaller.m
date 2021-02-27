//
// --------------------------------------------------------------------------
// Uninstaller.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "Uninstaller.h"
#import "HelperServices.h"
#import "Objects.h"
#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#import "Constants.h"
#import "SharedUtil.h"

@implementation Uninstaller

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
    
    NSLog(@"Set file monitoring to:%@ App location accoring to NSWorkspace:%@", mainAppURL, [NSWorkspace.sharedWorkspace URLForApplicationWithBundleIdentifier:kMFBundleIDApp]);
}

void Handle_FSCallback(ConstFSEventStreamRef streamRef, void *clientCallBackInfo, size_t numEvents, void *eventPaths, const FSEventStreamEventFlags *eventFlags, const FSEventStreamEventId *eventIds) {
    
    NSLog(@"Mac Mouse Fix move has been detected");
    
//    NSArray *installFolderContents = [NSFileManager.defaultManager contentsOfDirectoryAtPath:[Objects.mainAppBundle.bundlePath stringByDeletingLastPathComponent] error:NULL];
    
    NSURL *installedBundleURLFromWorkspace = [NSWorkspace.sharedWorkspace URLForApplicationWithBundleIdentifier:kMFBundleIDApp];
    
    if (installedBundleURLFromWorkspace == nil) { // Has been deleted
        NSLog(@"Mac Mouse Fix cannot be found on the system anymore");
        uninstallCompletely();
    } else if (installedBundleURLFromWorkspace != nil) { // Has been moved
        NSBundle *mainAppBundle = Objects.mainAppBundle;
        BOOL isTrashed = [mainAppBundle.bundleURL.URLByDeletingLastPathComponent.lastPathComponent isEqualToString:trashFolderName()];
        BOOL isRemoved = mainAppBundle == nil;
        BOOL workspaceURLIsTrash = [installedBundleURLFromWorkspace.URLByDeletingLastPathComponent.lastPathComponent isEqualToString:trashFolderName()];
        if (workspaceURLIsTrash) {
            NSLog(@"Workspace found Mac Mouse Fix in the trash. This probably means that Mac Mouse Fix has just been moved to the trash and that this is the only version of Mac Mouse Fix on the system.");
            uninstallCompletely();
        } else if (!workspaceURLIsTrash && (isTrashed || isRemoved)) {
            NSLog(@"Mac Mouse Fix has been deleted but is still installed at: %@", installedBundleURLFromWorkspace);
            removeHelper();
        } else {
            NSLog(@"Mac Mouse Fix has been relocated to %@", mainAppBundle.bundleURL.path);
            handleRelocation();
        }
    }
}

void handleRelocation() {
    NSLog(@"Handle Mac Mouse Fix relocation...");
    [HelperServices enableHelperAsUserAgent:YES]; // TODO: Check if this works - e.g. log out and in again after moving and see if helper still running
    setStreamToCurrentInstallLoc();
    NSLog(@"Restaring helper");
//    [NSApp terminate:nil]; // Restarting the app to refresh everything is probably more robust than setStreamToCurrentInstallLoc()
}
void uninstallCompletely() {
    NSLog(@"Uninstalling Mac Mouse Fix completely...");
    removeResidue();
    removeHelper();
}
void removeResidue() {
    NSLog(@"Removing Mac Mouse Fix resdiue");
    // Delete Application Support Folder
    [NSFileManager.defaultManager trashItemAtURL:Objects.MFApplicationSupportFolderURL resultingItemURL:nil error:nil];
    // Delete launchd plist
    [NSFileManager.defaultManager trashItemAtURL:Objects.launchdPlistURL resultingItemURL:nil error:nil];
}
void removeHelper() { // Kill this process
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
