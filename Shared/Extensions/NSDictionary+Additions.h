//
// --------------------------------------------------------------------------
// NSDictionary+Additions.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSDictionary (Additions)
- (NSObject * _Nullable)objectForCoolKeyPath:(NSString *)keyPath;
+ (NSMutableDictionary *)doDeepMutateDictionary:(NSDictionary *)dict;
@end

@interface NSMutableDictionary (Additions)
- (void)setObject:(NSObject * _Nullable)object forCoolKeyPath:(NSString *)keyPath;
- (void)setObject:(NSObject * _Nullable)object forCoolKeyArray:(NSArray *)keys;
@end

NS_ASSUME_NONNULL_END
