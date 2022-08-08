//
//  PolynomialRegression.h
//  PolynomialRegression
//
//  Created by Gilles Lesire on 18/03/15.
//  GNU General Public License (GPL)
//  https://github.com/KingIsulgard/iOS-Polynomial-Regression
//

#import <Foundation/Foundation.h>
#import "DoublesMatrix.h"

@interface PolynomialRegression : NSObject
+ (NSArray<NSNumber *> * _Nonnull)regressionWithXValues:(NSArray<NSNumber *> * _Nonnull)xvals yValues:(NSArray<NSNumber *> * _Nonnull)yvals polynomialDegree:(NSUInteger)p;
@end
