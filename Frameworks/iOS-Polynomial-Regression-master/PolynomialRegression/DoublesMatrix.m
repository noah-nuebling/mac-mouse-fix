//
//  2DMatrixOfDoubles.m
//  PolynomialRegression
//
//  Created by Gilles Lesire on 19/03/15.
//  GNU General Public License (GPL)
//  https://github.com/KingIsulgard/iOS-Polynomial-Regression
//

#import "DoublesMatrix.h"

@implementation DoublesMatrix

/**
 * Matrix init
 *
 * Create an empty matrix with zeros of size rowsxcolumns
 */
- (instancetype)initWithSizeRows:(NSUInteger)m columns:(NSUInteger)n
{
    if (!(self = [super init])) return nil;

    _rows = m;
    _columns = n;
    _values = [[NSMutableArray alloc] init];
    
    for (int i = 0; i < m; i++) {
        NSMutableArray *nValues = [[NSMutableArray alloc] init];
        
        for (int j = 0; j < n; j++) {
            [nValues addObject: @0];
        }
        
        [_values addObject: nValues];
    }

    return self;
}

/**
 * Matrix expand
 *
 * Resize the array to a bigger size if needed
 */
- (void)expandToRows:(NSUInteger)m columns:(NSUInteger)n
{
    if (self.columns < n) {
        for (int i = 0; i < self.rows; i++) {
            NSUInteger adder = n - self.columns;
            for (int j = 0; j < adder; j++) {
                [self.values[i] addObject: @0];
            }
        }

        self.columns = n;
    }
    
    if (self.rows < m) {
        NSUInteger adder = m - self.rows;
        for (int i = 0; i < adder; i++) {
            NSMutableArray *nValues = [[NSMutableArray alloc] init];
            for (int j = 0; j < n; j++) {
                [nValues addObject: @0];
            }
            
            [self.values addObject: nValues];
        }

        self.rows = m;
    }
}

/**
 * Matrix setvalue
 *
 * Set the value at a certain row and column
 */
- (void)setValueAtRow:(NSUInteger)m column:(NSUInteger)n value:(double)value
{
    if (m >= self.rows || n >= self.columns) {
        [self expandToRows: (m + 1) columns: (n + 1)];
    }
    
    NSNumber *val = @(value);
    [self.values[m] setObject: val atIndex: n];
}

/**
 * Matrix getvalue
 *
 * Get the value at a certain row and column
 */
- (double)valueAtRow:(NSUInteger)m column:(NSUInteger)n
{
    if (m >= self.rows || n >= self.columns) {
        [self expandToRows: (m + 1) columns: (n + 1)];
    }
    
    return [self.values[m][n] doubleValue];
}

/**
 * Matrix transpose
 * Result is a new matrix created by transposing this current matrix
 *
 * Eg.
 * [1,2,3]
 * [4,5,6]
 * becomes
 * [1,4]
 * [2,5]
 * [3,6]
 *
 * @link http://en.wikipedia.org/wiki/Transpose Wikipedia
 */
- (DoublesMatrix *)transpose
{
    DoublesMatrix *transposed = [[DoublesMatrix alloc] initWithSizeRows:self.columns columns:self.rows];
    
    for (int i = 0; i < self.rows; i++) {
        for (int j = 0; j < self.columns; j++) {
            double value = [self valueAtRow: i column: j];
            [transposed setValueAtRow: j column: i value: value];
        }
        
    }
    
    return transposed;
}

/**
 * Matrix multiply
 * Result is a new matrix created by multiplying this current matrix with a given matrix
 * The current matrix A should have just as many columns as the given matrix B has rows
 * otherwise multiplication is not possible
 *
 * The result of a mxn matrix multiplied with an nxp matrix resulsts in a mxp matrix
 * (AB)_{ij} = \sum_{r=1}^n a_{ir}b_{rj} = a_{i1}b_{1j} + a_{i2}b_{2j} + \cdots + a_{in}b_{nj}.
 *
 * @link http://en.wikipedia.org/wiki/Matrix_multiplication Wikipedia
 */
- (DoublesMatrix *) multiplyWithMatrix: (DoublesMatrix *) matrix
{
    NSCAssert(self.columns == matrix.rows, @"There should be as many columns in matrix A (this matrix) as there are rows in matrix B (parameter matrix) to multiply. Matrix A has %lu columns and matrix B has %lu rows.", self.columns, matrix.rows);
    
    // The result of a mxn matrix multiplied with an nxp matrix resulsts in a mxp matrix
    DoublesMatrix *result = [[DoublesMatrix alloc] initWithSizeRows:self.rows columns:matrix.columns];
    
    for (int r_col = 0; r_col < matrix.columns; r_col++) {
        for (int l_row = 0; l_row < self.rows; l_row++) {
            // For field Rij we need to make the sum of AixBxj
            double value = 0.0f;
            for (int col = 0; col < self.columns; col++) {
                value += ([self valueAtRow: l_row column: col] * [matrix valueAtRow: col column: r_col]);
            }
            [result setValueAtRow: l_row column: r_col value: value];
        }
    }
    
    return result;
}

/**
 * Matrix rotateLeft
 *
 * Rotate all row elements in the matrix one column to the left
 */
- (void)rotateLeft
{
    // Shift all rows
    for (int m = 0; m < self.rows; m++) {
        NSMutableArray *row = self.values[m];
        NSNumber *shiftObject = row[0];
        [row removeObjectAtIndex: 0];
        [row addObject: shiftObject];
    }
}

/**
 * Matrix rotateRight
 *
 * Rotate all row elements in the matrix one column to the right
 */
- (void)rotateRight
{
    // Shift all rows
    for (int m = 0; m < self.rows; m++) {
        NSMutableArray *row = self.values[m];
        NSNumber *shiftObject = row[self.columns - 1];
        [row removeObjectAtIndex: self.columns - 1];
        [row insertObject: shiftObject atIndex: 0];
    }
}

/**
 * Matrix rotateTop
 *
 * Rotate all column elements in the matrix one row to the top
 */
- (void)rotateTop
{
    NSMutableArray *row = self.values[0];
    [self.values removeObjectAtIndex: 0];
    [self.values addObject: row];
}

/**
 * Matrix rotateBottom
 *
 * Rotate all column elements in the matrix one row to the bottom
 */
- (void)rotateBottom
{
    NSMutableArray *row = self.values[self.rows - 1];
    [self.values removeObjectAtIndex: self.rows - 1];
    [self.values insertObject: row atIndex: 0];
}

/**
 * Matrix determinant
 *
 * Calculates the determinant value of the matrix
 *
 * Eg.
 * [1,2,3]
 * [4,5,6]
 * calculates
 * 1*5*3 + 2*6*1 + 3*4*2 - 3*5*1 - 2*4*3 - 1*6*2
 * equals 0
 *
 * @link http://en.wikipedia.org/wiki/Determinant Wikipedia
 */
- (double)determinant
{
    double det = 0;
    
    for (int i = 0; i < self.rows; i++) {
        double product = 1;
        
        for (int j = 0; j < self.columns; j++) {
            NSUInteger column = (NSUInteger) fmodf(i + j, self.columns);
            NSUInteger row = (NSUInteger) fmodf(j, self.rows);
            product *= [self valueAtRow: row column: column];
        }
        
        det += product;
        
        product = 1;
        
        for (int j = 0; j < self.columns; j++) {
            NSUInteger column = (NSUInteger)fmodf(i - j + self.columns, self.columns);
            NSUInteger row = (NSUInteger)fmodf(j, self.rows);
            product *= [self valueAtRow: row column: column];
        }
        
        det -= product;
    }
    
    return det;
}

/**
 * Matrix duplicate
 *
 * Creates a duplicate TwoDimensionalMatrixOfDoubles of the current matrix
 */
- (DoublesMatrix *)duplicate
{
    DoublesMatrix *duplicate = [[DoublesMatrix alloc] initWithSizeRows: self.rows columns: self.columns];
    
    for (int i = 0; i < self.rows; i++) {
        for (int j = 0; j < self.columns; j++) {
            [duplicate setValueAtRow: i column: j value: [self valueAtRow: i column: j]];
        }
    }
    
    return duplicate;
}

@end
