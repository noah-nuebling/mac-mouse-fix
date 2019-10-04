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
        [self loadConfigFromFile];
    }
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
}

+ (void)loadConfigFromFile {
    
    [self repairConfig];
    
    NSString *configPath = [[HelperServices helperBundle] pathForResource:@"config" ofType:@"plist"];
    NSData *configData = [NSData dataWithContentsOfFile:configPath];
    NSError *readErr;
    NSMutableDictionary *configDict = [NSPropertyListSerialization propertyListWithData:configData options:NSPropertyListMutableContainersAndLeaves format:nil error:&readErr];
    if (readErr) {
        NSLog(@"ERROR Reading config File: %@", readErr);
    }
    
    self.config = configDict;
}

+ (void)repairConfig {
    
    NSURL *currentBundleURL = [[NSBundle bundleForClass:self] bundleURL];
    
    NSString *currentConfigPathRelative = @"/Contents/Library/LoginItems/Mouse Fix Helper.app/Contents/Resources/config.plist";
        NSString *defaultConfigPathRelative = @"/Contents/Resources/default_config.plist";
    
    NSLog(@"default: %@", [NSDictionary dictionaryWithContentsOfURL:[currentBundleURL URLByAppendingPathComponent:defaultConfigPathRelative]]);
    
    NSURL *currentConfigURL = [currentBundleURL URLByAppendingPathComponent:currentConfigPathRelative];
    NSURL *defaultConfigURL = [currentBundleURL URLByAppendingPathComponent:defaultConfigPathRelative];
    
    NSNumber *currentConfigVersion = [[NSDictionary dictionaryWithContentsOfURL:currentConfigURL] valueForKeyPath:@"Other.configVersion"];
    NSNumber *defaultConfigVersion = [[NSDictionary dictionaryWithContentsOfURL:defaultConfigURL] valueForKeyPath:@"Other.configVersion"];
    
    if (currentConfigVersion.intValue != defaultConfigVersion.intValue) {
        NSData *defaultData = [NSData dataWithContentsOfURL:defaultConfigURL];
        [defaultData writeToURL:currentConfigURL atomically:YES];
        
        [MessagePort_PrefPane sendMessageToHelper:@"terminate"];
    }
}


@end
