//
// --------------------------------------------------------------------------
// NSDictionary+Additions.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

/// TODO: Implement cleanup method
///     - Should delete paths in the dictionary that don't have any leaves
///     - This should work on nested data structures made up of dictionaries and arrays and leaves
///     - We're doing somewhat similar stuff (recursing over nested array + dictionary structures) in [SharedUtility + deepMutableCopyOf:]
///     - I think we might have already implemented a dictionary cleanup function somewhere for AppOverridePanel or the config.
///     - This should be useful whereever we store data. So for the config, the SecureStorage.swift, and NSUserDefaults (if we use that)

#import "NSDictionary+Additions.h"
#import "NSArray+Additions.h"

#pragma mark - Utiliy

static NSArray *coolKeyPathToKeyArray(NSString * _Nonnull keyPath) {
    
    /// Notes:
    /// - Regex tester: https://regex101.com/
    /// - The regex Matches all "." not preceded by "\" The actual, unescaped patterns is `(?<!\\)\.`
    /// - `\0` is the NULL character. Previously we used `@"<;jas;jfds;lfjasdf THIS IS A TEMPORARY REPLACEMENT STRING>"`
    
    /// Replace unescaped "." chars in the keyPath with temporary separator
    
    NSString *regex = @"(?<!\\\\)\\.";
    NSString *tempSeparator = @"\0";
    NSRange wholeStringRange = NSMakeRange(0, keyPath.length);
    
    NSString *keyPathTempSeparator = [keyPath stringByReplacingOccurrencesOfString:regex
                                                                        withString:tempSeparator
                                                                           options:NSRegularExpressionSearch
                                                                             range:wholeStringRange];
    /// Remove escape characters
    NSString *keyPathBackslashesRemoved = [keyPathTempSeparator stringByReplacingOccurrencesOfString:@"\\" withString:@""];
    
    /// Split keyPath along temporary separatorm
    NSArray *keys = [keyPathBackslashesRemoved componentsSeparatedByString:tempSeparator];
    
    /// Return
    return keys;
}

#pragma mark - Mutable dict

@implementation NSMutableDictionary (Additions)

- (void)removeObjectForCoolKeyPath:(NSString *)keyPath {
    /// Not sure this works. Maybe this should be recursive and remove every node along the keypath if it is empty after removing the leaf? Or maybe we should have a separate 'cleanup' method for that?
    [self setObject:nil forCoolKeyPath:keyPath];
}

- (void)setObject:(NSObject * _Nullable)object forCoolKeyPath:(NSString *)keyPath {
    
    /// Should function similar to `- setValue:forKeyPath:`
    /// Differences:
    /// Will create all dicts in the keyPath that don't exist, yet.
    /// If a key in the keyPath contains "." characters they can be escaped with "\.".
    /// All "\" will be removed from keys before parsing.
    ///     -> For example he keyPath @"a\.bc.d\\\\\ef" will be treated as two keys: @"a.bc" and @"def"
    
    NSArray * keys = coolKeyPathToKeyArray(keyPath);
    
    [self setObject:object forCoolKeyArray:keys];
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

@end

#pragma mark - Normal dict

@implementation NSDictionary (Additions)

- (NSObject * _Nullable)objectForCoolKeyPath:(NSString *)keyPath {
    
    NSArray *keys = coolKeyPathToKeyArray(keyPath);
    
    if (keys == nil) {
        return nil;
    }
    if (keys.count == 0) {
        return nil;
    }
    NSDictionary *thisNode = self;
    for (NSString *key in keys) {
        thisNode = thisNode[key];
        if (thisNode == nil) {
            return nil;
        }
    }
    return thisNode;
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
