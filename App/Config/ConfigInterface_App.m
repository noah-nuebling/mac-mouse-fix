//
// --------------------------------------------------------------------------
// ConfigFileInterface_App.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <AppKit/AppKit.h>
#import "ConfigInterface_App.h"
#import "HelperServices.h"
#import "SharedMessagePort.h"
#import "NSMutableDictionary+Additions.h"
#import "Utility_App.h"
#import "Objects.h"
#import "Constants.h"
#import "WannabePrefixHeader.h"
#import "Mac Mouse Fix-Bridging-Header.h"

@implementation ConfigInterface_App

#pragma mark - Convenience

/// Convenience function for accessing config
NSObject *config(NSString *keyPath) {
    return [ConfigInterface_App.config valueForKeyPath:keyPath];
}
/// Convenience function for modifying config
void setConfig(NSString *keyPath, NSObject *object) {
    [ConfigInterface_App.config setValue:object forKeyPath:keyPath];
}
/// Convenience function for writing config to file and notifying the helper app
void commitConfig() {
    [ConfigInterface_App writeConfigToFileAndNotifyHelper];
}

#pragma mark - Storage

static NSMutableDictionary *_config;
+ (NSMutableDictionary *)config {
    return _config;
}
+ (void)setConfig:(NSMutableDictionary *)new {
    _config = new;
}
static NSURL *_defaultConfigURL; /// `default_config` aka `backup_config`

#pragma mark - Init

+ (void)load {
    /// TODO: Should probably make this an initialize function so that config is guaranteed to be initialized before it's accessed.
    
    /// Get backup config url
    NSString *defaultConfigPathRelative = @"Contents/Resources/default_config.plist";
    _defaultConfigURL = [Objects.mainAppBundle.bundleURL URLByAppendingPathComponent:defaultConfigPathRelative];
    
    /// Load config
    [self loadConfigFromFile];
}

#pragma mark - Read and write from file

+ (void)writeConfigToFileAndNotifyHelper {
    
    /**
     Writes the `_config` dicitonary to the plist file at `_configURL`
     */
    
    NSError *serializeErr;
    NSData *configData = [NSPropertyListSerialization dataWithPropertyList:self.config format:NSPropertyListXMLFormat_v1_0 options:0 error:&serializeErr];
    if (serializeErr) {
        DDLogInfo(@"ERROR serializing configDictFromFile: %@", serializeErr);
    }
    NSError *writeErr;
    [configData writeToURL:Objects.configURL options:NSDataWritingAtomic error:&writeErr];
    if (writeErr) {
        DDLogInfo(@"ERROR writing configDictFromFile to file: %@", writeErr);
    }
    DDLogInfo(@"Wrote config to file.");
    [SharedMessagePort sendMessage:@"configFileChanged" withPayload:nil expectingReply:NO];
}



+ (void)loadConfigFromFile {
    
    /// Load data from plist file at `_configURL` into `_config` class variable
    /// This only really needs to be called when `ConfigFileInterface_App` is loaded, but I use it in other places as well, to make the program behave better, when I manually edit the config file.
    
    [self repairConfigWithProblem:kMFConfigProblemNone info:nil];
    
    NSData *configData = [NSData dataWithContentsOfURL:Objects.configURL];
    NSError *readErr;
    NSMutableDictionary *configDict = [NSPropertyListSerialization propertyListWithData:configData options:NSPropertyListMutableContainersAndLeaves format:nil error:&readErr];
    if (readErr) {
        DDLogInfo(@"Error Reading config File: %@", readErr);
        // TODO: handle this error
    }
    
    DDLogDebug(@"Loaded config from file: %@", configDict);
    
    self.config = configDict;
    
    /// Send reactive signal
    
}

#pragma mark - Repair

+ (void)repairConfigWithProblem:(MFConfigProblem)problem info:(id _Nullable)info {
    
    /// Checks config for errors / incompatibilty and repairs it if necessary.
    /// TODO: Test if this still works
    /// TODO: Check whether all default (as opposed to override) values exist in config file. If they don't, then everything breaks. Maybe do this by comparing with default_config. Edit: Not sure this is feasible, also the comparing with default_config breaks if we want to have keys that are optional.
    /// TODO: Consider moving/copying this function to helper, so it can repair stuff as well.
    
    /// Create config file if none exists
    
    if (![NSFileManager.defaultManager fileExistsAtPath:Objects.configURL.path]) {
        [NSFileManager.defaultManager createDirectoryAtURL:Objects.configURL.URLByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
        [self replaceCurrentConfigWithDefaultConfig];
    }
    
    /// Check if config version matches, if not, replace with default.
    
    NSNumber *currentConfigVersion = [[NSDictionary dictionaryWithContentsOfURL:Objects.configURL] valueForKeyPath:@"Other.configVersion"];
    NSNumber *defaultConfigVersion = [[NSDictionary dictionaryWithContentsOfURL:_defaultConfigURL] valueForKeyPath:@"Other.configVersion"];
    if (currentConfigVersion.intValue != defaultConfigVersion.intValue) {
        [self replaceCurrentConfigWithDefaultConfig];
    }
    
    /// Repair incomplete App override
    ///     Do this by simply copying over the values from the default config
    ///     TODO: Check if this works
    
    if (problem == kMFConfigProblemIncompleteAppOverride) {
        NSAssert(info && [info isKindOfClass:[NSDictionary class]], @"Can't repair incomplete app override: invalid argument provided");
        
        NSString *bundleID = info[@"bundleID"]; /// Bundle ID of the app with the faulty override
        NSString *bundleIDEscaped = [bundleID stringByReplacingOccurrencesOfString:@"." withString:@"\\."];
        NSArray *keyPathsToDefaultValues = info[@"relevantKeyPaths"]; /// KeyPaths to the values of which at least one is missing
        for (NSString *defaultKP in keyPathsToDefaultValues) {
            NSString *overrideKP = [NSString stringWithFormat:@"AppOverrides.%@.Root.%@", bundleIDEscaped, defaultKP];
            if ([_config objectForCoolKeyPath:overrideKP] == nil) {
                /// If an override value doesn't exist at overrideKP, put default value at overrideKP.
                [_config setObject:[_config objectForCoolKeyPath:defaultKP] forCoolKeyPath:overrideKP];
            }
        }
        [self writeConfigToFileAndNotifyHelper];
    }
}

+ (void)replaceCurrentConfigWithDefaultConfig {
    
    /// Replaces the current config file which the helper app is reading from with the backup one and then terminates the helper. (Helper will restart automatically because of the KeepAlive attribute in its user agent config file.)
    
    NSData *defaultData = [NSData dataWithContentsOfURL:_defaultConfigURL];
    [defaultData writeToURL:Objects.configURL atomically:YES];
    [SharedMessagePort sendMessage:@"terminate" withPayload:nil expectingReply:NO];
    [self loadConfigFromFile];
}

+ (void)cleanConfig {
    NSMutableDictionary *appOverrides = _config[kMFConfigKeyAppOverrides];
    
    /// Note: We don't delete overrides for uninstalled apps because this might delete preinstalled overrides
    
    removeLeaflessSubDicts(appOverrides);
    
    [self writeConfigToFileAndNotifyHelper]; /// No need to notify the helper at the time of writing
}

static void removeLeaflessSubDicts(NSMutableDictionary *dict) {
    
    /// Delete all paths in the dictionary which don't lead to anything
    // TODO: Implement cleaning function which deletes all overrides that don't change the default config. Adding and removing different apps in ScrollOverridePanel will accumulate dead entries. v is that what I meant?
    
    for (NSString *key in dict.allKeys) {
        NSObject *val = dict[key];
        if ([val isKindOfClass:[NSMutableDictionary class]]) {
            removeLeaflessSubDicts((NSMutableDictionary *)val);
            if (((NSMutableDictionary *)val).count == 0) {
                dict[key] = nil;
            }
        }
    }
}

@end
