//
// --------------------------------------------------------------------------
// BiMap.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "BidirectionalMap.h"

@implementation BidirectionalMap {
    
    NSMutableDictionary *_leftMap;
    NSMutableDictionary *_rightMap;
}

/// Init

- (instancetype)init
{
    self = [super init];
    if (self) {
        _leftMap = [NSMutableDictionary dictionary];
        _rightMap = [NSMutableDictionary dictionary];
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)dict {
    
    BidirectionalMap *result = [self init];
    result->_leftMap = dict.mutableCopy;
    
    for (id key in dict.allKeys) {
        id value = dict[key];
        result->_rightMap[value] = key;
    }
    
    return self;
}

/// Setter

- (void)setLeftValue:(id)lhs forRightValue:(id)rhs {
    
    /// Prevent dangling one-way mappings
    _rightMap[_leftMap[lhs]] = nil;
    _leftMap[_rightMap[rhs]] = nil;
    
    /// Set new mapping
    _leftMap[lhs] = rhs;
    _rightMap[rhs] = lhs;
}

/// Deletors

- (void)removePairForLeftValue:(id)lhs {
    id rhs = _leftMap[lhs];
    _leftMap[lhs] = nil;
    _rightMap[rhs] = nil;
}
- (void)removePairForRightValue:(id)rhs {
    id lhs = _rightMap[rhs];
    _leftMap[lhs] = nil;
    _rightMap[rhs] = nil;
}

/// Getters

- (id)rightValueForLeftValue:(id)lhs {
    return _leftMap[lhs];
}
- (id)leftValueForRightValue:(id)rhs {
    return _rightMap[rhs];
}


@end
