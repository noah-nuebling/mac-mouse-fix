//
// --------------------------------------------------------------------------
// Utility_HelperApp.h
// Created for: Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by: Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>

@interface Utility_HelperApp : NSObject
+ (NSString *)binaryRepresentation:(int)value;
+ (int8_t)signOf:(int64_t)n;
+ (BOOL)sameSign_n:(int64_t)n m:(int64_t)m;

+ (NSBundle *)helperBundle;
+ (NSBundle *)prefPaneBundle;
@end

