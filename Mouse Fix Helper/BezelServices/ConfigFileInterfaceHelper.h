#import <Foundation/Foundation.h>


@interface ConfigFileInterfaceHelper : NSObject

@property (class, retain) NSMutableDictionary *config;
+ (void)reactToConfigFileChange;
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

