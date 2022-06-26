# iOS-Polynomial-Regression
Objective-C function for calculation the polynomial regression of a given dataset.

There are no mathematical data analysis functions in Objective-C and I couldn't find a suitable math framework for this task. For my thesis I require a function to calculate the polynomial regression of a give data set. Since this function didn't exist I had to write it myself. Problem was that other programming languages usually have this implemented by default as some kind of "polyfit" function so I dind't really had an example to base myself on.

So I had to go into the math and figure out how to turn it into an algorithm. A hellish job I wouldn't recommend to anyone. I programmed an Objective-C function for the calculation the polynomial regression of a given dataset which is extremely easy to use.

You have to give an array of NSNumber for the x values and y values and the desired degree of polynomial you would like to aquire. The function will return an NSMutableArray containing the polynomial constants. 

## Overview
* [Features](#features)
* [Example](#example)
* [Implementation](#implementation)
* [Donation](#donate)
* [License](#license)
* [Warranty](#warranty)

## Features
- Can calculate any degree of polynomial
- Easy to implement
- Very compact, one line usage
- Also contains a custom matrix class for this project which handles doubles

## Example

    NSMutableArray *x = [[NSMutableArray alloc] init];
    [x addObject: [NSNumber numberWithDouble: 0]];
    [x addObject: [NSNumber numberWithDouble: 9]];
    [x addObject: [NSNumber numberWithDouble: 13]];
    [x addObject: [NSNumber numberWithDouble: 15]];
    [x addObject: [NSNumber numberWithDouble: 19]];
    [x addObject: [NSNumber numberWithDouble: 20]];
    [x addObject: [NSNumber numberWithDouble: 26]];
    [x addObject: [NSNumber numberWithDouble: 26]];
    [x addObject: [NSNumber numberWithDouble: 29]];
    [x addObject: [NSNumber numberWithDouble: 30]];
    
    NSMutableArray *y = [[NSMutableArray alloc] init];
    
    [y addObject: [NSNumber numberWithDouble: 1]];
    [y addObject: [NSNumber numberWithDouble: -7]];
    [y addObject: [NSNumber numberWithDouble: 6]];
    [y addObject: [NSNumber numberWithDouble: 12]];
    [y addObject: [NSNumber numberWithDouble: -4]];
    [y addObject: [NSNumber numberWithDouble: -12]];
    [y addObject: [NSNumber numberWithDouble: -2]];
    [y addObject: [NSNumber numberWithDouble: 13]];
    [y addObject: [NSNumber numberWithDouble: 23]];
    [y addObject: [NSNumber numberWithDouble: 30]];
    
    int degree = 6;
    NSMutableArray *regression = [PolynomialRegression regressionWithXValues: x AndYValues: y PolynomialDegree: degree];
    
    NSLog(@"The result is the sum of");
    
    for(int i = 0; i < [regression count]; i++) {
        double value = [[regression objectAtIndex: i] doubleValue];
        NSLog(@"%f * x^%d", value, i);
    }

Generates the following output in console
```
2015-03-22 19:52:48.751 PolynomialRegression[2701:111554] The result is the sum of
2015-03-22 19:52:48.752 PolynomialRegression[2701:111554] 1.011300 * x^0
2015-03-22 19:52:48.752 PolynomialRegression[2701:111554] -23.964676 * x^1
2015-03-22 19:52:48.752 PolynomialRegression[2701:111554] 4.546635 * x^2
2015-03-22 19:52:48.752 PolynomialRegression[2701:111554] -0.236831 * x^3
2015-03-22 19:52:48.752 PolynomialRegression[2701:111554] -0.000581 * x^4
2015-03-22 19:52:48.753 PolynomialRegression[2701:111554] 0.000309 * x^5
2015-03-22 19:52:48.753 PolynomialRegression[2701:111554] -0.000005 * x^6
```

## Implementation
Implementation is easy. Just add the classes to your project and import the PolynomialRegression.h file.

## Donate
You can support [contributors](https://github.com/KingIsulgard/iOS-Polynomial-Regression/graphs/contributors) of this project individually. Every contributor is welcomed to add his/her line below with any content. Ordering shall be alphabetically by GitHub username.

Please consider a small donation if you use iOS Polynomial Regression in your projects. It would make me really happy.

* [@KingIsulgard](https://github.com/KingIsulgard): <a href="https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=HQE64D8RQGPLC"><img src="https://www.paypalobjects.com/en_US/i/btn/btn_donate_LG.gif" alt="[paypal]" /></a> !

## License
The license for the code is GPL.

You're welcome to use it in commercial, closed-source, open source, free or any other kind of software, as long as you credit me appropriately and share any improvements to the code.

## Warranty
The code comes with no warranty of any kind. I hope it'll be useful to you (it certainly is to me), but I make no guarantees regarding its functionality or otherwise.
