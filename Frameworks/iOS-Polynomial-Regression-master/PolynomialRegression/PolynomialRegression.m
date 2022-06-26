//
//  PolynomialRegression.m
//  PolynomialRegression
//
//  Created by Gilles Lesire on 22/03/15.
//  GNU General Public License (GPL)
//  https://github.com/KingIsulgard/iOS-Polynomial-Regression
//

#import "PolynomialRegression.h"

@implementation PolynomialRegression

+ (NSMutableArray *)regressionWithXValues:(NSMutableArray *)xvals yValues:(NSMutableArray *)yvals polynomialDegree:(NSUInteger)p
{
    NSCParameterAssert(p > 0);
    NSCAssert([xvals count] == [yvals count], @"There should be as many x values as y values. Given %lu x values and %lu y values.", [xvals count], [yvals count]);
    
    DoublesMatrix *z = [[DoublesMatrix alloc] initWithSizeRows:[xvals count] columns: (p + 1)];
    
    for (NSUInteger i = 0; i < [xvals count]; i++) {
        for (NSUInteger j = 0; j <= p; j++) {
            double val = pow([xvals[i] doubleValue], (double) j);
            [z setValueAtRow: i column: j value: val];
        }
    }
    
    DoublesMatrix *y = [[DoublesMatrix alloc] initWithSizeRows:[yvals count] columns: 1];
    
    for (NSUInteger u = 0; u < [yvals count]; u++) {
        [y setValueAtRow: u column: 0 value: [yvals[u] doubleValue]];
    }
    
    DoublesMatrix *z_transposed = [z transpose];
    DoublesMatrix *l = [z_transposed multiplyWithMatrix: z];
    DoublesMatrix *r = [z_transposed multiplyWithMatrix: y];
    
    DoublesMatrix *regression = [self solve_for: l andR: r];
    NSMutableArray *result = [[NSMutableArray alloc] init];
    
    for (NSUInteger i = 0; i <= p; i++) {
        double value = [regression valueAtRow:i column:0];
        [result addObject: @(value)];
    }
    
    return result;
}

+ (DoublesMatrix *) solve_for: (DoublesMatrix *) l andR: (DoublesMatrix *) r
{
    
    DoublesMatrix *resultMatrix = [[DoublesMatrix alloc] initWithSizeRows: l.rows columns: 1];
    
    NSMutableArray *resDecomp = [self decompose: l];
    
    DoublesMatrix *nP = resDecomp[2];
    DoublesMatrix *lMatrix = resDecomp[1];
    DoublesMatrix *uMatrix = resDecomp[0];
    
    for (NSUInteger k = 0; k < r.rows; k++) {
        double sum = 0.0f;
        
        DoublesMatrix *dMatrix = [[DoublesMatrix alloc] initWithSizeRows: l.rows columns: 1];
        
        double val1 = [r valueAtRow: (int) [nP valueAtRow: 0 column: 0] column: k];
        double val2 = [lMatrix valueAtRow: 0 column: 0];
        [dMatrix setValueAtRow: 0 column: 0 value: val1 / val2];
        
        for (NSUInteger i = 1; i < l.rows; i++) {
            sum = 0.0f;
            for (NSUInteger j = 0; j < i; j++) {
                sum += ([lMatrix valueAtRow: i column: j] * [dMatrix valueAtRow: j column: 0]);
            }
            
            double value = [r valueAtRow:(NSUInteger)[nP valueAtRow: i column: 0] column: k];
            value -= sum;
            value /= [lMatrix valueAtRow: i column: i];
            [dMatrix setValueAtRow: i column: 0 value: value];
        }
        
        [resultMatrix setValueAtRow: (l.rows - 1) column: k value: [dMatrix valueAtRow: (l.rows - 1) column: 0]];
        
        for (NSInteger i = (l.rows - 2); i >= 0; i--) {
            sum = 0.0f;
            for (NSUInteger j = i + 1; j < l.rows; j++) {
                sum += ([uMatrix valueAtRow: i column: j] * [resultMatrix valueAtRow: j column: k]);
            }
            [resultMatrix setValueAtRow: i column: k value: ([dMatrix valueAtRow: i column: 0] - sum)];
        }
    }
    
    return resultMatrix;
}

+ (NSMutableArray *) decompose: (DoublesMatrix *) l
{
    DoublesMatrix *uMatrix = [[DoublesMatrix alloc] initWithSizeRows: 1 columns: 1];
    DoublesMatrix *lMatrix = [[DoublesMatrix alloc] initWithSizeRows: 1 columns: 1];
    DoublesMatrix *workingUMatrix = [l duplicate];
    DoublesMatrix *workingLMatrix = [[DoublesMatrix alloc] initWithSizeRows: 1 columns: 1];
    
    DoublesMatrix *pivotArray = [[DoublesMatrix alloc] initWithSizeRows: l.rows columns: 1];
    
    for (NSUInteger i = 0; i < l.rows; i++) {
        [pivotArray setValueAtRow: i column: 0 value: (double) i];
    }
    
    for (int i = 0; i < l.rows; i++) {
        double maxRowRatio = -2147483648;
        NSInteger maxRow = -1;
        NSInteger maxPosition = -1;
        
        for (NSUInteger j = i; j < l.rows; j++) {
            double rowSum = 0.0f;
            
            for (NSUInteger k = i; k < l.rows; k++) {
                rowSum += fabs([workingUMatrix valueAtRow: (NSInteger) [pivotArray valueAtRow: j column: 0] column: k]);
            }
            
            double dCurrentRatio = fabs([workingUMatrix valueAtRow: (NSInteger) [pivotArray valueAtRow: j column: 0] column: i]) / rowSum;
            
            if (dCurrentRatio > maxRowRatio) {
                maxRowRatio = (int) fabs([workingUMatrix valueAtRow: (NSInteger) [pivotArray valueAtRow: j column: 0] column: i]) / rowSum;
                maxRow = (int) [pivotArray valueAtRow: j column: 0];
                maxPosition = j;
            }
        }
        
        if (maxRow != (int) [pivotArray valueAtRow: i column: 0]) {
            double hold = [pivotArray valueAtRow: i column: 0];
            [pivotArray setValueAtRow: i column: 0 value: (double) maxRow];
            [pivotArray setValueAtRow: maxPosition column: 0 value: hold];
        }
        
        double rowFirstElementValue = [workingUMatrix valueAtRow: (int) [pivotArray valueAtRow: i column: 0] column: i];
        
        for (int j = 0; j < l.rows; j++) {
            if (j < i) {
                [workingUMatrix setValueAtRow: (NSInteger) [pivotArray valueAtRow: i column: 0] column: j value: 0.0f];
            } else if (j == i) {
                [workingLMatrix setValueAtRow: (NSInteger) [pivotArray valueAtRow: i column: 0] column: j value: rowFirstElementValue];
                [workingUMatrix setValueAtRow: (NSInteger) [pivotArray valueAtRow: i column: 0] column: j value: 1.0f];
            } else {
                double tempValue = [workingUMatrix valueAtRow: (NSInteger) [pivotArray valueAtRow: i column: 0] column: j];
                [workingUMatrix setValueAtRow: (NSInteger) [pivotArray valueAtRow: i column: 0] column: j value: tempValue / rowFirstElementValue];
                [workingLMatrix setValueAtRow: (NSInteger) [pivotArray valueAtRow: i column: 0] column: j value: 0.0f];
            }
        }
        
        for (int k = i + 1; k < l.rows; k++) {
            rowFirstElementValue = [workingUMatrix valueAtRow: (NSInteger) [pivotArray valueAtRow: k column: 0] column: i];
            
            for (int j = 0; j < l.rows; j++) {
                if (j < i) {
                    [workingUMatrix setValueAtRow: (NSInteger) [pivotArray valueAtRow: k column: 0] column: j value: 0.0f];
                } else if (j == i) {
                    [workingLMatrix setValueAtRow: (NSInteger) [pivotArray valueAtRow: k column: 0] column: j value: rowFirstElementValue];
                    [workingUMatrix setValueAtRow: (NSInteger) [pivotArray valueAtRow: k column: 0] column: j value: 0.0f];
                } else {
                    double tempValue = [workingUMatrix valueAtRow: (NSInteger) [pivotArray valueAtRow: k column: 0] column: j];
                    double tempValue2 = [workingUMatrix valueAtRow: (NSInteger) [pivotArray valueAtRow: i column: 0] column: j];
                    [workingUMatrix setValueAtRow: (NSInteger) [pivotArray valueAtRow: k column: 0] column: j value: tempValue - (rowFirstElementValue * tempValue2)];
                }
            }
        }
    }
    
    for (int i = 0; i < l.rows; i++) {
        for (int j = 0; j < l.rows; j++) {
            double uValue = [workingUMatrix valueAtRow: (NSInteger) [pivotArray valueAtRow: i column:0] column: j];
            double lValue = [workingLMatrix valueAtRow: (NSInteger) [pivotArray valueAtRow: i column:0] column: j];
            [uMatrix setValueAtRow: i column: j value: uValue];
            [lMatrix setValueAtRow: i column: j value: lValue];
        }
    }
    
    NSMutableArray *result = [[NSMutableArray alloc] init];
    [result addObject: uMatrix];
    [result addObject: lMatrix];
    [result addObject: pivotArray];
    
    return result;
}
@end