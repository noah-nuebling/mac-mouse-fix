//
// --------------------------------------------------------------------------
// NSDictionary+Additions.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "NSMutableDictionary+Additions.h"
#import "NSArray+Additions.h"

@implementation NSMutableDictionary (Additions)

// Regex tester: https://regex101.com/
static NSArray *coolKeyPathToKeyArray(NSString * _Nonnull keyPath) {
    NSString *regex = @"(?<!\\\\)\\."; // Matches all "." not preceded by "\" // Actual regex pattern: @"(?<!\\)\."
    NSString *tempSeparator = @"<;jas;jfds;lfjasdf THIS IS A TEMPORARY REPLACEMENT STRING>";
    NSString *keyPathTempSeparator = [keyPath stringByReplacingOccurrencesOfString:regex
                                                                        withString:tempSeparator
                                                                           options:NSRegularExpressionSearch
                                                                             range:NSMakeRange(0, keyPath.length)];
    NSString *keyPathBackslashesRemoved = [keyPathTempSeparator stringByReplacingOccurrencesOfString:@"\\" withString:@""];
    NSArray *keys = [keyPathBackslashesRemoved componentsSeparatedByString:tempSeparator];
    return keys;
}

/// Should function similar to `- setValue:forKeyPath:`
/// Differences:
/// Will create all dicts in the keyPath that don't exist, yet.
/// If a key in the keyPath contains "." characters they can be escaped with "\.".
/// All "\" will be removed from keys before parsing.
///     -> For example he keyPath @"a\.bc.d\\\\\ef" will be treated as two keys: @"a.bc" and @"def"
- (void)setObject:(NSObject * _Nullable)object forCoolKeyPath:(NSString *)keyPath {
    
    NSArray * keys = coolKeyPathToKeyArray(keyPath);
    
    [self setObject:object forCoolKeyArray:keys];
}

- (NSObject * _Nullable)objectForCoolKeyPath:(NSString *)keyPath {
    
    NSArray *keys = coolKeyPathToKeyArray(keyPath);
    
    if (keys == nil) {
        return nil;
    }
    if (keys.count == 0) {
        return nil;
    }
    NSMutableDictionary *thisNode = self;
    for (NSString *key in keys) {
        thisNode = thisNode[key];
        if (thisNode == nil) {
            return nil;
        }
    }
    return thisNode;
}

- (void)setObject:(NSObject * _Nullable)object forCoolKeyArray:(NSArray *)keys {
    NSMutableDictionary *thisNode = self;
    for (NSString *key in keys) {
        if ([keys indexOfObject:key] == keys.count - 1) { // `key` is last key
            thisNode[key] = object;
        } else { // `key` is inner key
            NSObject *nextNode = thisNode[key];
            NSObject *newNextNode;
            if (nextNode == nil) {
                newNextNode = [NSMutableDictionary dictionary];
            } else if ([nextNode isKindOfClass:[NSMutableDictionary class]]) {
                newNextNode = nextNode;
            } else if ([nextNode isKindOfClass:[NSDictionary class]]) {
                newNextNode = [nextNode mutableCopy];
            } else {
                NSException *exception = [NSException exceptionWithName:@"Invalid keyPath" reason:@"An inner key in the key array was not nil and not a dictionary." userInfo:@{@"dictionary": self, @"keyArray": keys}];
                @throw exception;
            }
            thisNode[key] = newNextNode;
            thisNode = (NSMutableDictionary *)newNextNode;
        }
    }
}

+ (NSMutableDictionary *)doDeepMutateDictionary:(NSDictionary *)dict {
    
    NSMutableDictionary *toReturn = [NSMutableDictionary dictionaryWithDictionary:dict];
    
    [dict enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        
        
        if ([obj isKindOfClass:[NSDictionary class]])
        {
            
            NSMutableDictionary *testg = [self doDeepMutateDictionary:obj];
            [toReturn setValue:testg forKey:key];
        }
        else
            if ([obj isKindOfClass:[NSArray class]])
            {
                NSMutableArray *theNew = [NSMutableArray doDeepMutateArray:obj];
                
                [toReturn setValue:theNew forKey:key];
                
            }
        
    }];
    
    return toReturn;
    
}

@end
