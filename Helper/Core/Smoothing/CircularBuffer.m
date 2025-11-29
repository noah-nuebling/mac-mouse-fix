//
// --------------------------------------------------------------------------
// CircularBufferObjc.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2021
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// See: https://en.wikipedia.org/wiki/Circular_buffer
/// Implementing this in objc because Swift generics can't be used in objc, but the other way around works

#import "CircularBuffer.h"
#import "Logging.h"

@implementation CircularBuffer {
    /// Static vars
    NSInteger _capacity;
    NSMutableArray<id> *_buffer;
    /// Dynamic vars
    NSInteger _filled;
    NSUInteger _head; /// Head points to the next insertion point
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
        _buffer = [NSMutableArray arrayWithCapacity:n];
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
    
    [_buffer replaceObjectAtIndex:_head withObject:obj];
    
    _head = [self movedIndex:_head by:1];
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
    
    NSUInteger startIndex = [self movedIndex:_head by:-_filled];
    
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
    
    NSInteger idx = index; /// Need to cast `index` to signed integer, such that `idx + i` can become negative (I think??)
    
    NSInteger r = (idx + i) % _capacity;
    
    if (r < 0) {
        r = r + _capacity; /// Mod is implemented in a stupid way in c (truncated mod) so we have to use this to get it to behave like euclidian mod
    }
    
    assert(r >= 0);
    
    return r;
}

/// Other interface

- (NSInteger)capacity {
    return _capacity;
}

- (NSInteger)filled {
    return _filled;
}

@end
