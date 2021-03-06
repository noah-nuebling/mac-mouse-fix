//
// --------------------------------------------------------------------------
// Updater.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "Updater.h"
#import "UpdateWindow.h"
#import "AppDelegate.h"
#import "MoreSheet.h"
#import "ConfigFileInterface_App.h"
#import <ZipArchive/ZipArchive.h>
#import "Constants.h"
#import "Objects.h"
#import "SharedUtility.h"



@interface Updater ()
@end

@implementation Updater

# pragma mark - Class Properties

static NSURLSessionDownloadTask *_downloadTask1;
static NSURLSessionDownloadTask *_downloadTask2;
static NSURLSession *_downloadSession;
static UpdateWindow *_windowController;
static NSInteger _availableVersion;
static NSURL *_updateLocation;
static NSURL *_updateNotesLocation;

# pragma mark - Hardcoded URLs

static NSURL *_baseRemoteURL;
static NSString *_bundleVersionSubpath;
static NSString *_updateNotesSubpath;
static NSString *_mainAppSubpath;
static NSString *_updateNotesUnzipSubpath;
static NSString *_mainAppUnzipSubpath;

+ (void)setupURLs {
    _baseRemoteURL = [[NSURL URLWithString:kMFWebsiteAddress] URLByAppendingPathComponent:@"maindownload-app"];
//    _baseRemoteURL = [NSURL fileURLWithPath:@"/Users/Noah/Documents/Projekte/Programmieren/Webstorm/Mac-Mouse-Fix-Website/maindownload-app"];
    
    _bundleVersionSubpath = @"/bundleversion-app";
    _updateNotesSubpath = @"/updatenotes-app.zip";
    _mainAppSubpath = @"/MacMouseFixApp.zip";
    
    _updateNotesUnzipSubpath = @"updatenotes-app";
    _mainAppUnzipSubpath = kMFMainAppName;
}

# pragma mark - Class Methods

+ (void)load {
    [self setupURLs];
}

+ (void)setupDownloadSession {
    
    NSURLSessionConfiguration *downloadSessionConfiguration = NSURLSessionConfiguration.ephemeralSessionConfiguration;
        downloadSessionConfiguration.allowsCellularAccess = NO;
        if (@available(macOS 10.13, *)) {
            downloadSessionConfiguration.waitsForConnectivity = YES;
        }
    _downloadSession = [NSURLSession sessionWithConfiguration:downloadSessionConfiguration];
}

+ (void)reset {
    [_windowController close];
    
    [_downloadTask1 cancel];
    _downloadTask1 = nil;
    [_downloadTask2 cancel];
    _downloadTask2 = nil;
    [_downloadSession invalidateAndCancel];
}

+ (void)checkForUpdate {
    
    NSLog(@"Checking for update...");
    
    [self reset]; // TODO: make sure this works (on a slow connection)
    
    [self setupDownloadSession];
    
    // Clean up before starting the update procedure again
    
    _downloadTask1 = [_downloadSession downloadTaskWithURL:[_baseRemoteURL URLByAppendingPathComponent:_bundleVersionSubpath] completionHandler:^(NSURL * _Nullable location, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error != NULL){
            NSLog(@"checking for updates failed");
            NSLog(@"Error: \n%@", error);
            return;
        }
        NSInteger currentVersion = [[[NSBundle bundleForClass:self] objectForInfoDictionaryKey:@"CFBundleVersion"] integerValue];
        _availableVersion = [[NSString stringWithContentsOfURL:location encoding:NSUTF8StringEncoding error:NULL] integerValue];
        NSLog(@"currentVersion: %ld, availableVersion: %ld", (long)currentVersion, (long)_availableVersion);
        NSInteger skippedVersion = [[ConfigFileInterface_App.config valueForKeyPath:@"Other.skippedBundleVersion"] integerValue];
        if (currentVersion < _availableVersion && _availableVersion != skippedVersion) {
            [self downloadAndPresent];
        } else {
            NSLog(@"Not downloading update. Either no new version available or available version has been skipped");
        }
    }];
    [_downloadTask1 resume];
}
+ (void)downloadAndPresent {
    NSLog(@"Downloading update notes...");
    _downloadTask1 = [_downloadSession downloadTaskWithURL:[_baseRemoteURL URLByAppendingPathComponent:_updateNotesSubpath] completionHandler:^(NSURL * _Nullable location, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error != NULL) {
            NSLog(@"Error downloading update notes: %@", error);
            return;
        }
        NSLog(@"Successfully downloaded update notes");
        NSString *unzipDest = [[location path] stringByDeletingLastPathComponent];
        NSLog(@"Unzipped update notes to: %@",unzipDest);
        NSError *unzipError;
        [SSZipArchive unzipFileAtPath:[location path] toDestination:unzipDest overwrite:YES password:NULL error:&unzipError];
        if (unzipError != NULL) {
            NSLog(@"Error unzipping update Notes: %@", unzipError);
            return;
        }
        _updateNotesLocation = [[NSURL fileURLWithPath:unzipDest] URLByAppendingPathComponent:_updateNotesUnzipSubpath];
        
        NSLog(@"Downloading app update...");
        _downloadTask2 = [_downloadSession downloadTaskWithURL:[_baseRemoteURL URLByAppendingPathComponent:_mainAppSubpath] completionHandler:^(NSURL * _Nullable location, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            if (error != NULL) {
                NSLog(@"Error downloading appupdate: %@", error);
                return;
            }
            NSLog(@"Successfully downloaded app update. Archive at: %@", location);
            _updateLocation = location;
            [self presentUpdate];
        }];
        [_downloadTask2 resume];
    }];
    [_downloadTask1 resume];
}

+ (void)presentUpdate {
    dispatch_async(dispatch_get_main_queue(), ^{
        
        NSLog(@"Presenting update to user...");
        
        _windowController = [[UpdateWindow alloc] init];
        [_windowController startWithUpdateNotes:_updateNotesLocation];
        
        [_windowController showWindow:nil];
        [_windowController.window makeKeyAndOrderFront:nil];
//        [NSApplication.sharedApplication beginModalSessionForWindow:_windowController.window];
        
    });
}

+ (void)skipAvailableVersion {
    [ConfigFileInterface_App.config setValue:@(_availableVersion) forKeyPath:@"Other.skippedBundleVersion"];
    [ConfigFileInterface_App writeConfigToFileAndNotifyHelper];
}

+ (void)update {
    
    
    
    // TODO: Consider including the update origin URL in the config file
    // This would make future update debugging easier, cause we could easily test, what happens if an older version tries to update to a specific newer version, without having to recompile the old version
    
    // Dismiss more sheet
    dispatch_async(dispatch_get_main_queue(), ^{
        [MoreSheet.instance end];
    });
    
    // Get file manager
    NSFileManager *fm = [NSFileManager defaultManager];
    
    // Unzip the downloaded file
    NSString *unzipDest = [[_updateLocation path] stringByDeletingLastPathComponent];
    NSLog(@"update unzip dest: %@",unzipDest);
    NSError *unzipError;
    [SSZipArchive unzipFileAtPath:[_updateLocation path] toDestination:unzipDest overwrite:YES password:NULL error:&unzipError];
    if (unzipError != NULL) {
        NSLog(@"Error unzipping app: %@", unzipError);
        return;
    }
    NSLog(@"Update downloaded to temporary folder: %@", _updateLocation);
    
    // Prepare Apple Script which can install the update
    
    // I think the ability to get elevated permissions easily might have been one of the main reasons we chose Apple Script over NSWorkspace
    //  But we don't need elevated permission anymore. We only needed them to update prefpanes which are installed for all users
    // Prefpane versions of the script also moved the config file over to the newly installed prefpane
    //  We don't need this anymore cause the config is now stored in the library. The attempts to
    //  copy over the old config should fail gracefully, because the path to config was hardcoded and doesn't exist anymore
    
    NSURL *currentBundleURL = Objects.mainAppBundle.bundleURL;
    NSURL *currentBundleEnclosingURL = [currentBundleURL URLByDeletingLastPathComponent];
    NSURL *updateBundleURL = [[NSURL fileURLWithPath:unzipDest] URLByAppendingPathComponent:_mainAppUnzipSubpath];
    // Forgot why we need to quadrupel escape " "
    NSString *currentBundleOSAPath = [[currentBundleURL path] stringByReplacingOccurrencesOfString:@" " withString:@"\\\\ "];
    NSString *updateBundleOSAPath = [[updateBundleURL path] stringByReplacingOccurrencesOfString:@" " withString:@"\\\\ "];
    NSString *adminParamOSA = @"";
    if (![fm isWritableFileAtPath:[currentBundleEnclosingURL path]]
        || ![fm isWritableFileAtPath:[currentBundleURL path]]
        || ![fm isReadableFileAtPath:[updateBundleURL path]]) {
        // TODO: I'm almost certain we should remove this. I think it was necessary to update prefpanes installed for all users, but with an app that shouldn't be an issue.
        NSLog(@"We'll need elevated permissions to install update - adding admin rights request to installation script");
        adminParamOSA = @" with administrator privileges";
    }
    // Assemble the script
    NSString *installScriptOSA = [NSString stringWithFormat:@"do shell script \"rm -r %@;cp -a %@ %@\"%@",
                                  currentBundleOSAPath,updateBundleOSAPath,currentBundleOSAPath, adminParamOSA];
    NSLog(@"Assembled update installation script: %@", installScriptOSA);
    NSURL *accompliceExecURL = [Objects.mainAppBundle.bundleURL URLByAppendingPathComponent:kMFRelativeAccomplicePath];
    NSLog(@"Asking Accomplice to install the new update...");
    [SharedUtility launchCLT:accompliceExecURL withArgs:@[kMFAccompliceModeUpdate, installScriptOSA]];
}

@end
