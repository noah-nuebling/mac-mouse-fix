//
// --------------------------------------------------------------------------
// NSArray+Additions.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "NSArray+Additions.h"
#import "NSDictionary+Additions.h"

@implementation NSArray (Additions)


#pragma mark - Higher order functions
// source: https://medium.com/@weijentu/higher-order-functions-in-objective-c-850f6c90de30
- (NSArray *)map:(id (^)(id obj))block {
    NSMutableArray *mutableArray = [NSMutableArray new];
    [self enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [mutableArray addObject:block(obj)];
    }];
    return [mutableArray copy];
}
- (NSArray *)filter:(BOOL (^)(id obj))block {
    NSMutableArray *mutableArray = [NSMutableArray new];
    [self enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if (block(obj) == YES) {
            [mutableArray addObject:obj];
        }
    }];
    return [mutableArray copy];
}
- (id)reduce:(id)initial
       block:(id (^)(id obj1, id obj2))block {
    __block id obj = initial;
    [self enumerateObjectsUsingBlock:^(id _obj, NSUInteger idx, BOOL *stop) {
        obj = block(obj, _obj);
    }];
    return obj;
}
/// Noah: I might be misunderstanding but this doesn't seem to work
- (NSArray *)flatMap:(id (^)(id obj))block {
    NSMutableArray *mutableArray = [NSMutableArray new];
    [self enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        id _obj = block(obj);
        if ([_obj isKindOfClass:[NSArray class]]) {
            NSArray *_array = [_obj flatMap:block];
            [mutableArray addObjectsFromArray:_array];
            return;
        }
        [mutableArray addObject:_obj];
    }];
    return [mutableArray copy];
}

- (NSArray *)flattenedArray {
    if (self.count > 0 && ![self.firstObject isKindOfClass:NSArray.class]) {
        @throw [NSException exceptionWithName:@"ArrayDoesntConsistOfArraysException" reason:nil userInfo:nil];
    }
    NSMutableArray *flatArray = [NSMutableArray new];
    for (NSArray *sub in self) {
        [flatArray addObjectsFromArray:sub];
    }
    return flatArray.copy;
}

// Mutable deep copy
// Src: https://github.com/alfonsotesauro/NSDictionary-and-NSArray-Deep-mutable-copy/
+ (NSMutableArray *)doDeepMutateArray:(NSArray *)array {
    
    NSMutableArray *toReturn = [NSMutableArray arrayWithArray:array];
    
    for (id obj in array)
    {
        
        if ([obj isKindOfClass:[NSDictionary class]])
        {
            
            NSMutableDictionary *theNew = [NSMutableDictionary doDeepMutateDictionary:obj];
            
            [toReturn replaceObjectAtIndex:[array indexOfObject:obj] withObject:theNew];
        }
        else
            if ([obj isKindOfClass:[NSArray class]])
            {
                NSMutableArray *theNew = [self doDeepMutateArray:obj];
                
                [toReturn replaceObjectAtIndex:[array indexOfObject:obj] withObject:theNew];
                
            }
        
    }
    
    return toReturn;
    
}

@end
