//
// --------------------------------------------------------------------------
// Queue.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Queue<T> : NSObject
+ (Queue<T> *)queue;
- (void)enqueue:(T)obj;
- (T)dequeue;
- (T)peek;
- (BOOL)isEmpty;
- (int64_t)count;
@end

NS_ASSUME_NONNULL_END
