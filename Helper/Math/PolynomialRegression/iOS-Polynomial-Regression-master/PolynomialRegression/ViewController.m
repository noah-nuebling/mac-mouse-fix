//
//  ViewController.m
//  PolynomialRegression
//
//  Created by Gilles Lesire on 18/03/15.
//  GNU General Public License (GPL)
//  https://github.com/KingIsulgard/iOS-Polynomial-Regression
//

#import "ViewController.h"
#import "PolynomialRegression.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    NSMutableArray *x = [[NSMutableArray alloc] init];
    [x addObject: @0];
    [x addObject: @9];
    [x addObject: @13];
    [x addObject: @15];
    [x addObject: @19];
    [x addObject: @20];
    [x addObject: @26];
    [x addObject: @26];
    [x addObject: @29];
    [x addObject: @30];
    
    NSMutableArray *y = [[NSMutableArray alloc] init];
    
    [y addObject: @1];
    [y addObject: @-7];
    [y addObject: @6];
    [y addObject: @12];
    [y addObject: @-4];
    [y addObject: @-12];
    [y addObject: @-2];
    [y addObject: @13];
    [y addObject: @23];
    [y addObject: @30];
    
    int degree = 6;
    NSMutableArray *regression = [PolynomialRegression regressionWithXValues:x yValues:y polynomialDegree:degree];
    
    NSLog(@"The result is the sum of");
    
    for(int i = 0; i < [regression count]; i++) {
        double value = [regression[i] doubleValue];
        NSLog(@"%f * x^%d", value, i);
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
