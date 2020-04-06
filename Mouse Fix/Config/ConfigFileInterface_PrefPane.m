//
// --------------------------------------------------------------------------
// ConfigFileInterface_PrefPane.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <AppKit/AppKit.h>
#import "ConfigFileInterface_PrefPane.h"
#import "HelperServices.h"
#import "../MessagePort/MessagePort_PrefPane.h"
#import "NSMutableDictionary+Additions.h"
#import "Utility_PrefPane.h"

// TODO: Implement clean function which deletes all overrides that don't change the default config. Adding and removing different apps in ScrollOverridePanel will accumulate dead entries.

@implementation ConfigFileInterface_PrefPane

static NSMutableDictionary *_config;
+ (NSMutableDictionary *)config {
    return _config;
}
+ (void)setConfig:(NSMutableDictionary *)new {
    _config = new;
}
// Backup config used to be called default config. There might still be references to default config that I missed.
static NSURL *_configURL;
static NSURL *_backupConfigURL;
+ (NSURL *)configURL {
    return _configURL;
}

+ (void)load {
    
    // Determine URLs of config and backupConfig
    
    NSURL *currentBundleURL = [[NSBundle bundleForClass:self] bundleURL];
//    NSString *currentConfigPathRelative = @"/Contents/Library/LoginItems/Mouse Fix Helper.app/Contents/Resources/config.plist";
    NSString *currentConfigPathRelative = @"/Contents/Library/LoginItems/Mouse Fix Helper.app/Contents/Resources/config.plist";
//        NSString *backupConfigPathRelative = @"/Contents/Resources/backup_config.plist";
    NSString *backupConfigPathRelative = @"/Contents/Resources/backup_config.plist";
    NSLog(@"default: %@", [NSDictionary dictionaryWithContentsOfURL:[currentBundleURL URLByAppendingPathComponent:backupConfigPathRelative]]);
    _configURL = [currentBundleURL URLByAppendingPathComponent:currentConfigPathRelative];
    _backupConfigURL = [currentBundleURL URLByAppendingPathComponent:backupConfigPathRelative];
    
    // Load config
    
    [self loadConfigFromFile];
}

/**
 Writes the _config dicitonary to the plist file at _configURL
 
 Should only be called by functions named `- setConfigToUI`
 
 \note For every window there should be @b one function `- setConfigToUI`
 \todo Learn documentation syntax
 */
+ (void)writeConfigToFileAndNotifyHelper {
    
    NSError *serializeErr;
    NSData *configData = [NSPropertyListSerialization dataWithPropertyList:self.config format:NSPropertyListXMLFormat_v1_0 options:0 error:&serializeErr];
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
    [MessagePort_PrefPane sendMessageToHelper:@"configFileChanged"];
}

/// Load data from plist file at _configURL into _config class variable
/// This only really needs to be called when ConfigFileInterface_PrefPane is loaded, but I use it in other places as well, to make the program behave better, when I manually edit the config file.
+ (void)loadConfigFromFile {
    
    [self repairConfigWithProblem:kMFConfigProblemNone info:nil];
    
    // TODO: Make this utilize the class variable `_currentConfigURL` instead.
    NSString *configPath = [[HelperServices helperBundle] pathForResource:@"config" ofType:@"plist"];
    NSData *configData = [NSData dataWithContentsOfFile:configPath];
    NSError *readErr;
    NSMutableDictionary *configDict = [NSPropertyListSerialization propertyListWithData:configData options:NSPropertyListMutableContainersAndLeaves format:nil error:&readErr];
    if (readErr) {
        NSLog(@"ERROR Reading config File: %@", readErr);
        // TODO: handle this error
    }
    self.config = configDict;
}

// TODO: Test if this still works
/// Checks config for errors / incompatibilty and repairs it if necessary.
+ (void)repairConfigWithProblem:(ConfigProblem)problem info:(id _Nullable)info {
    
    // TODO: Check whether all default (as opposed to override) values exist in config file. If they don't everything breaks. Maybe do this by comparing with config_backup.
    // TODO: Consider moving/copying this function to helper, so it can repair stuff as well.
    
    // check if config version matches, if not, replace with default.
    
    NSNumber *currentConfigVersion = [[NSDictionary dictionaryWithContentsOfURL:_configURL] valueForKeyPath:@"Other.configVersion"];
    NSNumber *backupConfigVersion = [[NSDictionary dictionaryWithContentsOfURL:_backupConfigURL] valueForKeyPath:@"Other.configVersion"];
    if (currentConfigVersion.intValue != backupConfigVersion.intValue) {
        [self replaceCurrentConfigWithBackupConfig];
    }
    
    // TODO: Check if this works
    // Check all AppOverrides in config for the parameters specified in `keyPaths`. If one of the parameters doesn't exist, initialize it with the default value from config.
    
    if (problem == kMFConfigProblemIncompleteAppOverride) {
        NSAssert(info && [info isKindOfClass:[NSDictionary class]], @"Can't repair incomplete app override: invalid argument provided");
        
        NSString *bundleID = info[@"bundleID"]; // Bundle ID of the app with the faulty override
        NSString *bundleIDEscaped = [bundleID stringByReplacingOccurrencesOfString:@"." withString:@"\\."];
        NSArray *keyPathsToDefaultValues = info[@"relevantKeyPaths"]; // KeyPaths to the values of which at least one is missing
        for (NSString *defaultKP in keyPathsToDefaultValues) {
            NSString *overrideKP = [NSString stringWithFormat:@"AppOverrides.%@.Root.%@", bundleIDEscaped, defaultKP];
            if ([_config objectForCoolKeyPath:overrideKP] == nil) {
                // If an override value doesn't exist at overrideKP, put default value at overrideKP.
                [_config setObject:[_config objectForCoolKeyPath:defaultKP] forCoolKeyPath:overrideKP];
            }
        }
        [self writeConfigToFileAndNotifyHelper];
    }
//        for (NSString *o in overrides) {
//            NSString *keyPath = NSString stringWithFormat:@"AppOverrides.%"
//        }
//        NSMutableDictionary *repairedOverrides = [overrides mutableCopy];
//        for (NSString *bundleID in overrides) {
//            NSMutableDictionary *repairedOverride = [repairedOverrides[bundleID] mutableCopy];
//            for (NSString *kp in keyPaths) {
//                if ([repairedOverride valueForKeyPath:kp] == nil) {
//                    NSObject *defaultVal = [_config valueForKeyPath:kp];
//                    [repairedOverride setObject:defaultVal forCoolKeyPath:kp];
//                }
//            }
//            repairedOverrides[bundleID] = repairedOverride;
//        }
//        _config[@"AppOverrides"] = repairedOverrides;
//    }
}

/// Replaces the current config file which the helper app is reading from with the backup one and then terminates the helper. (Helper will restart automatically because of the KeepAlive attribute in its user agent config file.)
+ (void)replaceCurrentConfigWithBackupConfig {
    NSData *defaultData = [NSData dataWithContentsOfURL:_backupConfigURL];
    [defaultData writeToURL:_configURL atomically:YES];
    [MessagePort_PrefPane sendMessageToHelper:@"terminate"];
    [self loadConfigFromFile];
}

+ (void)cleanUpConfig {
    // Clean up overrides for uninstalled apps
    NSMutableDictionary *appOverrides = _config[@"AppOverrides"];
    for (NSString *bundleID in appOverrides.allKeys) {
        if (![Utility_PrefPane appIsInstalled:bundleID]) {
            appOverrides[bundleID] = nil;
        }
    }
    [self writeConfigToFileAndNotifyHelper]; // No need to notify the helper at the time of writing
}

@end
