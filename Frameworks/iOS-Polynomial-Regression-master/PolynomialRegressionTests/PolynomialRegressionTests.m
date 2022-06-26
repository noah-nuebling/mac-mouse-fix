//
//  PolynomialRegressionTests.m
//  PolynomialRegressionTests
//
//  Created by Gilles Lesire on 18/03/15.
//  Copyright (c) 2015 Gilles Lesire. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "PolynomialRegression.h"

@interface PolynomialRegressionTests : XCTestCase
@property (nonatomic, readwrite, strong) NSMutableArray *regression;
@end

@implementation PolynomialRegressionTests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    
    NSMutableArray *x = [NSMutableArray arrayWithArray:@[ @0, @9, @13, @15, @19, @20, @26, @26, @29, @30 ]];
    NSMutableArray *y = [NSMutableArray arrayWithArray:@[ @1, @-7, @6, @12, @-4, @-12, @-2, @13, @23, @30 ]];
    
    int degree = 6;
    self.regression = [PolynomialRegression regressionWithXValues:x yValues:y polynomialDegree:degree];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample
{
    double zeroDegreeValue = [self.regression[0] doubleValue];
    XCTAssert(zeroDegreeValue >= 1.011300, @"Misfire!");

    double firstDegreeValue = [self.regression[1] doubleValue];
    XCTAssert(firstDegreeValue >= -23.964676, @"Misfire!");

    double secondDegreeValue = [self.regression[2] doubleValue];
    XCTAssert(secondDegreeValue >= 4.546635, @"Misfire!");

    double thirdDegreeValue = [self.regression[3] doubleValue];
    XCTAssert(thirdDegreeValue >= -0.236831, @"Misfire!");

    double fourthDegreeValue = [self.regression[4] doubleValue];
    XCTAssert(fourthDegreeValue <= -0.000581, @"Misfire!");

    double fifthDegreeValue = [self.regression[5] doubleValue];
    XCTAssert(fifthDegreeValue >= 0.000309, @"Misfire!");

    double sixthDegreeValue = [self.regression[6] doubleValue];
    XCTAssert(sixthDegreeValue <= -0.000005, @"Misfire!");
}

@end
