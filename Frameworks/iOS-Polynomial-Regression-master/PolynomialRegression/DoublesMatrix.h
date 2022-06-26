//
//  2DMatrixOfDoubles.h
//  PolynomialRegression
//
//  Created by Gilles Lesire on 19/03/15.
//  GNU General Public License (GPL)
//  https://github.com/KingIsulgard/iOS-Polynomial-Regression
//

#import <Foundation/Foundation.h>

@interface DoublesMatrix : NSObject

@property (nonatomic, readwrite, strong) NSMutableArray *values;
@property (nonatomic, readwrite, assign) NSUInteger rows;
@property (nonatomic, readwrite, assign) NSUInteger columns;

- (instancetype)initWithSizeRows:(NSUInteger)m columns:(NSUInteger)n;
- (void)expandToRows:(NSUInteger)m columns:(NSUInteger)n;
- (void)setValueAtRow:(NSUInteger)m column:(NSUInteger)n value:(double)value;
- (double)valueAtRow:(NSUInteger)m column:(NSUInteger)n;

- (DoublesMatrix *)transpose;
- (DoublesMatrix *)multiplyWithMatrix:(DoublesMatrix *)matrix;

- (void)rotateLeft;
- (void)rotateRight;

- (void)rotateTop;
- (void)rotateBottom;

- (double)determinant;

- (DoublesMatrix *)duplicate;

@end
