//
// --------------------------------------------------------------------------
// SharedUtil.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>

#define fstring(format, ...) [NSString stringWithFormat:(format), ##__VA_ARGS__]

NS_ASSUME_NONNULL_BEGIN

@interface SharedUtil : NSObject
typedef void(*MFCTLCallback)(NSTask *task, NSPipe *output, NSError *error);

+ (NSString *)launchCTL:(NSURL *)executableURL withArguments:(NSArray<NSString *> *)arguments error:(NSError ** _Nullable)error;
+ (void)launchCLT:(NSURL *)commandLineTool withArgs:(NSArray <NSString *> *)arguments;
+ (void)launchCLT:(NSURL *)commandLineTool withArgs:(NSArray <NSString *> *)arguments callback:(MFCTLCallback _Nullable)callback;
+ (FSEventStreamRef)scheduleFSEventStreamOnPaths:(NSArray<NSString *> *)urls withCallback:(FSEventStreamCallback)callback;
+ (void)destroyFSEventStream:(FSEventStreamRef)stream;
@end

NS_ASSUME_NONNULL_END
