//
//  ConfigFileMonitor.h
//  Mouse Remap Helper
//
//  Created by Noah Nübling on 19.11.18.
//  Copyright © 2018 Noah Nuebling Enterprises Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

//NS_ASSUME_NONNULL_BEGIN

@interface ConfigFileInterface : NSObject

@property (class, retain) NSMutableDictionary *config;
+ (void)repairConfigFile:(NSString *)info;

//+ (void)start;

+ (void)reactToConfigFileChange;

//@property (retain) NSMutableDictionary *configDictFromFile;

//@property (retain) ConfigFileMonitor *selfInstance;

/*
- (void) Handle_FSEventStreamCallback: (ConstFSEventStreamRef) streamRef
                   clientCallBackInfo: (void *)clientInfo
                            numEvents: (size_t)nEvents
                           eventPaths: (void *)evPaths
                           eventFlags: (const FSEventStreamEventFlags *)evFlags
                             eventIds: (const FSEventStreamEventId *)evIds;
 */
@end

//NS_ASSUME_NONNULL_END
