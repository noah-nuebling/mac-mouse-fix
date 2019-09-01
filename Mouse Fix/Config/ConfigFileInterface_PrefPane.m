//
//  ConfigFileInterface.m
//  Mouse Fix
//
//  Created by Noah Nübling on 29.08.19.
//  Copyright © 2019 Noah Nuebling. All rights reserved.
//

#import "ConfigFileInterface_PrefPane.h"
#import "HelperServices.h"

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
    NSString *configPath = [[HelperServices helperBundle] pathForResource:@"config" ofType:@"plist"];
    NSData *configData = [NSData dataWithContentsOfFile:configPath];
    NSError *readErr;
    NSMutableDictionary *configDict = [NSPropertyListSerialization propertyListWithData:configData options:NSPropertyListMutableContainersAndLeaves format:nil error:&readErr];
    if (readErr) {
        NSLog(@"ERROR Reading config File: %@", readErr);
    }
    
    self.config = configDict;
}


@end
