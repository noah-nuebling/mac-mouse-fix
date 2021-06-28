//
// --------------------------------------------------------------------------
// CircularBufferObjc.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CircularBuffer<T> : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithCapacity:(NSInteger)n;

- (void)reset;
- (void)add:(T)obj;
- (NSArray<T> *)content;

- (NSInteger)capacity;
- (NSInteger)filled;

@end

NS_ASSUME_NONNULL_END
