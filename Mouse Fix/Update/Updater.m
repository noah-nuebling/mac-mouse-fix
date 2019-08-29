//
//  Updater.m
//  Mouse Fix
//
//  Created by Noah Nübling on 21.08.19.
//  Copyright © 2019 Noah Nuebling. All rights reserved.
//

#import "Updater.h"
#import "PrefPaneDelegate.h"
#import "ZipArchive/SSZipArchive.h"
#import "UpdateAvailableWindow.h"

@interface Updater ()
@property (class) NSURLSessionDownloadTask *downloadTask;
@end

@implementation Updater

# pragma mark - Class Globals
static NSURLSessionDownloadTask *_downloadTask;
+ (NSURLSessionTask *)downloadTask {
    return _downloadTask;
}
+ (void)setDownloadTask:(NSURLSessionDownloadTask *)newDownloadTask {
    _downloadTask = newDownloadTask;
}
static BOOL _updateAvailable = NO;
+ (BOOL)updateAvailable {
    return _updateAvailable;
}
static NSURLSession *_downloadSession;

# pragma mark - Class Methods

+ (void)load {
    [[NSBundle bundleForClass:[UpdateAvailableWindow class]] loadNibNamed:@"UpdateAvailableWindow" owner:[UpdateAvailableWindow class] topLevelObjects:NULL];
}

+ (void)initialize {
    
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
    
    _updateAvailable = NO;
    
    self.downloadTask = [_downloadSession downloadTaskWithURL:[NSURL URLWithString: @"https://noah-nuebling.github.io/mac-mouse-fix/maindownload/bundleversion"] completionHandler:^(NSURL * _Nullable location, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error != NULL){
            NSLog(@"checking for updates failed");
//            NSLog(@"Error: \n%@", error);
            return;
        }
        NSInteger currentVersion = [[[NSBundle bundleForClass:self] objectForInfoDictionaryKey:@"CFBundleVersion"] integerValue];
        NSInteger availableVersion = [[NSString stringWithContentsOfURL:location encoding:NSUTF8StringEncoding error:NULL] integerValue];
        NSLog(@"currentVersion: %ld, availableVersion: %ld", (long)currentVersion, (long)availableVersion);
        
        
        if (currentVersion < availableVersion && availableVersion != 193240) {
            _updateAvailable = YES;
        }
    }];
    [self.downloadTask resume];
}

+ (void)update {
    
    self.downloadTask = [_downloadSession downloadTaskWithURL:[NSURL URLWithString: @"https://noah-nuebling.github.io/mac-mouse-fix/maindownload/MacMouseFix.zip"] completionHandler:^(NSURL * _Nullable location, NSURLResponse * _Nullable response, NSError * _Nullable error) {

        if (error != NULL) {
            NSLog(@"Downloading error: %@", error);
            return;
        }
        NSFileManager *fm = [NSFileManager defaultManager];

        // unzip the downloaded file

        NSString *unzipDest = [[location path] stringByDeletingLastPathComponent];
        NSLog(@"unzip dest: %@",unzipDest);
        NSError *unzipError;
        [SSZipArchive unzipFileAtPath:[location path] toDestination:unzipDest overwrite:YES password:NULL error:&unzipError];
        if (unzipError != NULL) {
            NSLog(@"Unzipping error: %@", unzipError);
            return;
        }
        
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
    }];
    [self.downloadTask resume];
}

@end
