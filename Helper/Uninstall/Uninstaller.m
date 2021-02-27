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

    NSLog(@"Set Stream to \n%@\nLocation accoring to NSWorkspace:\n%@", mainAppURL, [NSWorkspace.sharedWorkspace URLForApplicationWithBundleIdentifier:kMFBundleIDApp]);
}

void Handle_FSCallback(ConstFSEventStreamRef streamRef, void *clientCallBackInfo, size_t numEvents, void *eventPaths, const FSEventStreamEventFlags *eventFlags, const FSEventStreamEventId *eventIds) {
    
    NSLog(@"Mac Mouse Fix move has been detected");
    
//    NSArray *installFolderContents = [NSFileManager.defaultManager contentsOfDirectoryAtPath:[Objects.mainAppBundle.bundlePath stringByDeletingLastPathComponent] error:NULL];
//    NSURL *trashURL = [NSFileManager.defaultManager URLForDirectory:NSTrashDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:nil];
//    NSArray *trashContents = [NSFileManager.defaultManager contentsOfDirectoryAtPath:trashURL.path error:nil];
    NSURL *installedBundleID = [NSWorkspace.sharedWorkspace URLForApplicationWithBundleIdentifier:kMFBundleIDApp];
    
    if (installedBundleID == nil) { // Has been uninstalled
        uninstall();
    } else if (installedBundleID != nil) { // Has been moved
        [HelperServices enableHelperAsUserAgent:YES]; // TODO: Check if this works - e.g. log out and in again after moving and see if helper still running
        setStreamToCurrentInstallLoc();
//        [NSApp terminate:nil]; // Restarting the app to refresh everything cause moving causes problems // Doesn't work either
    }
}

void uninstall() {
    
    NSLog(@"Uninstalling Mac Mouse Fix completely");
    
    // Delete Application Support Folder
    [NSFileManager.defaultManager trashItemAtURL:Objects.MFApplicationSupportFolderURL resultingItemURL:nil error:nil];
    // Delete launchd plist
    [NSFileManager.defaultManager trashItemAtURL:Objects.launchdPlistURL resultingItemURL:nil error:nil];
    // Remove from launchd
    [SharedUtil launchCLT:[NSURL fileURLWithPath:kMFLaunchctlPath] withArgs:@[@"remove", kMFLaunchdHelperIdentifier]]; // This kills as well I think
    // Kill self
    [NSApp terminate:nil];
    
//    [HelperServices enableHelperAsUserAgent:NO];
    // ^ This doesn't work properly, I think the root is that NSBundle still gives us the the old (pre-move-to-trash) bundle paths/urls
    //      But I think doing delete launchd plist, remove from launchd, and then kill self, has the same effect
    
}

@end
