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

@end

NS_ASSUME_NONNULL_END
