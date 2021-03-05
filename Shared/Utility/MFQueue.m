//
// --------------------------------------------------------------------------
// MFQueue.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "MFQueue.h"

@implementation MFQueue

NSMutableArray *_storage;

+ (id)queue {
    return [[MFQueue alloc] init];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _storage = [NSMutableArray array];
    }
    return self;
}

- (void)enqueue:(id)obj {
    [_storage insertObject:obj atIndex:0];
}
- (id)dequeue {
    id obj = [_storage lastObject];
    [_storage removeLastObject];
    return obj;
}
- (id)peek {
    return [_storage lastObject];
}
- (BOOL)isEmpty {
    return _storage.count == 0;
}
- (int64_t)count {
    return _storage.count;
}
@end
