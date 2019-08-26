//
//  Updater.m
//  Mouse Fix
//
//  Created by Noah Nübling on 21.08.19.
//  Copyright © 2019 Noah Nuebling. All rights reserved.
//

#import "Updater.h"
//#import "SSZipArchive.h"

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
    
    self.downloadTask = [_downloadSession downloadTaskWithURL:[NSURL URLWithString: @"https://noah-nuebling.github.io/mac-mouse-fix/MainDownloadBundleVersion"] completionHandler:^(NSURL * _Nullable location, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error != NULL){
            NSLog(@"checking for updates failed");
//            NSLog(@"Error: \n%@", error);
            return;
        }
        NSInteger currentVersion = [[[NSBundle bundleForClass:self] objectForInfoDictionaryKey:@"CFBundleVersion"] integerValue];
        NSInteger availableVersion = [[NSString stringWithContentsOfURL:location encoding:NSUTF8StringEncoding error:NULL] integerValue];
        NSLog(@"currentVersion: %ld, availableVersion: %ld", (long)currentVersion, (long)availableVersion);
        if (currentVersion != availableVersion) {
            _updateAvailable = YES;
            
            // TODO: only update after the user confirmed
            [self update];
        }
    }];
    [self.downloadTask resume];
}

+ (void)update {
    
//    self.downloadTask = [_downloadSession downloadTaskWithURL:[NSURL URLWithString: @"https://noah-nuebling.github.io/mac-mouse-fix/MacMouseFix.zip"] completionHandler:^(NSURL * _Nullable location, NSURLResponse * _Nullable response, NSError * _Nullable error) {
//
//
//        if (error != NULL) {
//            NSLog(@"Downloading error: %@", error);
//            return;
//        }
//
//        NSString *unzipDest = [[location path] stringByDeletingLastPathComponent];
////        unzipDest = @"/Users/Noah/Desktop";
//        NSLog(@"unzip dest: %@",unzipDest);
//        NSError *unzipError;
//        [SSZipArchive unzipFileAtPath:[location path] toDestination:unzipDest overwrite:YES password:NULL error:&unzipError];
//        if (unzipError != NULL) {
//            NSLog(@"Unzipping error: %@", unzipError);
//            return;
//        }
//
//        NSFileManager *fm = [NSFileManager defaultManager];
//
//
//        NSString *prefPaneName = @"Mouse Fix.prefPane";
//        NSURL *moveSrc = [[NSURL fileURLWithPath:unzipDest] URLByAppendingPathComponent:prefPaneName];
//
////        [fm replaceItemAtURL:moveDest withItemAtURL:moveOrg backupItemName:NULL options:NSFileManagerItemReplacementUsingNewMetadataOnly resultingItemURL:NULL error:&moveError];
//
//        NSURL *moveDest = [[NSBundle bundleForClass:self] bundleURL];
//
////        moveDest = [NSURL fileURLWithPath:@"/Users/Noah/Desktop/"];
////        NSURL *moveDestFile = [moveDest URLByAppendingPathComponent:@"Mouse Fix.prefPane"];
//        NSLog(@"move dest: %@", moveDest);
//
//        NSError *removeError;
//        NSLog(@"remove URL: %@",moveDest);
//
//        [fm removeItemAtURL:moveDest error:&removeError];
//        if (removeError != NULL) {
//            NSLog(@"Removing file error: %@", removeError);
////            return;
//        } else {
//        }
//        [NSThread sleepForTimeInterval:1];
//
//
//        NSError *moveError;
//        [fm moveItemAtURL:moveSrc toURL:moveDest error:&moveError];
//        if (moveError != NULL) {
//            NSLog(@"Moving file error: %@", moveError);
//            return;
//        }
//
//    }];
//    [self.downloadTask resume];
}

@end
