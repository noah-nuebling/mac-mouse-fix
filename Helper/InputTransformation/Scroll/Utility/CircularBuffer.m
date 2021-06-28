//
// --------------------------------------------------------------------------
// CircularBufferObjc.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under MIT
// --------------------------------------------------------------------------
//

/// See: https://en.wikipedia.org/wiki/Circular_buffer
/// Implementing this in objc because Swift generics can't be used in objc, but the other way around works

#import "CircularBuffer.h"
#import "WannabePrefixHeader.h"

@implementation CircularBuffer {
    /// Static vars
    NSInteger _capacity;
    NSMutableArray<id> *_buffer;
    /// Dynamic vars
    NSInteger _filled;
    NSUInteger _head;
}

/// Init

- (instancetype)init NS_UNAVAILABLE
{
    self = [super init];
    if (self) {
        assert(false);
    }
    return self;
}

- (instancetype)initWithCapacity:(NSInteger)n
{
    self = [super init];
    if (self) {
        
        _capacity = n;
        _filled = 0;
        _head = 0;
        _buffer = [NSMutableArray array];
        for (NSInteger i = 0; i < _capacity; i++) {
            [_buffer addObject:@(0)];
        }
        
    }
    return self;
}

/// Main

- (void)reset {
    _filled = 0;
}

- (void)add:(id)obj {
    _head = [self movedIndex:_head by:1];
    [_buffer replaceObjectAtIndex:_head withObject:obj];
    if (_filled < _capacity) {
        _filled += 1;
    }
}

- (NSArray *)content {
    
    NSMutableArray *result = [NSMutableArray new];
    
    if (_filled == 0) {
        DDLogDebug(@"Getting content of empty circular buffer.");
        return result;
    }
    
    NSUInteger startIndex = [self movedIndex:_head by:-(_filled - 1)];
    
    NSUInteger i = startIndex;
    while (true) {
        
        [result addObject:_buffer[i]];
        
        i = [self movedIndex:i by:1];
        
        if (i == _head) break;
    }
    
    return result;
}

/// Utility

- (NSUInteger)movedIndex:(NSUInteger)index by:(NSInteger)i {
    return (index + i) % _capacity;
}

/// Other interface

- (NSInteger)capacity {
    return _capacity;
}

- (NSInteger)filled {
    return _filled;
}

@end
