//
// --------------------------------------------------------------------------
// ConfigFileInterface_HelperApp.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>

@interface ConfigFileInterface_HelperApp : NSObject

typedef enum {
    kMFStateDidNotChange = NO,
    kMFStateDidChange = YES
} MFStateDidChange;

//@property (class, retain) NSMutableDictionary *config;
+ (NSMutableDictionary *)config;

+ (void)load_Manual;

+ (void)reactToConfigFileChange;
+ (MFStateDidChange)updateInternalParameters;
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

