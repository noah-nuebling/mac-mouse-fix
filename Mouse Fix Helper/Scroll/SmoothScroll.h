//
// --------------------------------------------------------------------------
// SmoothScroll.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import <Cocoa/Cocoa.h>
#import "ScrollControl.h"

@interface SmoothScroll : ScrollControl

+ (void)load_Manual;

+ (void)configureWithParameters:(NSDictionary * _Nonnull)params;

+ (void)start;
+ (void)stop;
+ (BOOL)hasStarted;
+ (BOOL)isScrolling;

+ (void)handleInput:(CGEventRef _Nonnull)event info:(NSDictionary * _Nullable)info;

@end

