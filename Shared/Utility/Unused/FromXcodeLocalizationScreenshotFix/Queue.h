//
// --------------------------------------------------------------------------
// Queue.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// We copied and adapted this fom MMF
/// -> Should probably copy this back into MMF

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Queue<T> : NSObject
+ (Queue<T> *)queue;
- (void)enqueue:(T)obj;
- (T)dequeue;
- (NSArray <T>*)dequeueAll;
- (NSArray <T>*)peekAll;
- (T)peek;
- (BOOL)isEmpty;
- (int64_t)count;
- (NSMutableArray <T>*)_rawStorage;
@end

NS_ASSUME_NONNULL_END
