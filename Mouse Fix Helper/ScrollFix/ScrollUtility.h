//
// --------------------------------------------------------------------------
// ScrollUtility.h
// Created for: Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by: Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ScrollUtility : NSObject
+ (CGEventRef)invertScrollEvent:(CGEventRef)event direction:(int)dir;
+ (CGEventRef)makeScrollEventHorizontal:(CGEventRef)event;
+ (double)signOf:(double)n;
+ (BOOL)sameSign_n:(double)n m:(double)m;
@end

NS_ASSUME_NONNULL_END
