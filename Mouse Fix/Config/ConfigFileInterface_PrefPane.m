//
// --------------------------------------------------------------------------
// ConfigFileInterface_PrefPane.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "ConfigFileInterface_PrefPane.h"
#import "HelperServices.h"
#import "../MessagePort/MessagePort_PrefPane.h"

// TODO: Implement clean function which deletes all overrides that don't change the default config. Adding and removing different apps in ScrollOverridePanel will accumulate dead entries.

@implementation ConfigFileInterface_PrefPane

static NSMutableDictionary *_config;
+ (NSMutableDictionary *)config {
    return _config;
}
+ (void)setConfig:(NSMutableDictionary *)new {
    _config = new;
}

static NSURL *_configURL;
static NSURL *_defaultConfigURL;
+ (NSURL *)configURL {
    return _configURL;
}

+ (void)initialize
{
    if (self == [ConfigFileInterface_PrefPane class]) {
        [self loadConfigFromFile];
    }
    
    // load current and default config
    
    NSURL *currentBundleURL = [[NSBundle bundleForClass:self] bundleURL];
    NSString *currentConfigPathRelative = @"/Contents/Library/LoginItems/Mouse Fix Helper.app/Contents/Resources/config.plist";
        NSString *defaultConfigPathRelative = @"/Contents/Resources/default_config.plist";
    NSLog(@"default: %@", [NSDictionary dictionaryWithContentsOfURL:[currentBundleURL URLByAppendingPathComponent:defaultConfigPathRelative]]);
    _configURL = [currentBundleURL URLByAppendingPathComponent:currentConfigPathRelative];
    _defaultConfigURL = [currentBundleURL URLByAppendingPathComponent:defaultConfigPathRelative];
}

+ (void)writeConfigToFile {
    
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

+ (void)loadConfigFromFile {
    
    [self repairConfig];
    
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
+ (void)repairConfig {
    
    // check if config version matches
    
    NSNumber *currentConfigVersion = [[NSDictionary dictionaryWithContentsOfURL:_configURL] valueForKeyPath:@"Other.configVersion"];
    NSNumber *defaultConfigVersion = [[NSDictionary dictionaryWithContentsOfURL:_defaultConfigURL] valueForKeyPath:@"Other.configVersion"];
    if (currentConfigVersion.intValue != defaultConfigVersion.intValue) {
        [self replaceCurrentConfigWithDefaultConfig];
    }
}

/// Replaces the current config file which the helper app is reading from with the default one and then terminates the helper. (Helper will restart automatically because of the KeepAlive attribute in its user agent config file.)
+ (void)replaceCurrentConfigWithDefaultConfig {
    NSData *defaultData = [NSData dataWithContentsOfURL:_defaultConfigURL];
    [defaultData writeToURL:_configURL atomically:YES];
    [MessagePort_PrefPane sendMessageToHelper:@"terminate"];
}

@end
