//
// --------------------------------------------------------------------------
// ConfigFileInterface_Helper.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>

@interface ConfigFileInterface_Helper : NSObject

+ (void)load_Manual;

id config(NSString *keyPath);
+ (NSMutableDictionary *)config;

+ (void)reactToConfigFileChange;
+ (BOOL)applyOverridesForAppUnderMousePointer_Force:(BOOL)force;
+ (void)repairConfigFile:(NSString *)info;



//+ (void)start;
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

