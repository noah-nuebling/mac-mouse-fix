//
// --------------------------------------------------------------------------
// ConfigFileInterface_PrefPane.m
// Created for: Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by: Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "ConfigFileInterface_PrefPane.h"
#import "HelperServices.h"
#import "../MessagePort/MessagePort_PrefPane.h"

@implementation ConfigFileInterface_PrefPane

static NSMutableDictionary *_temporaryConfig; // private (would you say atomic?) cache for Config. For manipulating config without interference from other classes.

static NSMutableDictionary *_config;
+ (NSMutableDictionary *)config {
    return _config;
}
+ (void)setConfig:(NSMutableDictionary *)new {
    _config = new;
}

+ (void)initialize
{
    if (self == [ConfigFileInterface_PrefPane class]) {
        [self repairConfig];
        [self loadConfigFromFile];
    }
}

+ (void)writeConfigToFile {
    [self writeConfigToFile_From:_config];
}
+ (void)writeConfigToFile_From:(NSMutableDictionary *)source {
    
    NSError *serializeErr;
    NSData *configData = [NSPropertyListSerialization dataWithPropertyList:source format:NSPropertyListXMLFormat_v1_0 options:0 error:&serializeErr];
    if (serializeErr) {
        NSLog(@"ERROR serializing configDictFromFile: %@", serializeErr);
    }
    NSString *configPath = [[HelperServices helperBundle] pathForResource:@"config" ofType:@"plist"];
    //    BOOL success = [configData writeToFile:configPath atomically:YES];
    //    if (!success) {
    //        NSLog(@"ERROR writing configDictFromFile to file");
    //    }
    NSError *writeErr;
    [configData writeToFile:configPath options:NSDataWritingAtomic error:&writeErr];
    if (writeErr) {
        NSLog(@"ERROR writing configDictFromFile to file: %@", writeErr);
    }
    
    NSLog(@"Wrote config to file.");
//    NSLog(@"config: %@", _config);
}

+ (void)loadConfigFromFile {
    [self loadConfigFromFile_Into:_config];
}
+ (void)loadConfigFromFile_Into:(NSMutableDictionary *)destination {

    NSString *configPath = [[HelperServices helperBundle] pathForResource:@"config" ofType:@"plist"];
    NSData *configData = [NSData dataWithContentsOfFile:configPath];
    NSError *readErr;
    NSMutableDictionary *configDict = [NSPropertyListSerialization propertyListWithData:configData options:NSPropertyListMutableContainersAndLeaves format:nil error:&readErr];
    if (readErr) {
        NSLog(@"ERROR Reading config File: %@", readErr);
    }
    
    destination = configDict;
}

+ (void)repairConfig {
    
    // 1. Check the config.
    
    NSURL *currentBundleURL = [[NSBundle bundleForClass:self] bundleURL];
    
    NSString *currentConfigPathRelative = @"/Contents/Library/LoginItems/Mouse Fix Helper.app/Contents/Resources/config.plist";
    NSString *defaultConfigPathRelative = @"/Contents/Resources/default_config.plist"; // delfault_config.plist is a sort of backup that should always be compatible with the current installation
    
    
    NSURL *currentConfigURL = [currentBundleURL URLByAppendingPathComponent:currentConfigPathRelative];
    NSURL *defaultConfigURL = [currentBundleURL URLByAppendingPathComponent:defaultConfigPathRelative];
    
    NSNumber *currentConfigVersion = [[NSDictionary dictionaryWithContentsOfURL:currentConfigURL] valueForKeyPath:@"Other.configVersion"];
    NSNumber *defaultConfigVersion = [[NSDictionary dictionaryWithContentsOfURL:defaultConfigURL] valueForKeyPath:@"Other.configVersion"];
    
    if (currentConfigVersion.intValue == defaultConfigVersion.intValue) {
        return;
    }
    
    // 2. config-conflict! - repair the config
        // this is completely untested!!
    
    BOOL replace = NO;
    
    if (currentConfigVersion.intValue < defaultConfigVersion.intValue) {
        if (currentConfigVersion.intValue == 2 && defaultConfigVersion.intValue == 3) {
            [self loadConfigFromFile_Into:_temporaryConfig];
            BOOL success = [self convertTemporaryConfigFromVersion2ToVersion3];
            if (success) {
                [self writeConfigToFile_From:_temporaryConfig];
            } else {
                replace = TRUE;
            }
        } else {
            replace = TRUE;
        }
    }
    else if (currentConfigVersion.intValue > defaultConfigVersion.intValue) {
        // this should never happen - we should never update to a bundle with a lower config version
        replace = YES;
    }
    
    if (replace) {
        NSData *defaultData = [NSData dataWithContentsOfURL:defaultConfigURL];
        [defaultData writeToURL:currentConfigURL atomically:YES];
    }
    
    [MessagePort_PrefPane sendMessageToHelper:@"terminate"];
}


// ------------------------------------------------------

// update config files

+ (BOOL)convertTemporaryConfigFromVersion2ToVersion3 {
    @try {
        
        [_temporaryConfig valueForKeyPath:@"ScrollSettings.values"][2] = [NSNumber numberWithDouble:1.7];
        return YES;
        
    } @catch (NSError *e) {
        return NO;
    }
}

@end
