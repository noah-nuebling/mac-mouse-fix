//
// --------------------------------------------------------------------------
// SharedUtility.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "SharedUtility.h"

@implementation SharedUtility

+ (void)printCallingFunctionInfo {
    
    NSLog(@"PRINTING INFO ON CALLING FUNCTION");
    
    //NSLog(@"%@", [NSThread callStackSymbols]);
    
    NSString *sourceString = [[NSThread callStackSymbols] objectAtIndex:2];
    
    NSLog(@"%@", sourceString);
}
@end
