//
//  Updater.m
//  Mouse Fix
//
//  Created by Noah Nübling on 21.08.19.
//  Copyright © 2019 Noah Nuebling. All rights reserved.
//

#import "Updater.h"
#import "UpdateWindow.h"
#import "../PrefPaneDelegate.h"
#import "../Config/ConfigFileInterfacePref.h"
#import "ZipArchive/SSZipArchive.h"


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

# pragma mark - Class Methods

+ (void)initialize
{
    if (self == [Updater class]) {
        [self setupDownloadSession];
    }
}
+ (void)setupDownloadSession {
    
    NSURLSessionConfiguration *downloadSessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
//        downloadSessionConfiguration.allowsCellularAccess = NO;
        if (@available(macOS 10.13, *)) {
            downloadSessionConfiguration.waitsForConnectivity = YES;
        }
    _downloadSession = [NSURLSession sessionWithConfiguration:downloadSessionConfiguration];
}

+ (void)checkForUpdate {
    
    // clean up before starting the update procedure again
    [_windowController close];
    
    
    
    _downloadTask1 = [_downloadSession downloadTaskWithURL:[NSURL URLWithString: @"https://noah-nuebling.github.io/mac-mouse-fix/maindownload/bundleversion"] completionHandler:^(NSURL * _Nullable location, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error != NULL){
            NSLog(@"checking for updates failed");
            NSLog(@"Error: \n%@", error);
            return;
        }
        NSInteger currentVersion = [[[NSBundle bundleForClass:self] objectForInfoDictionaryKey:@"CFBundleVersion"] integerValue];
        _availableVersion = [[NSString stringWithContentsOfURL:location encoding:NSUTF8StringEncoding error:NULL] integerValue];
        NSLog(@"currentVersion: %ld, availableVersion: %ld", (long)currentVersion, (long)_availableVersion);
        NSInteger skippedVersion = [[ConfigFileInterfacePref.config valueForKeyPath:@"other.skippedBundleVersion"] integerValue];
        if (currentVersion < _availableVersion && _availableVersion != skippedVersion) {
            [self downloadAndPresent];
        } else {
            NSLog(@"Not downloading update. Either no new version available or available version has been skipped");
        }
    }];
    [_downloadTask1 resume];
}
+ (void)downloadAndPresent {
    _downloadTask1 = [_downloadSession downloadTaskWithURL:[NSURL URLWithString:@"https://noah-nuebling.github.io/mac-mouse-fix/maindownload/updatenotes.zip"] completionHandler:^(NSURL * _Nullable location, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error != NULL) {
            NSLog(@"error downloading updatenotes: %@", error);
            return;
        }
        _updateLocation = location;
        _downloadTask2 = [_downloadSession downloadTaskWithURL:[NSURL URLWithString: @"https://noah-nuebling.github.io/mac-mouse-fix/maindownload/MacMouseFix.zip"] completionHandler:^(NSURL * _Nullable location, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            if (error != NULL) {
                NSLog(@"error downloading prefPane: %@", error);
                return;
            }
            [self presentUpdate:location withNotes:_updateNotesLocation];
        }];
        [_downloadTask2 resume];
    }];
    [_downloadTask1 resume];
}
    
    
    
//    _downloadTask = [_downloadSession downloadTaskWithURL:[NSURL URLWithString: @"https://noah-nuebling.github.io/mac-mouse-fix/maindownload/MacMouseFix.zip"] completionHandler:^(NSURL * _Nullable location, NSURLResponse * _Nullable response, NSError * _Nullable error) {
//
//        if (error != NULL) {
//            NSLog(@"Downloading error: %@", error);
//            return;
//        }
//        NSFileManager *fm = [NSFileManager defaultManager];
//
//        // unzip the downloaded file
//        
//        NSString *unzipDest = [[location path] stringByDeletingLastPathComponent];
//        NSLog(@"unzip dest: %@",unzipDest);
//        NSError *unzipError;
//        [SSZipArchive unzipFileAtPath:[location path] toDestination:unzipDest overwrite:YES password:NULL error:&unzipError];
//        if (unzipError != NULL) {
//            NSLog(@"Unzipping error: %@", unzipError);
//            return;
//        }
//

+ (void)presentUpdate:(NSURL *)update withNotes:(NSURL *)updateNotes {
    dispatch_async(dispatch_get_main_queue(), ^{
        
        _windowController = [UpdateWindow alloc];
        _windowController = [_windowController initWithWindowNibName:@"UpdateWindow" owner:_windowController];
        [_windowController startStuff];
        
        [_windowController showWindow:nil];
        [_windowController.window makeKeyAndOrderFront:nil];
//        [NSApplication.sharedApplication beginModalSessionForWindow:_windowController.window];
        
    });
}

+ (void)skipAvailableVersion {
    [ConfigFileInterfacePref.config setValue:@(_availableVersion) forKeyPath:@"other.skippedBundleVersion"];
    [ConfigFileInterfacePref writeConfigToFile];
    NSLog(@"config: %@", ConfigFileInterfacePref.config);
}

+ (void)update {
    

    // TODO: find a way to close the app even if the panel is open (dismiss it first)
//        [[[NSApplication sharedApplication] mainWindow] endSheet:NSApplication.sharedApplication.mainWindow.attachedSheet];
//    [[[NSBundle bundleForClass:self.class] principalClass] endSheetPanel];
//    [(PrefPaneDelegate *)NSApplication.sharedApplication.mainWindow.delegate endSheetPanel];

    NSFileManager *fm = [NSFileManager defaultManager];

    // unzip the downloaded file

    NSString *unzipDest = [[_updateLocation path] stringByDeletingLastPathComponent];
    NSLog(@"update unzip dest: %@",unzipDest);
    NSError *unzipError;
    [SSZipArchive unzipFileAtPath:[_updateLocation path] toDestination:unzipDest overwrite:YES password:NULL error:&unzipError];
    if (unzipError != NULL) {
        NSLog(@"Error unzipping prefPane: %@", unzipError);
        return;
    }
    
    NSLog(@"_updateLocation: %@", _updateLocation);
    
    NSURL *currentBundleURL = [[NSBundle bundleForClass:self] bundleURL];
    NSURL *currentBundleEnclosingURL = [currentBundleURL URLByDeletingLastPathComponent];
    NSURL *updateBundleURL = [[NSURL fileURLWithPath:unzipDest] URLByAppendingPathComponent:@"Mouse Fix.prefPane"];
    
    
    
    
    
    
// prepare apple script which can install the update (executed within Mouse Fix Updater)
    
    
    // copy config.plist into the updated bundle
    
    NSString *configPathRelative = @"/Contents/Library/LoginItems/Mouse Fix Helper.app/Contents/Resources/config.plist";
    NSString *currentConfigOSAPath = [[[currentBundleURL path]  stringByAppendingPathComponent:configPathRelative]stringByReplacingOccurrencesOfString:@" " withString:@"\\\\ "];
    NSString *updateConfigOSAPath = [[[updateBundleURL path] stringByAppendingPathComponent:configPathRelative] stringByReplacingOccurrencesOfString:@" " withString:@"\\\\ "];
    
    // installing update
    
    
    NSString *currentBundleOSAPath = [[currentBundleURL path] stringByReplacingOccurrencesOfString:@" " withString:@"\\\\ "];
    NSString *currentBundleEnclosingOSAPath = [[[currentBundleURL path] stringByDeletingLastPathComponent] stringByReplacingOccurrencesOfString:@" " withString:@"\\\\ "];
    NSString *updateBundleOSAPath = [[updateBundleURL path] stringByReplacingOccurrencesOfString:@" " withString:@"\\\\ "];
    
    NSString *adminParamOSA = @"";
    if (![fm isWritableFileAtPath:[currentBundleEnclosingURL path]]
        || ![fm isWritableFileAtPath:[currentBundleURL path]]
        || ![fm isReadableFileAtPath:[updateBundleURL path]]) {
        NSLog(@"don't have permissions to install update - adding admin rights request to installScriptOSA");
        adminParamOSA = @" with administrator privileges";
    }
    
    // assemble the script
    
    NSString *installScriptOSA = [NSString stringWithFormat:@"do shell script \"rm %@;cp %@ %@;rm -r %@;cp -a %@ %@\"%@",
                                  updateConfigOSAPath,currentConfigOSAPath,updateConfigOSAPath,
                                  currentBundleOSAPath,updateBundleOSAPath,currentBundleOSAPath,
                                  adminParamOSA];
    //NSString *installScriptOSA = [NSString stringWithFormat:@"do shell script \"rm -r %@;cp -a %@ %@\"%@", currentOSAPath, updateOSAPath, currentEnclosingOSAPath, adminParamOSA];
    NSArray *args = @[installScriptOSA];
    
    NSLog(@"script: %@", installScriptOSA);
    
    // get the url to Mouse Fix Updater executable
    
    NSURL *updaterExecURL = [[[NSBundle bundleForClass:self] bundleURL] URLByAppendingPathComponent:@"Contents/Library/LaunchServices/Mouse Fix Updater"];
    
    // launch Mouse Fix Updater
    
    if (@available(macOS 10.13, *)) {
        NSError *launchUpdaterErr;
        [NSTask launchedTaskWithExecutableURL:updaterExecURL arguments:args error:&launchUpdaterErr terminationHandler:^(NSTask *task) {
            NSLog(@"updater terminated: %@", launchUpdaterErr);
        }];
        if (launchUpdaterErr) {
            NSLog(@"error launching updater: %@", launchUpdaterErr);
        }
    } else {
        [NSTask launchedTaskWithLaunchPath:[updaterExecURL path] arguments:args];
    }
    

    
    
    
//        if (NO) {//([fm fileExistsAtPath:[moveDest path]]) {
////            NSError *replaceError;
////            [fm replaceItemAtURL:[moveDest URLByAppendingPathComponent:@"Contents"] withItemAtURL:[moveSrc URLByAppendingPathComponent:@"Contents"] backupItemName:NULL options:NSFileManagerItemReplacementUsingNewMetadataOnly resultingItemURL:NULL error:&replaceError];
////            if (replaceError != NULL) {
////                NSLog(@"Replace file error: %@", replaceError);
////            }
//        } else {
//
//            id authObj = [SFAuthorization authorization];
//
//            NSError *authObtainErr;
//            //[authObj obtainWithRight:kAuthorizationRuleAuthenticateAsAdmin flags:(kAuthorizationFlagExtendRights | kAuthorizationFlagInteractionAllowed | kAuthorizationFlagDefaults) error:&authObtainErr];
//            AuthorizationRights *obtainedRights;
//
//
//
//
//            // TODO: doc says that .value has to be the path we want to execute
//
//            AuthorizationItem authItem = {kAuthorizationRightExecute, 0, NULL, 0};
//            AuthorizationRights requestedRights = {1, &authItem};
//
//            AuthorizationFlags authFlags = kAuthorizationFlagDefaults |
//            kAuthorizationFlagInteractionAllowed |
//            kAuthorizationFlagPreAuthorize |
//            kAuthorizationFlagExtendRights;
//
//
//            char promptText[100] = "Authorize Mouse Fix to install updates";
//            AuthorizationItem authEnvPrompt = {kAuthorizationEnvironmentPrompt, strlen(promptText), promptText, 0};
//
////            NSBundle *thisBundle = [NSBundle bundleForClass:self];
////            const char *promptIcon = [thisBundle pathForResource:@"Mouse_Fix_alt" ofType:@"tiff"].UTF8String;
////            AuthorizationItem authEnvIcon = {kAuthorizationEnvironmentIcon, strlen(promptIcon), (void *)promptIcon, 0};
//            // TODO: make the Icon work
//            // (note: will only work if the picture is accessible by everyone (permission wise)) (http://forestparklab.blogspot.com/2013/01/osx-authorizationexecutewithprivileges.html)
//
//            AuthorizationItem authEnvArray[1] = {authEnvPrompt};
//            AuthorizationEnvironment authEnv = {1, authEnvArray};
//
//            // TODO: use environment parameter to customize prompt
//            [authObj obtainWithRights:&requestedRights flags:authFlags environment:&authEnv authorizedRights:&obtainedRights error:&authObtainErr];
//            NSLog(@"authentication error: %@",authObtainErr);
//            if (obtainedRights->items) {
//                NSLog(@"obtained right: %s", obtainedRights->items[0].name);
//            }
//
//            NSError *removeError;
//            NSLog(@"remove URL: %@",moveDest);
//            BOOL removeResult = [fm removeItemAtURL:moveDest error:&removeError];
//            if (removeResult == NO) {
//                NSLog(@"Removing file error: %@", removeError);
//                //            return;
//            } else {
//            }
//            [NSThread sleepForTimeInterval:1];
//
//
//            NSError *moveError;
//            BOOL moveResult = [fm moveItemAtURL:moveSrc toURL:moveDest error:&moveError];
//            if (moveResult == NO) {
//                NSLog(@"Moving file error: %@", moveError);
//                return;
//            }
//
//
//        }

    // TODO: get modifying config working again (has it ever worked?)
    // TODO: use authorization services to install update if installed for all users
    // TODO: restart System preferences and kill the helper app
}

@end
