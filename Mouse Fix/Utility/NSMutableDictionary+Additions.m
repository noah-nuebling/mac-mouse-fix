//
// --------------------------------------------------------------------------
// NSDictionary+Additions.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "NSMutableDictionary+Additions.h"

@implementation NSMutableDictionary (Additions)

- (void)test {
    NSLog(@"Cool Stuff");
}

static NSArray *coolKeyPathToKeyArray(NSString * _Nonnull keyPath) {
    NSString *regex = @"(?<!\\\\)\\."; // Matches all "." not preceded by "\" // Actual pattern: @"(?<!\\)\."
    NSString *tempSeparator = @"<TEMPORARY REPLACEMENT STRING>";
    NSString *keyPathTempSeparator = [keyPath stringByReplacingOccurrencesOfString:regex
                                                                        withString:tempSeparator
                                                                           options:NSRegularExpressionSearch
                                                                             range:NSMakeRange(0, keyPath.length)];
    NSString *keyPathBackslashesRemoved = [keyPathTempSeparator stringByReplacingOccurrencesOfString:@"\\" withString:@""];
    NSArray *keys = [keyPathBackslashesRemoved componentsSeparatedByString:tempSeparator];
    return keys;
}

// Regex tester: https://regex101.com/
/// Should function similar to `- setValue:forKeyPath:`
/// Differences:
/// Will create all dicts in the keyPath that don't exist, yet.
/// If a key in the keyPath contains "." characters they can be escaped with "\.".
/// All "\" will be removed from keys before parsing.
///     -> For example he keyPath @"a\.bc.d\\\\\ef" will be treated as two keys: @"a.bc" and @"def"
- (void)setObject:(NSObject * _Nullable)object forCoolKeyPath:(NSString *)keyPath {
    
    NSArray * keys = coolKeyPathToKeyArray(keyPath);
    
    NSMutableDictionary *thisNode = self;
    for (NSString *key in keys) {
        if ([keys indexOfObject:key] == keys.count - 1) { // Last key
            thisNode[key] = object;
        } else { // Inner key
            NSObject *nextNode = thisNode[key];
            NSObject *newNextNode;
            if (nextNode == nil) {
                newNextNode = [NSMutableDictionary dictionary];
            } else if ([nextNode isKindOfClass:[NSMutableDictionary class]]) {
                newNextNode = nextNode;
            } else if ([nextNode isKindOfClass:[NSDictionary class]]) {
                newNextNode = [nextNode mutableCopy];
            } else {
                NSException *exception = [NSException exceptionWithName:@"Invalid keyPath" reason:@"An inner key in the keyPath was not nil and not a dictionary." userInfo:@{@"dictionary": self, @"keyPath": keyPath}];
                @throw exception;
            }
            thisNode[key] = newNextNode;
            thisNode = (NSMutableDictionary *)newNextNode;
        }
    }
}

- (NSObject *)objectForCoolKeyPath:(NSString *)keyPath {
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

@end
