//
// --------------------------------------------------------------------------
// RoughScroll.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Traditional, non-smooth scrolling.

@interface RoughScroll : NSObject
+ (void)start;
+ (void)stop;
+ (void)handleInput:(CGEventRef)event;
@end

NS_ASSUME_NONNULL_END
