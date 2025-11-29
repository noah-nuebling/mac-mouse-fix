//
// --------------------------------------------------------------------------
// Queue.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "Queue.h"

@implementation Queue {
    NSMutableArray *_storage;
}

+ (id)queue {
    return [[Queue alloc] init];
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

- (NSArray *)dequeueAll {
    NSArray *result = [[_storage reverseObjectEnumerator] allObjects]; /// This also copies the object which I think is important so outsiders can't manipulate our `_storage`
    [_storage removeAllObjects];
    return result;
}

- (NSArray *)peekAll {
    NSArray *result = [[_storage reverseObjectEnumerator] allObjects];
    return result;
}

- (NSMutableArray *)_rawStorage { /// For outsiders to directly manipulate the underlying storage. Should probably not use `Queue` if this is necessary.
    return _storage;
}

@end
