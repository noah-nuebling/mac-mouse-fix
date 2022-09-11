//
// --------------------------------------------------------------------------
// PolyFitObjC.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/LICENSE)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PolyFit : NSObject

+ (NSArray <NSNumber *>* _Nonnull)fitWithX:(NSArray<NSNumber *> * _Nonnull)x y:(NSArray<NSNumber *> * _Nonnull)y polynomialDegree:(int)polyDegree;

@end

NS_ASSUME_NONNULL_END
