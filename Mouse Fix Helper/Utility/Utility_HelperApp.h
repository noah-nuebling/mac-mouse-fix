//
// --------------------------------------------------------------------------
// Utility_HelperApp.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>

@interface Utility_HelperApp : NSObject
+ (NSString *)binaryRepresentation:(int)value;

+ (NSBundle *)helperBundle;
+ (NSBundle *)prefPaneBundle;

+ (NSDictionary *)dictionaryWithOverridesAppliedFrom:(NSDictionary *)src to: (NSDictionary *)dst;
@end

