//
// --------------------------------------------------------------------------
// NSDictionary+Additions.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSDictionary (Additions)
    
    - (NSObject * _Nullable) objectForCoolKeyPath: (NSString *)keyPath;
    - (void) iterateCoolKeyPaths: (void (^)(NSString *keyPath, id object))callback;
    
    + (NSMutableDictionary *) doDeepMutateDictionary: (NSDictionary *)dict;
@end

@interface NSMutableDictionary (Additions)

    - (void) removeObjectForCoolKeyPath: (NSString *)keyPath;
    - (void) setObject: (NSObject * _Nullable)object forCoolKeyPath: (NSString *)keyPath;
    - (void) setObject: (NSObject * _Nullable)object forCoolKeyArray: (NSArray *)keys;

    - (void) applyOverridesFromDictionary: (NSDictionary *_Nullable)other;

@end

NS_ASSUME_NONNULL_END
