//
// --------------------------------------------------------------------------
// EventTapQueue.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
@import Foundation;

NS_ASSUME_NONNULL_BEGIN

@interface InputThread : NSObject

+ (CFRunLoopRef)runLoop;

+ (void)execute:(nonnull void (^)(void))block;
+ (void)executeSyncIfPossible:(nonnull void (^)(void))block;
+ (NSTimer *)executeAfter:(CFTimeInterval)interval block:(nonnull void (^)(NSTimer * _Nonnull))block;
+ (BOOL)runningOnInputThread;

@end

NS_ASSUME_NONNULL_END
