//
// --------------------------------------------------------------------------
// MFMessagePort.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MFMessagePort : NSObject

+ (void)load_Manual;

+ (NSObject *_Nullable)sendMessage:(NSString * _Nonnull)message withPayload:(NSObject <NSCoding> * _Nullable)payload waitForReply:(BOOL)replyExpected;
+ (NSObject *_Nullable)sendMessage:(NSString * _Nonnull)message withPayload:(NSObject<NSCoding> * _Nullable)payload toRemotePort:(NSString *)remotePortName waitForReply:(BOOL)waitForReply;

#if DEBUG
/// Exercises the same callback/archive path as an incoming CFMessagePort request.
/// The caller must invoke this on the main thread, matching the production run-loop source.
+ (NSData *_Nullable)dispatchArchivedMessageDataForTesting:(NSData *)data;
#endif

@end

NS_ASSUME_NONNULL_END
